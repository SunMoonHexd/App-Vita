import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart'
    show
        DocumentChangeType,
        DocumentSnapshot,
        FirebaseFirestore,
        Query,
        QuerySnapshot,
        SetOptions;
import 'package:firebase_auth/firebase_auth.dart'
    show EmailAuthProvider, FirebaseAuth, FirebaseAuthException, UserCredential;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vita_app/data/services/jitsi_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/data/services/secret_hasher.dart';
import 'package:vita_app/domain/legal_versions.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/firebase_options.dart';

/// Colección sincronizada con Firestore (solicitudes, reportes, alertas, etc.).
class _Sync<T> {
  _Sync(this.name, this.list, this.idOf, this.toJson, this.fromJson);

  final String name;
  final List<T> list;
  final String Function(T) idOf;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  /// Último contenido conocido en el servidor (id -> campos).
  final Map<String, Map<String, dynamic>> synced = {};
}

/// Repositorio de VITA conectado a Firebase (Auth + Firestore).
///
/// La interfaz hacia las pantallas es la misma de antes; por dentro, los datos
/// viven en Firestore y se mantienen sincronizados entre celulares.
class VitaRepository extends ChangeNotifier {
  VitaRepository({
    required LocalStorageService storage,
    required JitsiCallService jitsi,
    DateTime Function()? clock,
  })  : _jitsi = jitsi,
        _now = clock ?? DateTime.now {
    _requestsSync = _Sync<CallRequest>(
      'requests',
      _requests,
      (r) => r.id,
      (r) => r.toJson(),
      CallRequest.fromJson,
    );
    _reportsSync = _Sync<UserReport>(
      'reports',
      _reports,
      (r) => r.id,
      (r) => r.toJson(),
      UserReport.fromJson,
    );
    _alertsSync = _Sync<EmergencyAlert>(
      'alerts',
      _alerts,
      (a) => a.id,
      (a) => a.toJson(),
      EmergencyAlert.fromJson,
    );
    _surveysSync = _Sync<CallSurvey>(
      'surveys',
      _surveys,
      (s) => '${s.callId}_${s.userId}',
      (s) => s.toJson(),
      CallSurvey.fromJson,
    );
    _slotsSync = _Sync<AvailabilitySlot>(
      'slots',
      _slots,
      (s) => s.id,
      (s) => s.toJson(),
      AvailabilitySlot.fromJson,
    );
  }

  final JitsiCallService _jitsi;
  final DateTime Function() _now;
  final _uuid = const Uuid();
  final _random = Random();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const serviceStartHour = 8;
  static const serviceEndHour = 20;
  static const ringTimeout = Duration(seconds: 30);
  static const maxReassigns = 3;
  static const maxFailedAttempts = 5;
  static const lockDuration = Duration(minutes: 15);
  static const recoveryCodeTtl = Duration(minutes: 15);
  static const _writeTimeout = Duration(seconds: 8);

  /// El prototipo permite llamadas fuera de horario para demos académicas.
  static const demoBypassSchedule = true;

  final List<VitaUser> _users = [];
  final List<CallRequest> _requests = [];
  final List<UserReport> _reports = [];
  final List<EmergencyAlert> _alerts = [];
  final List<CallSurvey> _surveys = [];
  final List<AvailabilitySlot> _slots = [];

  late final _Sync<CallRequest> _requestsSync;
  late final _Sync<UserReport> _reportsSync;
  late final _Sync<EmergencyAlert> _alertsSync;
  late final _Sync<CallSurvey> _surveysSync;
  late final _Sync<AvailabilitySlot> _slotsSync;

  // Usuarios: parte pública (users/{id}) y parte privada (private/{id}).
  final Map<String, Map<String, dynamic>> _pubById = {};
  final Map<String, Map<String, dynamic>> _privById = {};
  final Map<String, Map<String, dynamic>> _syncedPub = {};
  final Map<String, Map<String, dynamic>> _syncedPriv = {};

  final List<StreamSubscription<dynamic>> _subs = [];
  String? _sessionUserId;

  /// Último problema de sincronización (útil para depurar).
  String? lastSyncError;

  JitsiCallService get jitsi => _jitsi;

  VitaUser? get currentUser =>
      _users.where((u) => u.id == _sessionUserId && u.status != AccountStatus.deleted).firstOrNull;

  List<VitaUser> get users => List.unmodifiable(_users);

  /// Solicitudes; las que quedaron "colgadas" se muestran como vencidas.
  List<CallRequest> get requests => List.unmodifiable(_requests.map(_normalize));

  List<UserReport> get reports => List.unmodifiable(_reports);
  List<EmergencyAlert> get alerts => List.unmodifiable(_alerts);

  List<AvailabilitySlot> slotsFor(String volunteerId) =>
      _slots.where((s) => s.volunteerId == volunteerId).toList();

  CallRequest _normalize(CallRequest r) {
    final now = _now();
    if ((r.status == CallRequestStatus.searching || r.status == CallRequestStatus.ringing) &&
        now.difference(r.createdAt) > const Duration(minutes: 10)) {
      return r.copyWith(status: CallRequestStatus.expired);
    }
    if (r.status == CallRequestStatus.connected &&
        now.difference(r.startedAt ?? r.createdAt) > const Duration(hours: 4)) {
      return r.copyWith(status: CallRequestStatus.interrupted);
    }
    return r;
  }

  CallRequest? get activeRequest {
    final user = currentUser;
    if (user == null) return null;
    return requests.cast<CallRequest?>().firstWhere(
          (r) =>
              r != null &&
              (r.elderlyId == user.id || r.volunteerId == user.id) &&
              (r.status == CallRequestStatus.searching ||
                  r.status == CallRequestStatus.ringing ||
                  r.status == CallRequestStatus.connected),
          orElse: () => null,
        );
  }

  bool get isWithinServiceHours {
    if (demoBypassSchedule) return true;
    final hour = _now().hour;
    return hour >= serviceStartHour && hour < serviceEndHour;
  }

  String get serviceHoursLabel => 'Horario de atención: $serviceStartHour:00 a $serviceEndHour:00';

  // ---------------------------------------------------------------------------
  // Inicio y sesión
  // ---------------------------------------------------------------------------

  Future<void> bootstrap() async {
    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      try {
        final user = await _fetchUser(fbUser.uid);
        if (user != null && user.status == AccountStatus.active) {
          await _openSession(user);
        } else {
          await _auth.signOut();
        }
      } catch (e) {
        lastSyncError = e.toString();
        debugPrint('No se pudo restaurar la sesión: $e');
      }
    }
    notifyListeners();
  }

  Future<VitaUser?> _fetchUser(String uid) async {
    final pub = await _db.collection('users').doc(uid).get();
    if (!pub.exists || pub.data() == null) return null;
    Map<String, dynamic>? priv;
    try {
      final privSnap = await _db.collection('private').doc(uid).get();
      priv = privSnap.data();
    } catch (_) {
      priv = null;
    }
    _pubById[uid] = Map<String, dynamic>.from(pub.data()!);
    if (priv != null) _privById[uid] = Map<String, dynamic>.from(priv);
    return _compose(uid);
  }

  VitaUser? _compose(String id) {
    final pub = _pubById[id];
    if (pub == null) return null;
    try {
      final merged = <String, dynamic>{...pub, ...?_privById[id], 'id': id};
      return VitaUser.fromJson(merged);
    } catch (e) {
      debugPrint('Usuario $id con datos incompletos: $e');
      return null;
    }
  }

  Future<void> _openSession(VitaUser user) async {
    await _stopSync();
    final pub = _pubById[user.id];
    final priv = _privById[user.id];
    _clearLocal();
    if (pub != null) _pubById[user.id] = pub;
    if (priv != null) _privById[user.id] = priv;
    _users.add(user);
    _syncedPub[user.id] = _publicJson(user);
    if (priv != null) _syncedPriv[user.id] = _privateJson(user);
    _sessionUserId = user.id;
    await _startSync();
    notifyListeners();
  }

  void _clearLocal() {
    _users.clear();
    _requests.clear();
    _reports.clear();
    _alerts.clear();
    _surveys.clear();
    _slots.clear();
    _pubById.clear();
    _privById.clear();
    _syncedPub.clear();
    _syncedPriv.clear();
    for (final s in [_requestsSync, _reportsSync, _alertsSync, _surveysSync, _slotsSync]) {
      s.synced.clear();
    }
  }

  AuthResult _finishLogin(VitaUser user) {
    if (user.status == AccountStatus.blocked) {
      return const AuthResult.error('Esta cuenta está bloqueada.');
    }
    if (user.status == AccountStatus.suspended) {
      return const AuthResult.error('Esta cuenta está suspendida.');
    }
    if (user.role == UserRole.volunteer && user.status == AccountStatus.pending) {
      return const AuthResult.error('Tu cuenta sigue pendiente de verificación.');
    }
    return AuthResult.ok(user);
  }

  String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// El adulto mayor ingresa con teléfono + PIN; por dentro se convierten en
  /// un correo y una clave de Firebase (la clave exige 6 caracteres o más).
  String _elderlyEmail(String phone) => '${_digits(phone)}@telefono.vita.invalid';
  String _elderlyPassword(String pin, String phone) => 'vita-$pin-${_digits(phone)}';

  String _authMessage(FirebaseAuthException e, {required String wrong}) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return wrong;
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red e inténtalo de nuevo.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      default:
        return 'No se pudo completar la acción (${e.code}).';
    }
  }

  Future<AuthResult> _login({
    required String email,
    required String password,
    required UserRole role,
    required String wrong,
    String? lockKey,
  }) async {
    if (lockKey != null) {
      final locked = await _lockMessage(lockKey);
      if (locked != null) return AuthResult.error(locked);
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final user = await _fetchUser(uid);
      if (user == null || user.status == AccountStatus.deleted || user.role != role) {
        await _auth.signOut();
        return const AuthResult.error('No encontramos esa cuenta para este perfil.');
      }
      final gate = _finishLogin(user);
      if (!gate.isOk) {
        await _auth.signOut();
        return gate;
      }
      if (lockKey != null) await _clearLock(lockKey);
      await _openSession(user);
      return AuthResult.ok(user);
    } on FirebaseAuthException catch (e) {
      final credentialError = e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-email';
      if (lockKey != null && credentialError) {
        return AuthResult.error(await _registerFailedAttempt(lockKey, wrong: wrong));
      }
      return AuthResult.error(_authMessage(e, wrong: wrong));
    } catch (e) {
      lastSyncError = e.toString();
      return const AuthResult.error('No se pudo conectar. Revisa tu internet e inténtalo de nuevo.');
    }
  }

  String _elderlyLockKey(String phone) => 'elderly:${_digits(phone)}';
  String _volunteerLockKey(String email) => 'volunteer:${email.trim().toLowerCase()}';

  Future<String?> _lockMessage(String key) async {
    try {
      final snap = await _db.collection('locks').doc(key).get();
      final data = snap.data();
      if (data == null) return null;
      final raw = data['lockedUntil'] as String?;
      if (raw == null) return null;
      final until = DateTime.tryParse(raw);
      if (until == null || !_now().isBefore(until)) return null;
      final minutes = until.difference(_now()).inMinutes + 1;
      final help = key.startsWith('elderly:')
          ? ' También puedes restablecer el PIN con ayuda de tu familiar.'
          : ' También puedes restablecer tu contraseña desde el correo.';
      return 'Cuenta bloqueada por intentos fallidos. Espera $minutes minuto(s).$help';
    } catch (_) {
      return null;
    }
  }

  Future<String> _registerFailedAttempt(String key, {required String wrong}) async {
    try {
      final ref = _db.collection('locks').doc(key);
      final snap = await ref.get();
      final prev = (snap.data()?['failedAttempts'] as num?)?.toInt() ?? 0;
      final next = prev + 1;
      if (next >= maxFailedAttempts) {
        final until = _now().add(lockDuration);
        await ref.set({
          'failedAttempts': next,
          'lockedUntil': until.toIso8601String(),
        });
        final help = key.startsWith('elderly:')
            ? ' Recupera el PIN con tu familiar o espera 15 minutos.'
            : ' Espera 15 minutos o restablece tu contraseña.';
        return 'Cuenta bloqueada por 15 minutos tras 5 intentos fallidos.$help';
      }
      await ref.set({'failedAttempts': next, 'lockedUntil': null});
      return '$wrong Te quedan ${maxFailedAttempts - next} intento(s).';
    } catch (_) {
      return wrong;
    }
  }

  Future<void> _clearLock(String key) async {
    try {
      await _db.collection('locks').doc(key).delete();
    } catch (_) {}
  }

  Future<AuthResult> loginElderly({required String phone, required String pin}) async {
    final result = await _login(
      email: _elderlyEmail(phone),
      password: _elderlyPassword(pin, phone),
      role: UserRole.elderly,
      wrong: 'Teléfono o PIN incorrectos.',
      lockKey: _elderlyLockKey(phone),
    );
    if (result.isOk && result.user != null) {
      await _upsertPhoneIndex(result.user!, pin);
    }
    return result;
  }

  Future<AuthResult> loginVolunteer({required String email, required String password}) {
    return _login(
      email: email.trim(),
      password: password,
      role: UserRole.volunteer,
      wrong: 'Correo o contraseña incorrectos.',
      lockKey: _volunteerLockKey(email),
    );
  }

  Future<AuthResult> loginCoordinator({required String email, required String password}) {
    return _login(
      email: email.trim(),
      password: password,
      role: UserRole.coordinator,
      wrong: 'Correo o contraseña incorrectos.',
    );
  }

  Future<void> _writeNewUser(VitaUser user) async {
    await _db.collection('users').doc(user.id).set(_publicJson(user)).timeout(const Duration(seconds: 15));
    await _db.collection('private').doc(user.id).set(_privateJson(user)).timeout(const Duration(seconds: 15));
    // Evidencia del consentimiento (RF10): qué versión del texto aceptó y cuándo.
    await _db.collection('consents').doc(user.id).set({
      'userId': user.id,
      'role': user.role.name,
      'consentVersion': kConsentVersion,
      'acceptedAt': _now().toIso8601String(),
      'acceptedTerms': true,
      'acceptedPrivacy': true,
    }).timeout(const Duration(seconds: 15));
  }

  Future<AuthResult> registerElderly({
    required String name,
    required DateTime birthDate,
    required String phone,
    required String pin,
    required String familyName,
    required String familyPhone,
    required String alternateName,
    required String alternatePhone,
    required bool consent,
    required bool aptitude,
  }) async {
    if (!consent) return const AuthResult.error('Debes aceptar el consentimiento informado.');
    if (!aptitude) return const AuthResult.error('Debes confirmar que puedes usar la app de forma autónoma.');
    if (pin.length != 4 || int.tryParse(pin) == null) {
      return const AuthResult.error('El PIN debe tener 4 dígitos.');
    }
    if (_digits(phone).length < 7) return const AuthResult.error('Revisa el número de teléfono.');
    if (_ageFrom(birthDate) < 60) return const AuthResult.error('El servicio es para personas de 60 años o más.');

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: _elderlyEmail(phone),
        password: _elderlyPassword(pin, phone),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return const AuthResult.error('Ese teléfono ya está registrado.');
      return AuthResult.error(_authMessage(e, wrong: 'Datos incorrectos.'));
    } catch (_) {
      return const AuthResult.error('No se pudo conectar. Revisa tu internet e inténtalo de nuevo.');
    }

    final user = VitaUser(
      id: cred.user!.uid,
      role: UserRole.elderly,
      displayName: name.trim(),
      status: AccountStatus.active,
      phone: phone.trim(),
      birthDate: birthDate,
      familyName: familyName.trim(),
      familyPhone: familyPhone.trim(),
      alternateName: alternateName.trim(),
      alternatePhone: alternatePhone.trim(),
      consentAccepted: true,
      createdAt: _now(),
    );
    try {
      await _writeNewUser(user);
    } catch (e) {
      lastSyncError = e.toString();
      try {
        await cred.user!.delete();
      } catch (_) {}
      return const AuthResult.error('No se pudo guardar tu registro. Revisa tu internet e inténtalo de nuevo.');
    }
    _pubById[user.id] = _publicJson(user);
    _privById[user.id] = _privateJson(user);
    await _openSession(user);
    await _upsertPhoneIndex(user, pin);
    return AuthResult.ok(user);
  }

  Future<AuthResult> registerVolunteer({
    required String name,
    required DateTime birthDate,
    required String phone,
    required String email,
    required String password,
    required String documentId,
    required bool consent,
    required bool conduct,
    required bool inductionDone,
  }) async {
    if (!consent) return const AuthResult.error('Debes aceptar el tratamiento de datos.');
    if (!conduct || !inductionDone) {
      return const AuthResult.error('Debes aceptar el código de conducta y completar la inducción.');
    }
    if (_ageFrom(birthDate) < 18) return const AuthResult.error('El voluntario debe ser mayor de 18 años.');

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return const AuthResult.error('Ese correo ya está registrado.');
      return AuthResult.error(_authMessage(e, wrong: 'Datos incorrectos.'));
    } catch (_) {
      return const AuthResult.error('No se pudo conectar. Revisa tu internet e inténtalo de nuevo.');
    }

    final user = VitaUser(
      id: cred.user!.uid,
      role: UserRole.volunteer,
      displayName: name.trim(),
      status: AccountStatus.pending,
      phone: phone.trim(),
      email: email.trim(),
      documentId: documentId.trim(),
      birthDate: birthDate,
      consentAccepted: true,
      conductAccepted: true,
      inductionDone: true,
      createdAt: _now(),
    );
    try {
      await _writeNewUser(user);
    } catch (e) {
      lastSyncError = e.toString();
      try {
        await cred.user!.delete();
      } catch (_) {}
      return const AuthResult.error('No se pudo guardar tu registro. Revisa tu internet e inténtalo de nuevo.');
    }
    // El voluntario queda pendiente: no inicia sesión hasta que coordinación lo apruebe.
    await _auth.signOut();
    return AuthResult.ok(user);
  }

  int _ageFrom(DateTime birth) {
    final now = _now();
    var age = now.year - birth.year;
    final hadBirthday = now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) age--;
    return age;
  }

  Future<void> completeOnboarding() async {
    final user = currentUser;
    if (user == null) return;
    _replaceUser(user.copyWith(onboardingDone: true));
    await _commit();
  }

  Future<void> logout() async {
    await _push();
    await _stopSync();
    _clearLocal();
    _sessionUserId = null;
    try {
      await _auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Recuperación de acceso
  // ---------------------------------------------------------------------------

  Future<PinRecoveryTicket> startPinRecovery(String phone) async {
    final digits = _digits(phone);
    if (digits.length < 7) {
      throw Exception('Revisa el número de teléfono.');
    }
    final index = await _db.collection('phoneIndex').doc(digits).get();
    final data = index.data();
    if (!index.exists || data == null) {
      throw Exception(
        'No encontramos ese teléfono. Si ya tenías cuenta, entra una vez con tu PIN '
        'o pide a coordinación que restablezca el acceso.',
      );
    }
    final familyPhone = (data['familyPhone'] as String?)?.trim() ?? '';
    final familyName = (data['familyName'] as String?)?.trim() ?? 'Familiar';
    if (familyPhone.isEmpty) {
      throw Exception('Esta cuenta no tiene un familiar registrado. Pide ayuda a coordinación.');
    }
    final code = (_random.nextInt(900000) + 100000).toString();
    await _db.collection('pinRecoveries').doc(digits).set({
      'codeHash': hashSecret(code),
      'expiresAt': _now().add(recoveryCodeTtl).toIso8601String(),
      'tries': 0,
      'uid': data['uid'],
    });
    return PinRecoveryTicket(code: code, familyPhone: familyPhone, familyName: familyName);
  }

  Future<void> completePinRecovery({
    required String phone,
    required String code,
    required String newPin,
  }) async {
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      throw Exception('El PIN nuevo debe tener 4 dígitos.');
    }
    final digits = _digits(phone);
    final rec = await _db.collection('pinRecoveries').doc(digits).get();
    final recData = rec.data();
    if (!rec.exists || recData == null) {
      throw Exception('Pide primero el código para este teléfono.');
    }
    final expiresAt = DateTime.tryParse(recData['expiresAt'] as String? ?? '');
    if (expiresAt == null || _now().isAfter(expiresAt)) {
      await rec.reference.delete();
      throw Exception('El código ya venció. Pide uno nuevo.');
    }
    final tries = (recData['tries'] as num?)?.toInt() ?? 0;
    if (tries >= maxFailedAttempts) {
      await rec.reference.delete();
      throw Exception('Demasiados intentos con el código. Pide uno nuevo o contacta a coordinación.');
    }
    if (recData['codeHash'] != hashSecret(code.trim())) {
      await rec.reference.update({'tries': tries + 1});
      throw Exception('El código no es correcto. Te quedan ${maxFailedAttempts - tries - 1} intento(s).');
    }
    final index = await _db.collection('phoneIndex').doc(digits).get();
    final wrapped = index.data()?['pinWrap'] as String?;
    final oldPin = wrapped == null ? null : unwrapPin(wrapped);
    if (oldPin == null) {
      throw Exception(
        'No se pudo restablecer el PIN desde aquí. Coordinación puede hacerlo tras verificar tu identidad.',
      );
    }
    await _changeElderlyPassword(phone: phone, currentPin: oldPin, newPin: newPin);
    await rec.reference.delete();
    await _clearLock(_elderlyLockKey(phone));
  }

  /// Coordinación restablece el PIN tras verificar la identidad (RF12).
  Future<void> coordinatorResetElderlyPin({required String phone, required String newPin}) async {
    final actor = currentUser;
    if (actor == null || actor.role != UserRole.coordinator) {
      throw Exception('Solo coordinación puede restablecer el PIN de esta forma.');
    }
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      throw Exception('El PIN nuevo debe tener 4 dígitos.');
    }
    final digits = _digits(phone);
    final index = await _db.collection('phoneIndex').doc(digits).get();
    var wrapped = index.data()?['pinWrap'] as String?;
    if (wrapped == null) {
      final match = _users.where((u) => u.role == UserRole.elderly && _digits(u.phone ?? '') == digits);
      if (match.isEmpty) {
        throw Exception('No hay un adulto mayor con ese teléfono.');
      }
      throw Exception(
        'Esa cuenta aún no tiene PIN recuperable. El adulto debe entrar una vez con su PIN actual.',
      );
    }
    final oldPin = unwrapPin(wrapped);
    if (oldPin == null) {
      throw Exception('No se pudo leer el PIN anterior. Prueba de nuevo.');
    }
    await _changeElderlyPassword(phone: phone, currentPin: oldPin, newPin: newPin);
    try {
      await _db.collection('pinRecoveries').doc(digits).delete();
    } catch (_) {}
    await _clearLock(_elderlyLockKey(phone));
  }

  Future<void> _upsertPhoneIndex(VitaUser user, String pin) async {
    final digits = _digits(user.phone ?? '');
    if (digits.isEmpty || user.role != UserRole.elderly) return;
    try {
      await _db.collection('phoneIndex').doc(digits).set({
        'uid': user.id,
        'familyName': user.familyName,
        'familyPhone': user.familyPhone,
        'pinWrap': wrapPin(pin),
        'updatedAt': _now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('No se pudo guardar el índice de teléfono: $e');
    }
  }

  Future<FirebaseApp> _pinResetApp() async {
    try {
      return Firebase.app('vita-pin-reset');
    } catch (_) {
      return Firebase.initializeApp(
        name: 'vita-pin-reset',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  /// Cambia el PIN en Firebase Auth sin tocar la sesión actual (usa una app secundaria).
  Future<void> _changeElderlyPassword({
    required String phone,
    required String currentPin,
    required String newPin,
  }) async {
    final app = await _pinResetApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    try {
      await auth.signInWithEmailAndPassword(
        email: _elderlyEmail(phone),
        password: _elderlyPassword(currentPin, phone),
      );
      await auth.currentUser!.updatePassword(_elderlyPassword(newPin, phone));
      await db.collection('phoneIndex').doc(_digits(phone)).set({
        'uid': auth.currentUser!.uid,
        'pinWrap': wrapPin(newPin),
        'updatedAt': _now().toIso8601String(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(_authMessage(e, wrong: 'No se pudo validar la cuenta para cambiar el PIN.'));
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  /// Envía un correo de Firebase para restablecer la contraseña del voluntario.
  Future<String> startPasswordRecovery(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return '';
    } on FirebaseAuthException catch (e) {
      throw Exception(_authMessage(e, wrong: 'Revisa que el correo esté bien escrito.'));
    }
  }

  Future<void> completePasswordRecovery({required String code, required String password}) async {
    throw Exception('Usa el enlace que enviamos a tu correo.');
  }

  // ---------------------------------------------------------------------------
  // Perfil y cuenta
  // ---------------------------------------------------------------------------

  /// Cuántos voluntarios pueden atender en este momento (para el inicio).
  int get availableVolunteerCount => _availableVolunteers().length;

  /// Cambia el PIN del adulto mayor: confirma el actual y guarda el nuevo.
  Future<void> changePin({required String currentPin, required String newPin}) async {
    final user = currentUser;
    final fbUser = _auth.currentUser;
    if (user == null || fbUser == null || user.role != UserRole.elderly) {
      throw Exception('Debes ingresar como adulto mayor.');
    }
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      throw Exception('El PIN nuevo debe tener 4 dígitos.');
    }
    if (newPin == currentPin) {
      throw Exception('El PIN nuevo debe ser distinto al actual.');
    }
    final phone = user.phone ?? '';
    try {
      final credential = EmailAuthProvider.credential(
        email: _elderlyEmail(phone),
        password: _elderlyPassword(currentPin, phone),
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(_elderlyPassword(newPin, phone));
      await _upsertPhoneIndex(user, newPin);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authMessage(e, wrong: 'El PIN actual no es correcto.'));
    }
  }

  Future<void> updateProfile({
    String? phone,
    String? familyName,
    String? familyPhone,
    String? alternateName,
    String? alternatePhone,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (user.role == UserRole.elderly && phone != null && _digits(phone) != _digits(user.phone ?? '')) {
      throw Exception('Por seguridad, el número de ingreso solo se cambia con ayuda de coordinación.');
    }
    final updated = user.copyWith(
      phone: phone,
      familyName: familyName,
      familyPhone: familyPhone,
      alternateName: alternateName,
      alternatePhone: alternatePhone,
    );
    _replaceUser(updated);
    await _commit();
    if (updated.role == UserRole.elderly) {
      final digits = _digits(updated.phone ?? '');
      if (digits.isNotEmpty) {
        try {
          await _db.collection('phoneIndex').doc(digits).set({
            'uid': updated.id,
            'familyName': updated.familyName,
            'familyPhone': updated.familyPhone,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    }
  }

  Future<void> requestAccountDeletion() async {
    final user = currentUser;
    if (user == null) return;
    _replaceUser(user.copyWith(status: AccountStatus.deleted, available: false));
    await _commit();
    try {
      await _db.collection('private').doc(user.id).delete().timeout(_writeTimeout);
    } catch (_) {}
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
    await logout();
  }

  Future<void> setAvailability(bool available) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer) return;
    if (activeRequest?.status == CallRequestStatus.connected) {
      throw Exception('No puedes cambiar la disponibilidad durante una videollamada.');
    }
    if (available && !isVolunteerInShift(user.id)) {
      throw Exception('Estás fuera de tu horario programado.');
    }
    _replaceUser(user.copyWith(available: available));
    await _commit();
  }

  bool isVolunteerInShift(String volunteerId) {
    final now = _now();
    final slots = slotsFor(volunteerId);
    if (slots.isEmpty) return true;
    return slots.any((s) => s.weekday == now.weekday && now.hour >= s.startHour && now.hour < s.endHour);
  }

  Future<void> addSlot({required int weekday, required int startHour, required int endHour}) async {
    final user = currentUser;
    if (user == null) return;
    if (endHour <= startHour) throw Exception('La hora final debe ser posterior a la inicial.');
    final overlap = slotsFor(user.id).any(
      (s) => s.weekday == weekday && startHour < s.endHour && endHour > s.startHour,
    );
    if (overlap) throw Exception('Ese horario se cruza con otro turno ya guardado.');
    _slots.add(
      AvailabilitySlot(
        id: _uuid.v4(),
        volunteerId: user.id,
        weekday: weekday,
        startHour: startHour,
        endHour: endHour,
      ),
    );
    await _commit();
  }

  Future<void> removeSlot(String id) async {
    _slots.removeWhere((s) => s.id == id);
    await _commit();
  }

  // ---------------------------------------------------------------------------
  // Llamadas
  // ---------------------------------------------------------------------------

  Future<CallRequest> startCallRequest() async {
    final user = currentUser;
    if (user == null || user.role != UserRole.elderly) {
      throw Exception('Debes ingresar como adulto mayor.');
    }
    if (!isWithinServiceHours) {
      throw Exception('Fuera de horario. $serviceHoursLabel');
    }
    // Si quedó una llamada "conectada" de antes (por ejemplo, se cerró la app a medias),
    // se cierra: la persona está pidiendo una nueva y el voluntario debe quedar libre.
    for (final r in List<CallRequest>.from(_requests)) {
      if (r.elderlyId == user.id && r.status == CallRequestStatus.connected) {
        await finishCall(r.id, status: CallRequestStatus.interrupted);
      }
    }

    final existing = activeRequest;
    if (existing != null) return existing;

    // La sala se deriva del código: otro celular puede entrar a la misma sala.
    final code = (_random.nextInt(900000) + 100000).toString();
    final request = CallRequest(
      id: _uuid.v4(),
      elderlyId: user.id,
      roomName: 'VITA_Acompanamiento_$code',
      joinCode: code,
      status: CallRequestStatus.searching,
      createdAt: _now(),
    );
    _requests.add(request);
    await _commit();
    await assignVolunteer(request.id);
    return _requests.firstWhere((r) => r.id == request.id);
  }

  List<VitaUser> _availableVolunteers({String? excludeId}) {
    final list = _users.where((u) {
      if (u.role != UserRole.volunteer) return false;
      if (u.status != AccountStatus.active) return false;
      if (!u.available) return false;
      if (excludeId != null && u.id == excludeId) return false;
      if (!isVolunteerInShift(u.id)) return false;
      final busy = _requests.any(
        (r) =>
            r.volunteerId == u.id &&
            (r.status == CallRequestStatus.ringing || r.status == CallRequestStatus.connected),
      );
      return !busy;
    }).toList()
      ..sort((a, b) {
        final aTime = a.lastCallAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastCallAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    return list;
  }

  Future<CallRequest> assignVolunteer(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Solicitud no encontrada.');
    final request = _requests[index];
    final candidates = _availableVolunteers(excludeId: request.volunteerId);
    if (candidates.isEmpty) {
      _requests[index] = request.copyWith(status: CallRequestStatus.expired);
      await _commit();
      return _requests[index];
    }
    final volunteer = candidates.first;
    _requests[index] = request.copyWith(
      volunteerId: volunteer.id,
      status: CallRequestStatus.ringing,
    );
    await _commit();
    return _requests[index];
  }

  Future<void> cancelRequest(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    final request = _requests[index];
    if (request.status == CallRequestStatus.connected) return;
    _requests[index] = request.copyWith(status: CallRequestStatus.cancelled, endedAt: _now());
    await _commit();
  }

  Future<CallRequest> timeoutRing(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Solicitud no encontrada.');
    final request = _requests[index];
    if (request.status != CallRequestStatus.ringing) return request;
    if (request.attempts >= maxReassigns) {
      _requests[index] = request.copyWith(status: CallRequestStatus.expired);
      await _commit();
      return _requests[index];
    }
    _requests[index] = request.copyWith(attempts: request.attempts + 1);
    await _commit();
    return assignVolunteer(requestId);
  }

  Future<CallRequest> acceptRequest(String requestId) async {
    final user = currentUser;
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Solicitud no encontrada.');
    final request = _requests[index];
    if (user != null && request.volunteerId != user.id) {
      throw Exception('Esta solicitud no te fue asignada.');
    }
    _requests[index] = request.copyWith(status: CallRequestStatus.connected, startedAt: _now());
    await _commit();
    return _requests[index];
  }

  Future<void> rejectRequest(String requestId) async {
    await timeoutRing(requestId);
  }

  /// Respaldo manual: el voluntario escribe el código que ve el adulto mayor.
  Future<CallRequest> joinByCode(String code) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer) {
      throw Exception('Ingresa como voluntario para unirte.');
    }
    final clean = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(clean)) {
      throw Exception('El código debe tener 6 dígitos.');
    }

    final snap = await _db
        .collection('requests')
        .where('joinCode', isEqualTo: clean)
        .where('status', whereIn: ['searching', 'ringing'])
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('No hay una solicitud con ese código.');

    final found = CallRequest.fromJson(Map<String, dynamic>.from(snap.docs.first.data()));
    final i = _requests.indexWhere((r) => r.id == found.id);
    if (i >= 0) {
      _requests[i] = found;
    } else {
      _requests.add(found);
    }
    _requestsSync.synced[found.id] = found.toJson();

    final updated = found.copyWith(
      volunteerId: user.id,
      status: CallRequestStatus.connected,
      startedAt: _now(),
    );
    _requests[_requests.indexWhere((r) => r.id == found.id)] = updated;
    _replaceUser(user.copyWith(available: false));
    await _commit();
    return updated;
  }

  /// Ya no hay voluntario "demo" local: se mantiene solo por compatibilidad.
  Future<CallRequest> autoAcceptDemo(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Solicitud no encontrada.');
    return _requests[index];
  }

  Future<void> finishCall(String requestId, {CallRequestStatus status = CallRequestStatus.completed}) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    final request = _requests[index];
    // Una "llamada" de menos de 15 segundos casi seguro falló: no cuenta como completada.
    var finalStatus = status;
    if (status == CallRequestStatus.completed &&
        request.startedAt != null &&
        _now().difference(request.startedAt!) < const Duration(seconds: 15)) {
      finalStatus = CallRequestStatus.interrupted;
    }
    _requests[index] = request.copyWith(status: finalStatus, endedAt: _now());
    if (request.volunteerId != null) {
      final volunteer = _users.cast<VitaUser?>().firstWhere(
            (u) => u != null && u.id == request.volunteerId,
            orElse: () => null,
          );
      if (volunteer != null) {
        _replaceUser(volunteer.copyWith(lastCallAt: _now(), available: true));
      }
    }
    await _commit();
  }

  Future<void> joinCurrentCall() async {
    final user = currentUser;
    final request = activeRequest;
    if (user == null || request == null) {
      throw Exception('No hay una llamada activa.');
    }
    await _jitsi.join(
      roomName: request.roomName,
      displayName: user.displayName,
      userId: user.id,
      onTerminated: () {
        finishCall(request.id);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Reportes, alertas, encuestas y administración
  // ---------------------------------------------------------------------------

  Future<void> addReport({
    required String callId,
    required String reportedId,
    required String reason,
    String? comment,
  }) async {
    final user = currentUser;
    if (user == null) return;
    _reports.add(
      UserReport(
        id: _uuid.v4(),
        reporterId: user.id,
        reportedId: reportedId,
        callId: callId,
        reason: reason,
        comment: comment,
        status: ReportStatus.pending,
        createdAt: _now(),
      ),
    );
    await _commit();
  }

  Future<void> resolveReport(String reportId, ReportStatus decision) async {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index < 0) return;
    final report = _reports[index];
    _reports[index] = report.copyWith(status: decision);
    final reportedIndex = _indexOf(report.reportedId);
    if (reportedIndex >= 0) {
      final next = switch (decision) {
        ReportStatus.suspended => AccountStatus.suspended,
        ReportStatus.blocked => AccountStatus.blocked,
        _ => _users[reportedIndex].status,
      };
      _users[reportedIndex] = _users[reportedIndex].copyWith(
        status: next,
        available: decision == ReportStatus.suspended || decision == ReportStatus.blocked
            ? false
            : _users[reportedIndex].available,
      );
    }
    await _commit();
  }

  Future<void> addAlert({required String callId, required String elderlyId, String? note}) async {
    final user = currentUser;
    if (user == null) return;
    _alerts.add(
      EmergencyAlert(
        id: _uuid.v4(),
        callId: callId,
        triggeredById: user.id,
        elderlyId: elderlyId,
        note: note,
        createdAt: _now(),
      ),
    );
    await _commit();
  }

  Future<void> saveSurvey(CallSurvey survey) async {
    _surveys.removeWhere((s) => s.callId == survey.callId && s.userId == survey.userId);
    _surveys.add(survey);
    await _commit();
  }

  Future<void> approveVolunteer(String userId, {required bool approve}) async {
    final i = _indexOf(userId);
    if (i < 0) return;
    _users[i] = _users[i].copyWith(status: approve ? AccountStatus.active : AccountStatus.blocked);
    await _commit();
  }

  Future<void> setAccountStatus(String userId, AccountStatus status) async {
    final i = _indexOf(userId);
    if (i < 0) return;
    _users[i] = _users[i].copyWith(
      status: status,
      available: status == AccountStatus.active ? _users[i].available : false,
    );
    await _commit();
  }

  VitaUser? userById(String id) => _users.cast<VitaUser?>().firstWhere((u) => u?.id == id, orElse: () => null);

  Duration volunteerHours(String volunteerId) {
    var total = Duration.zero;
    for (final request in _requests) {
      if (request.volunteerId == volunteerId && request.status == CallRequestStatus.completed) {
        total += request.duration;
      }
    }
    return total;
  }

  int get completedCalls => _requests.where((r) => r.status == CallRequestStatus.completed).length;

  Duration get averageDuration {
    final done = _requests.where((r) => r.status == CallRequestStatus.completed && r.startedAt != null).toList();
    if (done.isEmpty) return Duration.zero;
    final ms = done.fold<int>(0, (p, r) => p + r.duration.inMilliseconds) ~/ done.length;
    return Duration(milliseconds: ms);
  }

  // ---------------------------------------------------------------------------
  // Sincronización con Firestore
  // ---------------------------------------------------------------------------

  int _indexOf(String id) => _users.indexWhere((u) => u.id == id);

  void _replaceUser(VitaUser user) {
    final i = _indexOf(user.id);
    if (i >= 0) _users[i] = user;
  }

  Map<String, dynamic> _publicJson(VitaUser u) => {
        'id': u.id,
        'role': u.role.name,
        'displayName': u.displayName,
        'status': u.status.name,
        'consentAccepted': u.consentAccepted,
        'conductAccepted': u.conductAccepted,
        'inductionDone': u.inductionDone,
        'available': u.available,
        'onboardingDone': u.onboardingDone,
        'lastCallAt': u.lastCallAt?.toIso8601String(),
        'createdAt': u.createdAt?.toIso8601String(),
      };

  Map<String, dynamic> _privateJson(VitaUser u) => {
        'phone': u.phone,
        'email': u.email,
        'documentId': u.documentId,
        'birthDate': u.birthDate?.toIso8601String(),
        'familyName': u.familyName,
        'familyPhone': u.familyPhone,
        'alternateName': u.alternateName,
        'alternatePhone': u.alternatePhone,
      };

  Future<void> _commit() async {
    notifyListeners();
    await _push();
  }

  /// Solo los campos que cambiaron respecto a lo último conocido del servidor.
  Map<String, dynamic> _changed(Map<String, dynamic>? old, Map<String, dynamic> now) {
    if (old == null) return Map<String, dynamic>.from(now);
    final out = <String, dynamic>{};
    for (final e in now.entries) {
      if (!old.containsKey(e.key) || old[e.key] != e.value) out[e.key] = e.value;
    }
    return out;
  }

  Future<void> _set(String collection, String id, Map<String, dynamic> data, void Function() onOk) async {
    try {
      await _db.collection(collection).doc(id).set(data, SetOptions(merge: true)).timeout(_writeTimeout);
      onOk();
    } on TimeoutException {
      // Sin conexión: Firestore guarda la escritura y la envía al reconectar.
      onOk();
      lastSyncError = 'Sin confirmación del servidor; se enviará al reconectar.';
    } catch (e) {
      lastSyncError = 'No se pudo guardar $collection/$id: $e';
      debugPrint(lastSyncError);
    }
  }

  Future<void> _delete(String collection, String id, void Function() onOk) async {
    try {
      await _db.collection(collection).doc(id).delete().timeout(_writeTimeout);
      onOk();
    } on TimeoutException {
      onOk();
    } catch (e) {
      lastSyncError = 'No se pudo borrar $collection/$id: $e';
      debugPrint(lastSyncError);
    }
  }

  Future<void> _push() async {
    if (_auth.currentUser == null) return;
    final writes = <Future<void>>[];

    for (final u in List<VitaUser>.from(_users)) {
      final pub = _publicJson(u);
      final oldPub = _syncedPub[u.id];
      final chPub = _changed(oldPub, pub);
      if (oldPub == null || chPub.isNotEmpty) {
        writes.add(_set('users', u.id, chPub, () => _syncedPub[u.id] = pub));
      }
      if (u.id == _sessionUserId) {
        final priv = _privateJson(u);
        final oldPriv = _syncedPriv[u.id];
        final chPriv = _changed(oldPriv, priv);
        if (oldPriv == null || chPriv.isNotEmpty) {
          writes.add(_set('private', u.id, chPriv, () => _syncedPriv[u.id] = priv));
        }
      }
    }

    void collect<T>(_Sync<T> s, {bool deleteMissing = false}) {
      final ids = <String>{};
      for (final item in List<T>.from(s.list)) {
        final id = s.idOf(item);
        ids.add(id);
        final json = s.toJson(item);
        final old = s.synced[id];
        final ch = _changed(old, json);
        if (old != null && ch.isEmpty) continue;
        writes.add(_set(s.name, id, ch, () => s.synced[id] = json));
      }
      if (deleteMissing) {
        for (final id in s.synced.keys.toList()) {
          if (!ids.contains(id)) writes.add(_delete(s.name, id, () => s.synced.remove(id)));
        }
      }
    }

    collect(_requestsSync);
    collect(_reportsSync);
    collect(_alertsSync);
    collect(_surveysSync);
    collect(_slotsSync, deleteMissing: true);

    if (writes.isNotEmpty) await Future.wait(writes);
  }

  void _onSyncError(Object error) {
    lastSyncError = error.toString();
    debugPrint('Error de sincronización: $error');
  }

  Future<void> _stopSync() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  Future<void> _startSync() async {
    final me = _sessionUserId;
    final role = currentUser?.role;
    if (me == null || role == null) return;

    _subs.add(_db.collection('users').snapshots().listen(_onUsers, onError: _onSyncError));
    _listen(_db.collection('slots'), (snap) => _applySnapshot(_slotsSync, snap));

    if (role == UserRole.coordinator) {
      _subs.add(_db.collection('private').snapshots().listen(_onPrivateAll, onError: _onSyncError));
      _listen(_db.collection('requests'), (snap) => _applySnapshot(_requestsSync, snap));
      _listen(_db.collection('reports'), (snap) => _applySnapshot(_reportsSync, snap));
      _listen(_db.collection('alerts'), (snap) => _applySnapshot(_alertsSync, snap));
      _listen(_db.collection('surveys'), (snap) => _applySnapshot(_surveysSync, snap));
    } else {
      _subs.add(_db.collection('private').doc(me).snapshots().listen(_onPrivateOne, onError: _onSyncError));
      final field = role == UserRole.elderly ? 'elderlyId' : 'volunteerId';
      _listen(
        _db.collection('requests').where(field, isEqualTo: me),
        (snap) => _applySnapshot(_requestsSync, snap),
      );
    }
  }

  void _listen(Query<Map<String, dynamic>> query, void Function(QuerySnapshot<Map<String, dynamic>>) onData) {
    _subs.add(query.snapshots().listen(onData, onError: _onSyncError));
  }

  void _upsertUser(String id) {
    final user = _compose(id);
    if (user == null) return;
    final i = _indexOf(id);
    if (i >= 0) {
      _users[i] = user;
    } else {
      _users.add(user);
    }
    _syncedPub[id] = _publicJson(user);
    if (_privById.containsKey(id)) _syncedPriv[id] = _privateJson(user);
  }

  void _onUsers(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final c in snap.docChanges) {
      final id = c.doc.id;
      if (c.type == DocumentChangeType.removed) {
        _pubById.remove(id);
        _syncedPub.remove(id);
        _users.removeWhere((u) => u.id == id);
        continue;
      }
      final data = c.doc.data();
      if (data == null) continue;
      _pubById[id] = Map<String, dynamic>.from(data);
      _upsertUser(id);
    }
    notifyListeners();
  }

  void _onPrivateAll(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final c in snap.docChanges) {
      final id = c.doc.id;
      if (c.type == DocumentChangeType.removed) {
        _privById.remove(id);
        _syncedPriv.remove(id);
      } else if (c.doc.data() != null) {
        _privById[id] = Map<String, dynamic>.from(c.doc.data()!);
      }
      _upsertUser(id);
    }
    notifyListeners();
  }

  void _onPrivateOne(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return;
    _privById[doc.id] = Map<String, dynamic>.from(data);
    _upsertUser(doc.id);
    notifyListeners();
  }

  void _applySnapshot<T>(_Sync<T> s, QuerySnapshot<Map<String, dynamic>> snap) {
    for (final c in snap.docChanges) {
      final id = c.doc.id;
      if (c.type == DocumentChangeType.removed) {
        s.list.removeWhere((e) => s.idOf(e) == id);
        s.synced.remove(id);
        continue;
      }
      final data = c.doc.data();
      if (data == null) continue;
      try {
        final item = s.fromJson(Map<String, dynamic>.from(data));
        final i = s.list.indexWhere((e) => s.idOf(e) == id);
        if (i >= 0) {
          s.list[i] = item;
        } else {
          s.list.add(item);
        }
        s.synced[id] = s.toJson(item);
      } catch (e) {
        debugPrint('Documento ${s.name}/$id con datos incompletos: $e');
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
