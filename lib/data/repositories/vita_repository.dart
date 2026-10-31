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
import 'package:vita_app/data/services/internet_connectivity_service.dart';
import 'package:vita_app/data/services/livekit_api.dart';
import 'package:vita_app/data/services/livekit_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/data/services/secret_hasher.dart';
import 'package:vita_app/domain/audit_log.dart';
import 'package:vita_app/domain/data_retention.dart';
import 'package:vita_app/domain/legal_versions.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/domain/volunteer_matching.dart';
import 'package:vita_app/domain/volunteer_verification.dart';
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
    required LiveKitCallService jitsi,
    DateTime Function()? clock,
  }) : _jitsi = jitsi,
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
    _supportsSync = _Sync<SupportRequest>(
      'supportRequests',
      _supports,
      (s) => s.id,
      (s) => s.toJson(),
      SupportRequest.fromJson,
    );
    _slotsSync = _Sync<AvailabilitySlot>(
      'slots',
      _slots,
      (s) => s.id,
      (s) => s.toJson(),
      AvailabilitySlot.fromJson,
    );
  }

  final LiveKitCallService _jitsi;
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
  static const _writeTimeout = Duration(seconds: 8);

  /// Un voluntario sin "latido" en este tiempo se considera desconectado.
  static const presenceWindow = kPresenceWindow;

  /// El prototipo permite llamadas fuera de horario para demos académicas.
  static const demoBypassSchedule = true;

  final List<VitaUser> _users = [];
  final List<CallRequest> _requests = [];
  final List<UserReport> _reports = [];
  final List<EmergencyAlert> _alerts = [];
  final List<CallSurvey> _surveys = [];
  final List<AvailabilitySlot> _slots = [];
  final List<SupportRequest> _supports = [];

  late final _Sync<CallRequest> _requestsSync;
  late final _Sync<UserReport> _reportsSync;
  late final _Sync<EmergencyAlert> _alertsSync;
  late final _Sync<CallSurvey> _surveysSync;
  late final _Sync<AvailabilitySlot> _slotsSync;
  late final _Sync<SupportRequest> _supportsSync;

  // Usuarios: parte pública (users/{id}) y parte privada (private/{id}).
  final Map<String, Map<String, dynamic>> _pubById = {};
  final Map<String, Map<String, dynamic>> _privById = {};
  final Map<String, Map<String, dynamic>> _syncedPub = {};
  final Map<String, Map<String, dynamic>> _syncedPriv = {};

  final List<StreamSubscription<dynamic>> _subs = [];
  String? _sessionUserId;

  /// Último problema de sincronización (útil para depurar).
  String? lastSyncError;

  /// Aviso para mostrar cuando coordinación suspende o bloquea la cuenta mientras la persona
  /// tiene la sesión abierta. La pantalla principal lo muestra una vez y lo borra.
  String? accessNotice;
  bool _closingForAccess = false;

  LiveKitCallService get jitsi => _jitsi;

  VitaUser? get currentUser => _users
      .where((u) => u.id == _sessionUserId && u.status != AccountStatus.deleted)
      .firstOrNull;

  List<VitaUser> get users => List.unmodifiable(_users);

  /// Solicitudes; las que quedaron "colgadas" se muestran como vencidas.
  List<CallRequest> get requests =>
      List.unmodifiable(_requests.map(_normalize));

  List<UserReport> get reports => List.unmodifiable(_reports);
  List<EmergencyAlert> get alerts => List.unmodifiable(_alerts);
  List<SupportRequest> get supportRequests => List.unmodifiable(_supports);

  List<AvailabilitySlot> slotsFor(String volunteerId) =>
      _slots.where((s) => s.volunteerId == volunteerId).toList();

  CallRequest _normalize(CallRequest r) {
    final now = _now();
    if ((r.status == CallRequestStatus.searching ||
            r.status == CallRequestStatus.ringing) &&
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
    final hour = _colombiaNow().hour;
    return hour >= serviceStartHour && hour < serviceEndHour;
  }

  String get serviceHoursLabel =>
      'Horario de atención: $serviceStartHour:00 a $serviceEndHour:00';

  // ---------------------------------------------------------------------------
  // Inicio y sesión
  // ---------------------------------------------------------------------------

  Future<void> bootstrap() async {
    String? uid;
    try {
      uid = _auth.currentUser?.uid;
    } catch (e) {
      // Si Firebase no está disponible (por ejemplo, en las pruebas) se muestra la pantalla inicial.
      lastSyncError = e.toString();
      debugPrint('Firebase no disponible al iniciar: $e');
    }
    if (uid != null) {
      try {
        final user = await _fetchUser(uid);
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
    _supports.clear();
    _pubById.clear();
    _privById.clear();
    _syncedPub.clear();
    _syncedPriv.clear();
    for (final s in [
      _requestsSync,
      _reportsSync,
      _alertsSync,
      _surveysSync,
      _slotsSync,
      _supportsSync,
    ]) {
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
    if ((user.role == UserRole.volunteer ||
            user.role == UserRole.psychologist) &&
        user.status == AccountStatus.pending) {
      return const AuthResult.error(
        'Tu cuenta sigue pendiente de verificación.',
      );
    }
    return AuthResult.ok(user);
  }

  String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// El adulto mayor ingresa con teléfono + PIN; por dentro se convierten en
  /// un correo y una clave de Firebase (la clave exige 6 caracteres o más).
  String _elderlyEmail(String phone) =>
      '${_digits(phone)}@telefono.vita.invalid';
  String _elderlyPassword(String pin, String phone) =>
      'vita-$pin-${_digits(phone)}';

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
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final user = await _fetchUser(uid);
      if (user == null ||
          user.status == AccountStatus.deleted ||
          user.role != role) {
        await _auth.signOut();
        return const AuthResult.error(
          'No encontramos esa cuenta para este perfil.',
        );
      }
      if (user.role == UserRole.volunteer &&
          user.status == AccountStatus.pending) {
        // RF3: se confirma el correo con Firebase y se le dice en qué paso va.
        final verified = await _syncEmailVerification(user);
        await _auth.signOut();
        return AuthResult.error(
          volunteerPendingMessage(emailVerified: verified),
        );
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
      final credentialError =
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-email';
      if (lockKey != null && credentialError) {
        return AuthResult.error(
          await _registerFailedAttempt(lockKey, wrong: wrong),
        );
      }
      return AuthResult.error(_authMessage(e, wrong: wrong));
    } catch (e) {
      lastSyncError = e.toString();
      return const AuthResult.error(
        'No se pudo conectar. Revisa tu internet e inténtalo de nuevo.',
      );
    }
  }

  /// RF3: pregunta a Firebase si el correo ya fue verificado y, si es así, lo deja anotado en el
  /// perfil para que coordinación lo vea. Las reglas solo aceptan ese dato si el token lo respalda.
  Future<bool> _syncEmailVerification(VitaUser user) async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) return false;
      await fbUser.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;
      if (verified && !user.emailVerified) {
        await _auth.currentUser!.getIdToken(true);
        await _db
            .collection('users')
            .doc(user.id)
            .set({'emailVerified': true}, SetOptions(merge: true))
            .timeout(_writeTimeout);
      }
      return verified;
    } catch (e) {
      lastSyncError = e.toString();
      return false;
    }
  }

  /// RF3: reenvía el correo de verificación (regeneración del enlace). Devuelve el mensaje a mostrar.
  Future<String> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user;
      final user = fbUser == null ? null : await _fetchUser(fbUser.uid);
      if (fbUser == null || user == null || user.role != UserRole.volunteer) {
        await _auth.signOut();
        return 'No encontramos una cuenta de voluntario con esos datos.';
      }
      await fbUser.reload();
      if (_auth.currentUser?.emailVerified ?? false) {
        await _auth.signOut();
        return volunteerPendingMessage(emailVerified: true);
      }
      await fbUser.sendEmailVerification();
      await _auth.signOut();
      return 'Te enviamos un nuevo correo de verificación. Revisa también la carpeta de spam.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests')
        return 'Espera unos minutos antes de pedir otro correo.';
      return _authMessage(e, wrong: 'Correo o contraseña incorrectos.');
    } catch (_) {
      return 'No se pudo conectar. Revisa tu internet e inténtalo de nuevo.';
    }
  }

  String _elderlyLockKey(String phone) => 'elderly:${_digits(phone)}';
  String _volunteerLockKey(String email) =>
      'volunteer:${email.trim().toLowerCase()}';

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

  Future<String> _registerFailedAttempt(
    String key, {
    required String wrong,
  }) async {
    try {
      final ref = _db.collection('locks').doc(key);
      final snap = await ref.get();
      final data = snap.data();
      var prev = (data?['failedAttempts'] as num?)?.toInt() ?? 0;
      // Si el bloqueo anterior ya venció, se empieza un ciclo nuevo (si no, un solo error
      // más volvería a bloquear 15 minutos).
      final rawUntil = data?['lockedUntil'] as String?;
      final prevUntil = rawUntil == null ? null : DateTime.tryParse(rawUntil);
      if (prevUntil != null && !_now().isBefore(prevUntil)) prev = 0;
      final next = prev + 1;
      if (next >= maxFailedAttempts) {
        final until = _now().add(lockDuration);
        await ref.set({'failedAttempts': next, 'lockedUntil': vitaIso(until)});
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

  Future<AuthResult> loginElderly({
    required String phone,
    required String pin,
  }) async {
    final result = await _login(
      email: _elderlyEmail(phone),
      password: _elderlyPassword(pin, phone),
      role: UserRole.elderly,
      wrong: 'Teléfono o PIN incorrectos.',
      lockKey: _elderlyLockKey(phone),
    );
    if (result.isOk && result.user != null) {
      await _storePinWrap(result.user!, pin);
    }
    return result;
  }

  Future<AuthResult> loginVolunteer({
    required String email,
    required String password,
  }) {
    return _login(
      email: email.trim(),
      password: password,
      role: UserRole.volunteer,
      wrong: 'Correo o contraseña incorrectos.',
      lockKey: _volunteerLockKey(email),
    );
  }

  /// Profesional de apoyo psicológico. No se registra solo: coordinación crea la cuenta.
  Future<AuthResult> loginPsychologist({
    required String email,
    required String password,
  }) {
    return _login(
      email: email.trim(),
      password: password,
      role: UserRole.psychologist,
      wrong: 'Correo o contraseña incorrectos.',
      lockKey: 'psychologist:${email.trim().toLowerCase()}',
    );
  }

  Future<AuthResult> loginCoordinator({
    required String email,
    required String password,
  }) {
    return _login(
      email: email.trim(),
      password: password,
      role: UserRole.coordinator,
      wrong: 'Correo o contraseña incorrectos.',
    );
  }

  Future<void> _writeNewUser(VitaUser user) async {
    await _db
        .collection('users')
        .doc(user.id)
        .set(_publicJson(user))
        .timeout(const Duration(seconds: 15));
    await _db
        .collection('private')
        .doc(user.id)
        .set(_privateJson(user))
        .timeout(const Duration(seconds: 15));
    // Evidencia del consentimiento (RF10): qué versión del texto aceptó y cuándo.
    await _db
        .collection('consents')
        .doc(user.id)
        .set({
          'userId': user.id,
          'role': user.role.name,
          'consentVersion': kConsentVersion,
          'acceptedAt': vitaIso(_now()),
          'acceptedTerms': true,
          'acceptedPrivacy': true,
          'volunteerIdentityDocumentConsent': user.role == UserRole.volunteer,
        })
        .timeout(const Duration(seconds: 15));
    if (user.role == UserRole.volunteer) {
      await _db.collection('presentationConsents').doc(user.id).set({
        'userId': user.id,
        'authorized': user.volunteerPresentationConsent,
        'consentVersion': kConsentVersion,
        'updatedAt': vitaIso(_now()),
      }).timeout(const Duration(seconds: 15));
      await _db.collection('identityConsents').doc(user.id).set({
        'userId': user.id,
        'authorized': user.identityDocumentConsent,
        'consentVersion': kConsentVersion,
        'updatedAt': vitaIso(_now()),
      }).timeout(const Duration(seconds: 15));
    }
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
    if (!consent)
      return const AuthResult.error(
        'Debes aceptar el consentimiento informado.',
      );
    if (!aptitude)
      return const AuthResult.error(
        'Debes confirmar que puedes usar la app de forma autónoma.',
      );
    if (pin.length != 4 || int.tryParse(pin) == null) {
      return const AuthResult.error('El PIN debe tener 4 dígitos.');
    }
    if (_digits(phone).length < 7)
      return const AuthResult.error('Revisa el número de teléfono.');
    if (_ageFrom(birthDate) < 60)
      return const AuthResult.error(
        'El servicio es para personas de 60 años o más.',
      );

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: _elderlyEmail(phone),
        password: _elderlyPassword(pin, phone),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use')
        return const AuthResult.error('Ese teléfono ya está registrado.');
      return AuthResult.error(_authMessage(e, wrong: 'Datos incorrectos.'));
    } catch (_) {
      return const AuthResult.error(
        'No se pudo conectar. Revisa tu internet e inténtalo de nuevo.',
      );
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
      return const AuthResult.error(
        'No se pudo guardar tu registro. Revisa tu internet e inténtalo de nuevo.',
      );
    }
    _pubById[user.id] = _publicJson(user);
    _privById[user.id] = _privateJson(user);
    await _openSession(user);
    await _storePinWrap(user, pin);
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
    required String presentationBio,
    required String presentationInterests,
    required String presentationExperience,
    required bool presentationConsent,
    required String idFrontBase64,
    required String idBackBase64,
    required bool identityDocumentConsent,
  }) async {
    if (!consent)
      return const AuthResult.error('Debes aceptar el tratamiento de datos.');
    if (!identityDocumentConsent || idFrontBase64.isEmpty || idBackBase64.isEmpty) {
      return const AuthResult.error('Debes autorizar el uso de la cédula y cargar el frente y reverso para que coordinación pueda verificar tu identidad.');
    }
    if (!conduct || !inductionDone) {
      return const AuthResult.error(
        'Debes aceptar el código de conducta y completar la inducción.',
      );
    }
    if (_ageFrom(birthDate) < 18)
      return const AuthResult.error('El voluntario debe ser mayor de 18 años.');

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use')
        return const AuthResult.error('Ese correo ya está registrado.');
      return AuthResult.error(_authMessage(e, wrong: 'Datos incorrectos.'));
    } catch (_) {
      return const AuthResult.error(
        'No se pudo conectar. Revisa tu internet e inténtalo de nuevo.',
      );
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
      volunteerBio: presentationBio.trim(),
      volunteerInterests: presentationInterests.trim(),
      volunteerExperience: presentationExperience.trim(),
      volunteerPresentationConsent: presentationConsent,
      idFrontBase64: idFrontBase64,
      idBackBase64: idBackBase64,
      identityDocumentConsent: true,
      idDocumentsUploadedAt: _now(),
    );
    try {
      await _writeNewUser(user);
    } catch (e) {
      lastSyncError = e.toString();
      try {
        await cred.user!.delete();
      } catch (_) {}
      return const AuthResult.error(
        'No se pudo guardar tu registro. Revisa tu internet e inténtalo de nuevo.',
      );
    }
    // RF3: Firebase envía un correo con un enlace para verificar la dirección.
    try {
      await cred.user!.sendEmailVerification();
    } catch (e) {
      // Si falla, el voluntario puede pedir el reenvío desde la pantalla de ingreso.
      debugPrint('No se pudo enviar el correo de verificación: $e');
    }
    // El voluntario queda pendiente: no inicia sesión hasta que coordinación lo apruebe.
    await _auth.signOut();
    return AuthResult.ok(user);
  }

  int _ageFrom(DateTime birth) {
    final now = _now();
    var age = now.year - birth.year;
    final hadBirthday =
        now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
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
    // Un voluntario que cierra sesión deja de estar disponible; si no, la app le seguiría
    // asignando llamadas y el adulto esperaría hasta que venza el tiempo de timbre.
    final me = currentUser;
    if (me != null && me.role == UserRole.volunteer && me.available) {
      _replaceUser(me.copyWith(available: false));
    }
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

  /// Coordinación restablece el PIN tras verificar la identidad por fuera de la app (RF12).
  /// Sin backend (plan Spark) no hay forma segura de validar un código del familiar, por
  /// eso la recuperación pasa siempre por una persona de coordinación.
  Future<void> coordinatorResetElderlyPin({
    required String phone,
    required String newPin,
  }) async {
    final actor = currentUser;
    if (actor == null || actor.role != UserRole.coordinator) {
      throw Exception(
        'Solo coordinación puede restablecer el PIN de esta forma.',
      );
    }
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      throw Exception('El PIN nuevo debe tener 4 dígitos.');
    }
    final digits = _digits(phone);
    if (digits.length < 7) {
      throw Exception('Revisa el número de teléfono.');
    }
    final matches = _users.where(
      (u) =>
          u.role == UserRole.elderly &&
          u.status != AccountStatus.deleted &&
          _digits(u.phone ?? '') == digits,
    );
    if (matches.isEmpty) {
      throw Exception('No hay un adulto mayor con ese teléfono.');
    }
    final target = matches.first;
    final wrapped = _privById[target.id]?['pinWrap'] as String?;
    final oldPin = wrapped == null ? null : unwrapPin(wrapped);
    if (oldPin == null) {
      throw Exception(
        'Esa cuenta aún no tiene PIN recuperable. El adulto debe entrar una vez con su PIN actual.',
      );
    }
    await _changeElderlyPassword(
      uid: target.id,
      phone: target.phone ?? phone,
      currentPin: oldPin,
      newPin: newPin,
    );
    await _clearLock(_elderlyLockKey(phone));
    unawaited(_audit('pin_reset', targetId: target.id));
  }

  /// Guarda el PIN ofuscado en `private/{uid}` (solo lo leen el propio adulto y coordinación).
  Future<void> _storePinWrap(VitaUser user, String pin) async {
    if (user.role != UserRole.elderly) return;
    final wrapped = wrapPin(pin);
    if (_privById[user.id]?['pinWrap'] == wrapped) return;
    try {
      await _db.collection('private').doc(user.id).set({
        'pinWrap': wrapped,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('No se pudo guardar el PIN recuperable: $e');
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
    required String uid,
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
      await db.collection('private').doc(uid).set({
        'pinWrap': wrapPin(newPin),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _authMessage(
          e,
          wrong: 'No se pudo validar la cuenta para cambiar el PIN.',
        ),
      );
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
      throw Exception(
        _authMessage(e, wrong: 'Revisa que el correo esté bien escrito.'),
      );
    }
  }

  Future<void> completePasswordRecovery({
    required String code,
    required String password,
  }) async {
    throw Exception('Usa el enlace que enviamos a tu correo.');
  }

  // ---------------------------------------------------------------------------
  // Perfil y cuenta
  // ---------------------------------------------------------------------------

  /// Cuántos voluntarios pueden atender en este momento (para el inicio).
  int get availableVolunteerCount => _availableVolunteers().length;

  /// Confirma el PIN actual de la persona (se usa antes de acciones delicadas, RF14 y RF37).
  Future<void> verifyPin(String pin) async {
    final user = currentUser;
    final fbUser = _auth.currentUser;
    if (user == null || fbUser == null || user.role != UserRole.elderly) {
      throw Exception('Debes ingresar como adulto mayor.');
    }
    final phone = user.phone ?? '';
    try {
      final credential = EmailAuthProvider.credential(
        email: _elderlyEmail(phone),
        password: _elderlyPassword(pin, phone),
      );
      await fbUser.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authMessage(e, wrong: 'El PIN no es correcto.'));
    }
  }

  /// Confirma la contraseña actual del voluntario (RF14). Lanza un mensaje claro si no coincide.
  Future<void> verifyPassword(String password) async {
    final user = currentUser;
    final fbUser = _auth.currentUser;
    final email = fbUser?.email;
    if (user == null ||
        fbUser == null ||
        email == null ||
        user.role != UserRole.volunteer) {
      throw Exception('Debes ingresar como voluntario.');
    }
    try {
      await fbUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authMessage(e, wrong: 'La contraseña no es correcta.'));
    }
  }

  /// Cambia la contraseña del voluntario: confirma la actual y guarda la nueva (RF14).
  Future<void> changeVolunteerPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw Exception('La contraseña nueva debe tener al menos 6 caracteres.');
    }
    if (newPassword == currentPassword) {
      throw Exception('La contraseña nueva debe ser distinta a la actual.');
    }
    await verifyPassword(currentPassword);
    try {
      await _auth.currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _authMessage(e, wrong: 'No se pudo cambiar la contraseña.'),
      );
    }
  }

  /// Cambia el PIN del adulto mayor: confirma el actual y guarda el nuevo.
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
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
      await _storePinWrap(user, newPin);
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
    if (user.role == UserRole.elderly &&
        phone != null &&
        _digits(phone) != _digits(user.phone ?? '')) {
      throw Exception(
        'Por seguridad, el número de ingreso solo se cambia con ayuda de coordinación.',
      );
    }
    _replaceUser(
      user.copyWith(
        phone: phone,
        familyName: familyName,
        familyPhone: familyPhone,
        alternateName: alternateName,
        alternatePhone: alternatePhone,
      ),
    );
    await _commit();
  }

  Future<void> updateVolunteerPresentation({
    required String bio,
    required String interests,
    required String experience,
    required bool consent,
  }) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer) return;
    _replaceUser(user.copyWith(
      volunteerBio: bio.trim(),
      volunteerInterests: interests.trim(),
      volunteerExperience: experience.trim(),
      volunteerPresentationConsent: consent,
      volunteerPresentationReviewed: false,
      clearVolunteerPresentationPhoto: true,
    ));
    await _db.collection('presentationConsents').doc(user.id).set({
      'userId': user.id,
      'authorized': consent,
      'consentVersion': kConsentVersion,
      'updatedAt': vitaIso(_now()),
    });
    await _commit();
  }

  Future<void> reviewVolunteerPresentation(String userId, {required bool approve}) async {
    final i = _indexOf(userId);
    if (i < 0 || _users[i].role != UserRole.volunteer) return;
    final user = _users[i];
    _users[i] = user.copyWith(
      volunteerPresentationReviewed: approve,
      volunteerPresentationPhoto: approve && user.volunteerPresentationConsent ? user.photoBase64 : null,
      clearVolunteerPresentationPhoto: !approve || !user.volunteerPresentationConsent,
    );
    await _commit();
    unawaited(_audit(approve ? 'volunteer_profile_approved' : 'volunteer_profile_rejected', targetId: userId));
  }

  Future<void> saveVolunteerIdentityDocuments({required String front, required String back}) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer) return;
    if (front.isEmpty || back.isEmpty) throw Exception('Carga el frente y el reverso de la cédula.');
    _replaceUser(user.copyWith(
      idFrontBase64: front,
      idBackBase64: back,
      identityVerified: false,
      identityDocumentConsent: true,
      idDocumentsUploadedAt: _now(),
      clearIdentityVerification: true,
    ));
    await _db.collection('identityConsents').doc(user.id).set({
      'userId': user.id,
      'authorized': true,
      'consentVersion': kConsentVersion,
      'updatedAt': vitaIso(_now()),
    });
    await _commit();
  }

  Future<void> withdrawVolunteerIdentityConsent() async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer) return;
    _replaceUser(user.copyWith(
      clearIdFront: true,
      clearIdBack: true,
      identityDocumentConsent: false,
      identityVerified: false,
      clearIdDocumentsUploadedAt: true,
      clearIdentityVerification: true,
      clearDocumentId: true,
    ));
    await _db.collection('identityConsents').doc(user.id).set({
      'userId': user.id,
      'authorized': false,
      'consentVersion': kConsentVersion,
      'updatedAt': vitaIso(_now()),
    });
    await _commit();
  }

  Future<void> verifyVolunteerIdentity(String userId) async {
    final i = _indexOf(userId);
    if (i < 0 || _users[i].role != UserRole.volunteer) return;
    final user = _users[i];
    if (!user.identityDocumentConsent) {
      throw Exception('El voluntario no autorizó el tratamiento de la cédula.');
    }
    if (user.idFrontBase64 == null || user.idBackBase64 == null) {
      throw Exception('El voluntario debe cargar el frente y el reverso de la cédula.');
    }
    final coordinator = currentUser;
    final verifiedUser = user.copyWith(
      clearIdFront: true,
      clearIdBack: true,
      clearIdDocumentsUploadedAt: true,
      clearDocumentId: true,
      identityVerified: true,
      identityVerifiedAt: _now(),
      identityVerifiedBy: coordinator?.id,
    );
    // Borra las imágenes del documento privado antes de publicar la marca de verificación.
    await _db.collection('private').doc(user.id).set(
      _privateJson(verifiedUser),
      SetOptions(merge: true),
    );
    _users[i] = verifiedUser;
    await _commit();
    unawaited(_audit('volunteer_identity_verified', targetId: userId));
  }

  /// Guarda la foto de perfil de quien tiene la sesión abierta (o la quita si [photoBase64] es
  /// null). Va en `private/{uid}`, así que solo la ven esa persona y coordinación.
  Future<void> setProfilePhoto(String? photoBase64) async {
    final user = currentUser;
    if (user == null) return;
    _replaceUser(
      user.copyWith(
        photoBase64: photoBase64,
        clearPhoto: photoBase64 == null,
        volunteerPresentationReviewed: false,
        clearVolunteerPresentationPhoto: true,
      ),
    );
    await _commit();
  }

  Future<void> requestAccountDeletion() async {
    final user = currentUser;
    if (user == null) return;
    _replaceUser(
      user.copyWith(
        status: AccountStatus.deleted,
        available: false,
        displayName: 'Cuenta eliminada',
      ),
    );
    await _commit();
    await _logDataRequest(user);
    try {
      await _db
          .collection('private')
          .doc(user.id)
          .delete()
          .timeout(_writeTimeout);
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
      throw Exception(
        'No puedes cambiar la disponibilidad durante una videollamada.',
      );
    }
    if (available && !isVolunteerInShift(user.id)) {
      throw Exception('Estás fuera de tu horario programado.');
    }
    _replaceUser(
      user.copyWith(
        available: available,
        lastSeenAt: available ? _now() : null,
      ),
    );
    await _commit();
  }

  /// "Latido" del voluntario: mientras la app está abierta y está disponible, avisa que sigue ahí.
  Future<void> touchPresence() async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer || !user.available)
      return;
    _replaceUser(user.copyWith(lastSeenAt: _now()));
    await _commit();
  }

  /// Hora de Colombia (UTC-5, sin horario de verano), sin importar la zona horaria del celular.
  /// Los horarios de atención y las franjas de los voluntarios se miden con esta hora; si no,
  /// un emulador en UTC o un celular mal configurado dan "fuera de tu horario" a deshoras.
  DateTime _colombiaNow() => colombiaTime(_now());

  bool isVolunteerInShift(String volunteerId) {
    return isInShift(slotsFor(volunteerId), _colombiaNow());
  }

  Future<void> addSlot({
    required int weekday,
    required int startHour,
    required int endHour,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (endHour <= startHour)
      throw Exception('La hora final debe ser posterior a la inicial.');
    final overlap = slotsFor(user.id).any(
      (s) =>
          s.weekday == weekday &&
          startHour < s.endHour &&
          endHour > s.startHour,
    );
    if (overlap)
      throw Exception('Ese horario se cruza con otro turno ya guardado.');
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

  Future<CallRequest> startCallRequest({bool audioOnly = false}) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.elderly) {
      throw Exception('Debes ingresar como adulto mayor.');
    }
    if (!isWithinServiceHours) {
      throw Exception('Fuera de horario. $serviceHoursLabel');
    }
    if (!await InternetConnectivityService.hasInternetConnection()) {
      throw Exception(
        'No hay conexión a internet. Conéctate e intenta de nuevo.',
      );
    }

    // Si quedó una llamada "conectada" de antes (por ejemplo, se cerró la app a medias),
    // se cierra: la persona está pidiendo una nueva y el voluntario debe quedar libre.
    for (final r in List<CallRequest>.from(_requests)) {
      if (r.elderlyId == user.id && r.status == CallRequestStatus.connected) {
        await finishCall(r.id, status: CallRequestStatus.interrupted);
      }
    }

    // Solicitudes que quedaron abiertas (por ejemplo, se salió de la pantalla sin cancelar):
    // se cierran para que no dejen "ocupado" a un voluntario ni se reutilicen ya vencidas.
    for (final r in List<CallRequest>.from(_requests)) {
      final open =
          r.status == CallRequestStatus.searching ||
          r.status == CallRequestStatus.ringing;
      if (r.elderlyId == user.id &&
          open &&
          _now().difference(r.createdAt) > const Duration(seconds: 45)) {
        final i = _requests.indexWhere((x) => x.id == r.id);
        _requests[i] = r.copyWith(
          status: CallRequestStatus.cancelled,
          endedAt: _now(),
        );
      }
    }

    final existing = activeRequest;
    if (existing != null) return existing;

    // El código solo sirve para que otro celular encuentre esta solicitud y entre a su sala.
    final code = (_random.nextInt(900000) + 100000).toString();
    final request = CallRequest(
      id: _uuid.v4(),
      elderlyId: user.id,
      // RF6: sala de nombre aleatorio y único (no derivada del código de 6 dígitos).
      roomName: 'VITA_${_uuid.v4().replaceAll('-', '')}',
      joinCode: code,
      status: CallRequestStatus.searching,
      createdAt: _now(),
      audioOnly: audioOnly,
    );
    _requests.add(request);
    await _commit();
    await assignVolunteer(request.id);
    return _requests.firstWhere((r) => r.id == request.id);
  }

  List<VitaUser> _availableVolunteers({
    String? excludeId,
    String? ignoreRequestId,
  }) {
    // Se usan las solicitudes normalizadas: una solicitud vieja que quedó "ringing" o "connected"
    // no debe dejar al voluntario como ocupado para siempre.
    return selectVolunteers(
      users: _users,
      requests: requests,
      slots: _slots,
      now: _now(),
      excludeId: excludeId,
      ignoreRequestId: ignoreRequestId,
      presenceWindow: presenceWindow,
      requireRecentPresence: false,
    );
  }

  /// Voluntario de la llamada cortada, al que se intenta llamar primero (RF35).
  String? _preferredVolunteerId;

  /// RF35 – "Llamar de nuevo": crea una solicitud nueva que prefiere al mismo voluntario si sigue
  /// disponible; si no, el emparejamiento normal busca a otro.
  Future<CallRequest> recallAfterInterruption(
    String interruptedRequestId, {
    bool audioOnly = false,
  }) async {
    final i = _requests.indexWhere((r) => r.id == interruptedRequestId);
    _preferredVolunteerId = i < 0 ? null : _requests[i].volunteerId;
    try {
      return await startCallRequest(audioOnly: audioOnly);
    } finally {
      _preferredVolunteerId = null;
    }
  }

  Future<CallRequest> assignVolunteer(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Solicitud no encontrada.');
    final request = _requests[index];
    final volunteer = chooseVolunteer(
      users: _users,
      requests: requests,
      slots: _slots,
      now: _now(),
      requestId: request.id,
      previousVolunteerId: request.volunteerId,
      preferredId: _preferredVolunteerId,
      presenceWindow: presenceWindow,
      requireRecentPresence: false,
    );
    if (volunteer == null) {
      _requests[index] = request.copyWith(status: CallRequestStatus.expired);
      await _commit();
      return _requests[index];
    }
    _requests[index] = request.copyWith(
      volunteerId: volunteer.id,
      status: CallRequestStatus.ringing,
    );
    await _commit();
    unawaited(
      LiveKitApi.notifyIncomingCall(requestId)
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('No se pudo enviar el aviso al voluntario: $error');
          }),
    );
    return _requests[index];
  }

  Future<void> cancelRequest(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    final request = _requests[index];
    if (request.status == CallRequestStatus.connected) return;
    _requests[index] = request.copyWith(
      status: CallRequestStatus.cancelled,
      endedAt: _now(),
    );
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
    _requests[index] = request.copyWith(
      status: CallRequestStatus.connected,
      startedAt: _now(),
    );
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
    if (snap.docs.isEmpty)
      throw Exception('No hay una solicitud con ese código.');

    final found = CallRequest.fromJson(
      Map<String, dynamic>.from(snap.docs.first.data()),
    );
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

  Future<void> finishCall(
    String requestId, {
    CallRequestStatus status = CallRequestStatus.completed,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    final request = _requests[index];
    // La señal de "se cortó" puede llegar antes que la de "terminó": no se sobrescribe.
    if (request.status == CallRequestStatus.interrupted &&
        status == CallRequestStatus.completed)
      return;
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
        _replaceUser(
          volunteer.copyWith(
            lastCallAt: _now(),
            available: true,
            lastSeenAt: volunteer.id == _sessionUserId ? _now() : null,
          ),
        );
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
    _callInProgressId = request.id;
    try {
      if (!await InternetConnectivityService.hasInternetConnection()) {
        throw Exception(
          'No hay conexión a internet para iniciar la llamada. Conéctate e intenta de nuevo.',
        );
      }
      await _jitsi.join(
        roomName: request.roomName,
        requestId: request.id,
        displayName: user.displayName,
        userId: user.id,
        profilePhotoBase64: user.photoBase64,
        audioOnly: request.audioOnly,
        onTerminated: () {
          _callInProgressId = null;
          finishCall(request.id);
        },
        // RF35: una llamada que se corta por un problema queda como "interrumpida".
        onInterrupted: () {
          _callInProgressId = null;
          finishCall(request.id, status: CallRequestStatus.interrupted);
        },
      );
    } catch (_) {
      _callInProgressId = null;
      await finishCall(request.id, status: CallRequestStatus.interrupted);
      rethrow;
    }
  }

  /// Llamada de LiveKit que este celular tiene abierta ahora mismo.
  String? _callInProgressId;

  /// Si la otra persona ya terminó la llamada (se ve en Firestore), se cuelga la de este celular.
  /// LiveKit solo avisa cuando alguien SE VA; si uno cuelga antes de que el otro llegue a conectarse,
  /// el que queda se quedaría solo en la sala sin que nada lo saque.
  void _hangUpIfEnded() {
    final id = _callInProgressId;
    if (id == null) return;
    final i = _requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final status = _requests[i].status;
    if (status == CallRequestStatus.completed ||
        status == CallRequestStatus.interrupted ||
        status == CallRequestStatus.cancelled) {
      _callInProgressId = null;
      _jitsi.hangUp();
    }
  }

  // ---------------------------------------------------------------------------
  // Apoyo psicológico dentro de la llamada
  //
  //  1. El voluntario nota a la persona muy triste y pulsa "Pedir apoyo psicológico".
  //  2. Se crea una SupportRequest (open) con la sala de la llamada.
  //  3. Un psicólogo la acepta (solo uno; se decide con una transacción) y entra a la sala.
  //  4. Al terminar, el psicólogo (o el voluntario) la cierra.
  // ---------------------------------------------------------------------------

  /// Solicitud de apoyo activa (abierta o aceptada) de una llamada, si hay.
  SupportRequest? activeSupportFor(String callId) => _supports
      .where(
        (s) =>
            s.callId == callId &&
            (s.status == SupportStatus.open ||
                s.status == SupportStatus.accepted),
      )
      .firstOrNull;

  /// Solicitudes que un psicólogo puede tomar ahora, la más antigua primero.
  List<SupportRequest> get openSupportRequests =>
      _supports.where((s) => s.status == SupportStatus.open).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Solicitudes que este psicólogo ya aceptó y siguen en curso.
  List<SupportRequest> get mySupportInProgress {
    final me = currentUser;
    if (me == null) return const [];
    return _supports
        .where(
          (s) =>
              s.status == SupportStatus.accepted && s.psychologistId == me.id,
        )
        .toList();
  }

  /// El voluntario pide que un psicólogo se una a la llamada [callId].
  Future<SupportRequest> requestPsychologistSupport({
    required String callId,
    String? note,
  }) async {
    final me = currentUser;
    if (me == null || me.role != UserRole.volunteer) {
      throw Exception('Solo un voluntario puede pedir apoyo psicológico.');
    }
    final call = _requests.where((r) => r.id == callId).firstOrNull;
    if (call == null || call.volunteerId != me.id) {
      throw Exception('Esa llamada no es tuya.');
    }
    if (call.status != CallRequestStatus.connected) {
      throw Exception(
        'Solo se puede pedir apoyo durante una llamada en curso.',
      );
    }
    final existing = activeSupportFor(callId);
    if (existing != null) return existing;
    final request = SupportRequest(
      id: _uuid.v4(),
      callId: callId,
      roomName: call.roomName,
      requestedById: me.id,
      elderlyId: call.elderlyId,
      note: note,
      createdAt: _now(),
    );
    _supports.add(request);
    await _commit();
    return request;
  }

  /// El voluntario cancela la solicitud (por ejemplo, la persona ya se sintió mejor).
  Future<void> cancelSupport(String id) async {
    final i = _supports.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = _supports[i];
    if (s.status != SupportStatus.open) return;
    _supports[i] = s.copyWith(
      status: SupportStatus.cancelled,
      closedAt: _now(),
    );
    await _commit();
  }

  /// Un psicólogo toma la solicitud. Con transacción, para que dos no la acepten a la vez.
  Future<SupportRequest> acceptSupport(String id) async {
    final me = currentUser;
    if (me == null || me.role != UserRole.psychologist) {
      throw Exception('Solo un psicólogo puede aceptar esta solicitud.');
    }
    final ref = _db.collection('supportRequests').doc(id);
    final now = _now();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw Exception('La solicitud ya no existe.');
      if (data['status'] != SupportStatus.open.name) {
        throw Exception('Otro profesional ya tomó esta solicitud.');
      }
      tx.update(ref, {
        'status': SupportStatus.accepted.name,
        'psychologistId': me.id,
        'acceptedAt': vitaIso(now),
      });
    });
    final i = _supports.indexWhere((s) => s.id == id);
    if (i < 0) throw Exception('Solicitud no encontrada.');
    final updated = _supports[i].copyWith(
      status: SupportStatus.accepted,
      psychologistId: me.id,
      acceptedAt: now,
    );
    _supports[i] = updated;
    _supportsSync.synced[id] = updated.toJson();
    notifyListeners();
    return updated;
  }

  /// El psicólogo entra a la sala de la llamada. Termina cuando sale.
  Future<void> joinSupportCall(String supportId) async {
    final me = currentUser;
    final i = _supports.indexWhere((s) => s.id == supportId);
    if (me == null || me.role != UserRole.psychologist || i < 0) {
      throw Exception('No hay una solicitud de apoyo para unirte.');
    }
    final support = _supports[i];
    if (support.status != SupportStatus.accepted ||
        support.psychologistId != me.id) {
      throw Exception('Primero debes aceptar la solicitud.');
    }
    if (!await InternetConnectivityService.hasInternetConnection()) {
      throw Exception('No hay conexión a internet para entrar a la llamada.');
    }
    final call = requests.cast<CallRequest?>().firstWhere(
      (request) => request?.id == support.callId,
      orElse: () => null,
    );
    await _jitsi.join(
      roomName: support.roomName,
      requestId: support.callId,
      supportRequestId: support.id,
      announceAs: me.displayName,
      displayName: me.displayName,
      userId: me.id,
      profilePhotoBase64: me.photoBase64,
      audioOnly: call?.audioOnly ?? false,
      // Al salir, el psicólogo cierra su participación; la llamada del voluntario sigue o termina sola.
      onTerminated: () => closeSupport(supportId),
      onInterrupted: () => closeSupport(supportId),
    );
  }

  /// Cierra la solicitud (la llamada de apoyo terminó).
  Future<void> closeSupport(String id) async {
    final i = _supports.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = _supports[i];
    if (s.status == SupportStatus.closed ||
        s.status == SupportStatus.cancelled) {
      return;
    }
    _supports[i] = s.copyWith(status: SupportStatus.closed, closedAt: _now());
    await _commit();
  }

  /// Coordinación crea la cuenta de un psicólogo (nadie se registra solo como profesional).
  /// Se usa una app secundaria de Firebase para no cerrar la sesión de coordinación, y se
  /// envía un correo para que el profesional elija su propia contraseña.
  Future<void> createPsychologist({
    required String name,
    required String email,
    String? phone,
  }) async {
    final actor = currentUser;
    if (actor == null || actor.role != UserRole.coordinator) {
      throw Exception('Solo coordinación puede crear profesionales de apoyo.');
    }
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    if (cleanName.length < 3) throw Exception('Escribe el nombre completo.');
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception('Revisa el correo.');
    }
    final app = await _pinResetApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    try {
      // Contraseña temporal aleatoria: nadie la conoce; el profesional la cambia por correo.
      final temp = '${_uuid.v4()}${_uuid.v4()}'
          .replaceAll('-', '')
          .substring(0, 24);
      final cred = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: temp,
      );
      final user = VitaUser(
        id: cred.user!.uid,
        role: UserRole.psychologist,
        displayName: cleanName,
        // Nace "pendiente" (lo exigen las reglas de Firestore); coordinación la activa abajo.
        status: AccountStatus.pending,
        phone: phone?.trim(),
        email: cleanEmail,
        consentAccepted: true,
        conductAccepted: true,
        inductionDone: true,
        onboardingDone: true,
        createdAt: _now(),
      );
      await db
          .collection('users')
          .doc(user.id)
          .set(_publicJson(user))
          .timeout(const Duration(seconds: 15));
      await db
          .collection('private')
          .doc(user.id)
          .set(_privateJson(user))
          .timeout(const Duration(seconds: 15));
      // Ahora coordinación (sesión principal) activa la cuenta.
      await _db
          .collection('users')
          .doc(user.id)
          .set({'status': AccountStatus.active.name}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      await auth.sendPasswordResetEmail(email: cleanEmail);
      unawaited(_audit('psychologist_created', targetId: user.id));
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.code == 'email-already-in-use'
            ? 'Ese correo ya está registrado.'
            : _authMessage(e, wrong: 'No se pudo crear la cuenta.'),
      );
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
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
        available:
            decision == ReportStatus.suspended ||
                decision == ReportStatus.blocked
            ? false
            : _users[reportedIndex].available,
      );
    }
    await _commit();
    unawaited(
      _audit('report_resolved', targetId: reportId, detail: decision.name),
    );
  }

  Future<void> addAlert({
    required String callId,
    required String elderlyId,
    String? note,
  }) async {
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
    _surveys.removeWhere(
      (s) => s.callId == survey.callId && s.userId == survey.userId,
    );
    _surveys.add(survey);
    await _commit();
  }

  Future<void> approveVolunteer(String userId, {required bool approve}) async {
    final i = _indexOf(userId);
    if (i < 0) return;
    // RF3: no se aprueba a quien no haya verificado su correo. Rechazar siempre se puede.
    if (approve && !canApproveVolunteer(_users[i])) return;
    _users[i] = _users[i].copyWith(
      status: approve ? AccountStatus.active : AccountStatus.blocked,
    );
    await _commit();
    unawaited(
      _audit(
        approve ? 'volunteer_approved' : 'volunteer_rejected',
        targetId: userId,
      ),
    );
  }

  /// RF9: suspende la cuenta reportada mientras coordinación revisa el reporte (que sigue pendiente).
  Future<void> suspendWhileReviewing(String reportId) async {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index < 0) return;
    final i = _indexOf(_reports[index].reportedId);
    if (i < 0) return;
    _users[i] = _users[i].copyWith(
      status: AccountStatus.suspended,
      available: false,
    );
    await _commit();
    unawaited(
      _audit(
        'account_suspended',
        targetId: _users[i].id,
        detail: 'mientras se revisa un reporte',
      ),
    );
  }

  Future<void> setAccountStatus(String userId, AccountStatus status) async {
    final i = _indexOf(userId);
    if (i < 0) return;
    _users[i] = _users[i].copyWith(
      status: status,
      available: status == AccountStatus.active ? _users[i].available : false,
    );
    await _commit();
    unawaited(
      _audit(
        status == AccountStatus.active
            ? 'account_reactivated'
            : status == AccountStatus.blocked
            ? 'account_blocked'
            : 'account_suspended',
        targetId: userId,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Seguimiento de emergencias (RF11 · F8.7, F8.9 y F8.11)
  // ---------------------------------------------------------------------------

  Future<void> _updateAlert(
    String id,
    EmergencyAlert Function(EmergencyAlert) change,
  ) async {
    final me = currentUser;
    if (me == null || me.role != UserRole.coordinator) return;
    final i = _alerts.indexWhere((a) => a.id == id);
    if (i < 0) return;
    _alerts[i] = change(_alerts[i]);
    await _commit();
  }

  /// Si la alerta seguía abierta, pasa a «en atención» y queda anotado quién la tomó.
  EmergencyAlert _asTaken(EmergencyAlert a) => a.status == AlertStatus.open
      ? a.copyWith(
          status: AlertStatus.inProgress,
          takenById: currentUser?.id,
          takenAt: _now(),
        )
      : a;

  Future<void> takeAlert(String id) => _updateAlert(id, _asTaken);

  /// Anota que se le avisó al familiar y por qué canal («whatsapp» o «llamada»).
  Future<void> notifyFamily(String id, {required String channel}) =>
      _updateAlert(
        id,
        (a) =>
            _asTaken(a)
                .copyWith(familyNotifiedAt: _now(), familyChannel: channel),
      );

  /// Anota que se le avisó al contacto alternativo.
  Future<void> notifyAlternate(String id, {required String channel}) =>
      _updateAlert(
        id,
        (a) => _asTaken(a).copyWith(alternateNotifiedAt: _now()),
      );

  Future<void> setFamilyOutcome(String id, FamilyOutcome outcome) =>
      _updateAlert(id, (a) => a.copyWith(familyOutcome: outcome));

  Future<void> setAlternateOutcome(String id, FamilyOutcome outcome) =>
      _updateAlert(id, (a) => a.copyWith(alternateOutcome: outcome));

  /// Cierra la alerta, con una nota opcional de lo que se hizo.
  Future<void> resolveAlert(String id, {String? note}) async {
    final clean = (note == null || note.trim().isEmpty) ? null : note.trim();
    await _updateAlert(
      id,
      (a) => a.copyWith(
        status: AlertStatus.resolved,
        resolvedAt: _now(),
        resolvedById: currentUser?.id,
        resolutionNote: clean,
      ),
    );
    unawaited(_audit('alert_resolved', targetId: id));
  }

  // ---------------------------------------------------------------------------
  // Privacidad y seguridad (RF44 · F18.7)
  // ---------------------------------------------------------------------------

  /// Días que se conservan los datos de llamadas, reportes y alertas antes de anonimizarlos.
  int retentionDays = kDefaultRetentionDays;

  Future<void> loadPrivacyConfig() async {
    try {
      final snap = await _db
          .collection('config')
          .doc('privacy')
          .get()
          .timeout(_writeTimeout);
      final value = snap.data()?['retentionDays'];
      if (value is num) retentionDays = clampRetention(value.toInt());
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo leer la configuración de privacidad: $e');
    }
  }

  Future<void> saveRetentionDays(int days) async {
    final me = currentUser;
    if (me == null || me.role != UserRole.coordinator) return;
    final value = clampRetention(days);
    await _db
        .collection('config')
        .doc('privacy')
        .set({
          'retentionDays': value,
          'updatedAt': vitaIso(_now()),
          'updatedBy': me.id,
        }, SetOptions(merge: true))
        .timeout(_writeTimeout);
    retentionDays = value;
    notifyListeners();
    unawaited(_audit('retention_changed', detail: '$value días'));
  }

  /// Cuántos registros ya superaron el tiempo de retención y todavía tienen datos personales.
  Map<String, int> get expiredCounts {
    final now = _now();
    return {
      'Llamadas': _requests
          .where(
            (r) =>
                r.elderlyId != kAnonymized &&
                isExpired(r.createdAt, now, retentionDays),
          )
          .length,
      'Reportes': _reports
          .where(
            (r) =>
                r.reportedId != kAnonymized &&
                isExpired(r.createdAt, now, retentionDays),
          )
          .length,
      'Alertas': _alerts
          .where(
            (a) =>
                !a.isAnonymized && isExpired(a.createdAt, now, retentionDays),
          )
          .length,
    };
  }

  /// Quita los datos personales de las llamadas, reportes y alertas que superaron la retención.
  /// Devuelve cuántos registros se anonimizaron.
  Future<int> anonymizeExpiredData() async {
    final me = currentUser;
    if (me == null || me.role != UserRole.coordinator) return 0;
    final now = _now();
    var count = 0;
    for (var i = 0; i < _requests.length; i++) {
      final r = _requests[i];
      if (r.elderlyId != kAnonymized &&
          isExpired(r.createdAt, now, retentionDays)) {
        _requests[i] = r.anonymized();
        count++;
      }
    }
    for (var i = 0; i < _reports.length; i++) {
      final r = _reports[i];
      if (r.reportedId != kAnonymized &&
          isExpired(r.createdAt, now, retentionDays)) {
        _reports[i] = r.anonymized();
        count++;
      }
    }
    for (var i = 0; i < _alerts.length; i++) {
      final a = _alerts[i];
      if (!a.isAnonymized && isExpired(a.createdAt, now, retentionDays)) {
        _alerts[i] = a.anonymized();
        count++;
      }
    }
    for (var i = 0; i < _supports.length; i++) {
      final sp = _supports[i];
      if (!sp.isAnonymized && isExpired(sp.createdAt, now, retentionDays)) {
        _supports[i] = sp.anonymized();
        count++;
      }
    }
    if (count > 0) {
      await _commit();
      unawaited(_audit('data_anonymized', detail: '$count registros'));
    }
    return count;
  }

  /// Registro de acciones de seguridad hechas por coordinación (las 30 más recientes).
  Stream<List<AuditEntry>> auditStream() {
    return _db
        .collection('auditLogs')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AuditEntry.fromJson(d.data())).toList(),
        );
  }

  Future<void> _audit(String action, {String? targetId, String? detail}) async {
    final me = currentUser;
    if (me == null || me.role != UserRole.coordinator) return;
    try {
      final entry = AuditEntry(
        id: _uuid.v4(),
        actorId: me.id,
        actorName: me.displayName,
        action: action,
        targetId: targetId,
        detail: detail,
        createdAt: _now(),
      );
      await _db
          .collection('auditLogs')
          .doc(entry.id)
          .set(entry.toJson())
          .timeout(_writeTimeout);
    } catch (e) {
      debugPrint('No se pudo registrar la auditoría: $e');
    }
  }

  /// Deja constancia (sin identidad) de una solicitud de supresión de datos que se atendió al instante.
  Future<void> _logDataRequest(VitaUser user) async {
    try {
      await _db
          .collection('dataRequests')
          .doc(_uuid.v4())
          .set({
            'type': 'supresion',
            'role': user.role.name,
            'requestedAt': vitaIso(_now()),
            'attendedAt': vitaIso(_now()),
            'method': 'automática',
          })
          .timeout(_writeTimeout);
    } catch (e) {
      debugPrint('No se pudo registrar la solicitud de supresión: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadDataRequests() async {
    final snap = await _db
        .collection('dataRequests')
        .orderBy('requestedAt', descending: true)
        .limit(20)
        .get()
        .timeout(_writeTimeout);
    return snap.docs.map((d) => d.data()).toList();
  }

  VitaUser? userById(String id) => _users.cast<VitaUser?>().firstWhere(
    (u) => u?.id == id,
    orElse: () => null,
  );

  Duration volunteerHours(String volunteerId) {
    var total = Duration.zero;
    for (final request in _requests) {
      if (request.volunteerId == volunteerId &&
          request.status == CallRequestStatus.completed) {
        total += request.duration;
      }
    }
    return total;
  }

  int get completedCalls =>
      _requests.where((r) => r.status == CallRequestStatus.completed).length;

  Duration get averageDuration {
    final done = _requests
        .where(
          (r) => r.status == CallRequestStatus.completed && r.startedAt != null,
        )
        .toList();
    if (done.isEmpty) return Duration.zero;
    final ms =
        done.fold<int>(0, (p, r) => p + r.duration.inMilliseconds) ~/
        done.length;
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
    'lastCallAt': u.lastCallAt == null ? null : vitaIso(u.lastCallAt!),
    'lastSeenAt': u.lastSeenAt == null ? null : vitaIso(u.lastSeenAt!),
    'emailVerified': u.emailVerified,
    'createdAt': u.createdAt == null ? null : vitaIso(u.createdAt!),
    'volunteerPresentationConsent': u.volunteerPresentationConsent,
    'volunteerPresentationReviewed': u.volunteerPresentationReviewed,
    'identityVerified': u.identityVerified,
    'volunteerBio': u.role == UserRole.volunteer && u.volunteerPresentationConsent && u.volunteerPresentationReviewed ? u.volunteerBio : null,
    'volunteerInterests': u.role == UserRole.volunteer && u.volunteerPresentationConsent && u.volunteerPresentationReviewed ? u.volunteerInterests : null,
    'volunteerExperience': u.role == UserRole.volunteer && u.volunteerPresentationConsent && u.volunteerPresentationReviewed ? u.volunteerExperience : null,
    'volunteerPresentationPhoto': u.role == UserRole.volunteer && u.volunteerPresentationConsent && u.volunteerPresentationReviewed ? u.volunteerPresentationPhoto : null,
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
    'photoBase64': u.photoBase64,
    'volunteerBio': u.volunteerBio,
    'volunteerInterests': u.volunteerInterests,
    'volunteerExperience': u.volunteerExperience,
    'idFrontBase64': u.idFrontBase64,
    'idBackBase64': u.idBackBase64,
    'identityDocumentConsent': u.identityDocumentConsent,
    'idDocumentsUploadedAt': u.idDocumentsUploadedAt == null ? null : vitaIso(u.idDocumentsUploadedAt!),
    'identityVerifiedAt': u.identityVerifiedAt == null ? null : vitaIso(u.identityVerifiedAt!),
    'identityVerifiedBy': u.identityVerifiedBy,
  };

  Future<void> _commit() async {
    notifyListeners();
    await _push();
  }

  /// Solo los campos que cambiaron respecto a lo último conocido del servidor.
  Map<String, dynamic> _changed(
    Map<String, dynamic>? old,
    Map<String, dynamic> now,
  ) {
    if (old == null) return Map<String, dynamic>.from(now);
    final out = <String, dynamic>{};
    for (final e in now.entries) {
      if (!old.containsKey(e.key) || old[e.key] != e.value)
        out[e.key] = e.value;
    }
    return out;
  }

  Future<void> _set(
    String collection,
    String id,
    Map<String, dynamic> data,
    void Function() onOk,
  ) async {
    try {
      await _db
          .collection(collection)
          .doc(id)
          .set(data, SetOptions(merge: true))
          .timeout(_writeTimeout);
      onOk();
    } on TimeoutException {
      // Sin conexión: Firestore guarda la escritura y la envía al reconectar.
      onOk();
      lastSyncError =
          'Sin confirmación del servidor; se enviará al reconectar.';
    } catch (e) {
      lastSyncError = 'No se pudo guardar $collection/$id: $e';
      debugPrint(lastSyncError);
    }
  }

  Future<void> _delete(
    String collection,
    String id,
    void Function() onOk,
  ) async {
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
          writes.add(
            _set('private', u.id, chPriv, () => _syncedPriv[u.id] = priv),
          );
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
          if (!ids.contains(id))
            writes.add(_delete(s.name, id, () => s.synced.remove(id)));
        }
      }
    }

    collect(_requestsSync);
    collect(_reportsSync);
    collect(_alertsSync);
    collect(_surveysSync);
    collect(_supportsSync);
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

    _subs.add(
      _db
          .collection('users')
          .snapshots()
          .listen(_onUsers, onError: _onSyncError),
    );
    _listen(
      _db.collection('slots'),
      (snap) => _applySnapshot(_slotsSync, snap),
    );

    if (role == UserRole.coordinator) {
      _subs.add(
        _db
            .collection('private')
            .snapshots()
            .listen(_onPrivateAll, onError: _onSyncError),
      );
      _listen(_db.collection('requests'), (snap) {
        _applySnapshot(_requestsSync, snap);
        _hangUpIfEnded();
      });
      _listen(
        _db.collection('reports'),
        (snap) => _applySnapshot(_reportsSync, snap),
      );
      _listen(
        _db.collection('alerts'),
        (snap) => _applySnapshot(_alertsSync, snap),
      );
      _listen(
        _db.collection('surveys'),
        (snap) => _applySnapshot(_surveysSync, snap),
      );
      _listen(
        _db.collection('supportRequests'),
        (snap) => _applySnapshot(_supportsSync, snap),
      );
    } else {
      _subs.add(
        _db
            .collection('private')
            .doc(me)
            .snapshots()
            .listen(_onPrivateOne, onError: _onSyncError),
      );
      if (role == UserRole.psychologist) {
        // El psicólogo solo ve solicitudes de apoyo, no las llamadas de los demás.
        _listen(
          _db.collection('supportRequests'),
          (snap) => _applySnapshot(_supportsSync, snap),
        );
      } else {
        final field = role == UserRole.elderly ? 'elderlyId' : 'volunteerId';
        _listen(_db.collection('requests').where(field, isEqualTo: me), (snap) {
          _applySnapshot(_requestsSync, snap);
          _hangUpIfEnded();
        });
        if (role == UserRole.volunteer) {
          _listen(
            _db
                .collection('supportRequests')
                .where('requestedById', isEqualTo: me),
            (snap) => _applySnapshot(_supportsSync, snap),
          );
        }
      }
    }
  }

  void _listen(
    Query<Map<String, dynamic>> query,
    void Function(QuerySnapshot<Map<String, dynamic>>) onData,
  ) {
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
    _checkOwnAccess();
    notifyListeners();
  }

  /// RF9: si la cuenta con la sesión abierta quedó suspendida o bloqueada, se cierra la sesión
  /// y se deja un aviso. Antes solo se revisaba al iniciar sesión.
  void _checkOwnAccess() {
    final me = currentUser;
    if (me == null || _closingForAccess) return;
    if (me.status != AccountStatus.suspended &&
        me.status != AccountStatus.blocked)
      return;
    _closingForAccess = true;
    accessNotice = me.status == AccountStatus.blocked
        ? 'Coordinación bloqueó tu cuenta. Comunícate con coordinación para más información.'
        : 'Coordinación suspendió tu cuenta mientras revisa un reporte. Comunícate con coordinación para más información.';
    // Se sale fuera del listener de Firestore, en el siguiente ciclo.
    Future<void>(() async {
      try {
        await logout();
      } finally {
        _closingForAccess = false;
      }
    });
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
