import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vita_app/data/services/jitsi_call_service.dart';
import 'package:vita_app/data/services/local_storage_service.dart';
import 'package:vita_app/data/services/secret_hasher.dart';
import 'package:vita_app/domain/models/vita_models.dart';

class VitaRepository extends ChangeNotifier {
  VitaRepository({
    required LocalStorageService storage,
    required JitsiCallService jitsi,
    DateTime Function()? clock,
  })  : _storage = storage,
        _jitsi = jitsi,
        _now = clock ?? DateTime.now;

  final LocalStorageService _storage;
  final JitsiCallService _jitsi;
  final DateTime Function() _now;
  final _uuid = const Uuid();
  final _random = Random();

  static const serviceStartHour = 8;
  static const serviceEndHour = 20;
  static const maxLoginAttempts = 5;
  static const lockMinutes = 15;
  static const ringTimeout = Duration(seconds: 30);
  static const maxReassigns = 3;

  /// El prototipo permite llamadas fuera de horario para demos académicas.
  static const demoBypassSchedule = true;

  final List<VitaUser> _users = [];
  final List<CallRequest> _requests = [];
  final List<UserReport> _reports = [];
  final List<EmergencyAlert> _alerts = [];
  final List<CallSurvey> _surveys = [];
  final List<AvailabilitySlot> _slots = [];
  String? _sessionUserId;
  String? _recoveryCode;
  String? _recoveryUserId;

  JitsiCallService get jitsi => _jitsi;
  VitaUser? get currentUser =>
      _users.where((u) => u.id == _sessionUserId && u.status != AccountStatus.deleted).firstOrNull;
  List<VitaUser> get users => List.unmodifiable(_users);
  List<CallRequest> get requests => List.unmodifiable(_requests);
  List<UserReport> get reports => List.unmodifiable(_reports);
  List<EmergencyAlert> get alerts => List.unmodifiable(_alerts);
  List<AvailabilitySlot> slotsFor(String volunteerId) =>
      _slots.where((s) => s.volunteerId == volunteerId).toList();

  CallRequest? get activeRequest {
    final user = currentUser;
    if (user == null) return null;
    return _requests.cast<CallRequest?>().firstWhere(
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

  String get serviceHoursLabel =>
      'Horario de atención: $serviceStartHour:00 a $serviceEndHour:00';

  Future<void> bootstrap() async {
    final data = _storage.load();
    if (data.isEmpty) {
      _seedDemo();
      await _persist();
      notifyListeners();
      return;
    }
    _users
      ..clear()
      ..addAll(((data['users'] as List?) ?? []).map((e) => VitaUser.fromJson(Map<String, dynamic>.from(e as Map))));
    _requests
      ..clear()
      ..addAll(((data['requests'] as List?) ?? []).map((e) => CallRequest.fromJson(Map<String, dynamic>.from(e as Map))));
    _reports
      ..clear()
      ..addAll(((data['reports'] as List?) ?? []).map((e) => UserReport.fromJson(Map<String, dynamic>.from(e as Map))));
    _alerts
      ..clear()
      ..addAll(((data['alerts'] as List?) ?? []).map((e) => EmergencyAlert.fromJson(Map<String, dynamic>.from(e as Map))));
    _surveys
      ..clear()
      ..addAll(((data['surveys'] as List?) ?? []).map((e) => CallSurvey.fromJson(Map<String, dynamic>.from(e as Map))));
    _slots
      ..clear()
      ..addAll(((data['slots'] as List?) ?? []).map((e) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(e as Map))));
    _sessionUserId = data['sessionUserId'] as String?;
    notifyListeners();
  }

  void _seedDemo() {
    final now = _now();
    _users.addAll([
      VitaUser(
        id: 'elderly-demo',
        role: UserRole.elderly,
        displayName: 'Pedro Gómez',
        status: AccountStatus.active,
        phone: '3001112233',
        secretHash: hashSecret('1234'),
        birthDate: DateTime(1955, 4, 12),
        familyName: 'Ana Gómez',
        familyPhone: '3004445566',
        alternateName: 'Luis Gómez',
        alternatePhone: '3007778899',
        consentAccepted: true,
        onboardingDone: true,
        createdAt: now,
      ),
      VitaUser(
        id: 'volunteer-demo',
        role: UserRole.volunteer,
        displayName: 'María Volunteer',
        status: AccountStatus.active,
        email: 'voluntario@vita.app',
        documentId: '1234567890',
        secretHash: hashSecret('Voluntario1'),
        birthDate: DateTime(1998, 8, 20),
        consentAccepted: true,
        conductAccepted: true,
        inductionDone: true,
        available: true,
        onboardingDone: true,
        createdAt: now,
      ),
      VitaUser(
        id: 'coord-demo',
        role: UserRole.coordinator,
        displayName: 'Coordinación VITA',
        status: AccountStatus.active,
        email: 'coordinacion@vita.app',
        secretHash: hashSecret('CoordVita1'),
        consentAccepted: true,
        createdAt: now,
      ),
    ]);
    _slots.add(
      AvailabilitySlot(
        id: 'slot-demo',
        volunteerId: 'volunteer-demo',
        weekday: now.weekday,
        startHour: 0,
        endHour: 23,
      ),
    );
  }

  Future<void> _persist() async {
    await _storage.save({
      'users': _users.map((e) => e.toJson()).toList(),
      'requests': _requests.map((e) => e.toJson()).toList(),
      'reports': _reports.map((e) => e.toJson()).toList(),
      'alerts': _alerts.map((e) => e.toJson()).toList(),
      'surveys': _surveys.map((e) => e.toJson()).toList(),
      'slots': _slots.map((e) => e.toJson()).toList(),
      'sessionUserId': _sessionUserId,
    });
  }

  Future<void> _commit() async {
    await _persist();
    notifyListeners();
  }

  int _indexOf(String id) => _users.indexWhere((u) => u.id == id);

  void _replaceUser(VitaUser user) {
    final i = _indexOf(user.id);
    if (i >= 0) _users[i] = user;
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
    final lock = user.lockedUntil;
    if (lock != null && lock.isAfter(_now())) {
      return const AuthResult.error('Cuenta bloqueada por 15 minutos. Intenta más tarde o recupera el acceso.');
    }
    return AuthResult.ok(user);
  }

  AuthResult _registerFailedAttempt(VitaUser user) {
    var attempts = user.failedAttempts + 1;
    DateTime? lock;
    var status = user.status;
    if (attempts >= maxLoginAttempts) {
      lock = _now().add(const Duration(minutes: lockMinutes));
      attempts = 0;
    }
    _replaceUser(user.copyWith(failedAttempts: attempts, lockedUntil: lock, status: status));
    _persist();
    notifyListeners();
    if (lock != null) {
      return const AuthResult.error('Demasiados intentos. Cuenta bloqueada 15 minutos.');
    }
    return AuthResult.error('Datos incorrectos. Intento $attempts de $maxLoginAttempts.');
  }

  Future<AuthResult> loginElderly({required String phone, required String pin}) async {
    final user = _users.cast<VitaUser?>().firstWhere(
          (u) => u != null && u.role == UserRole.elderly && u.phone == phone && u.status != AccountStatus.deleted,
          orElse: () => null,
        );
    if (user == null) return const AuthResult.error('No encontramos ese teléfono.');
    final gate = _finishLogin(user);
    if (!gate.isOk) return gate;
    if (user.secretHash != hashSecret(pin)) return _registerFailedAttempt(user);
    _replaceUser(user.copyWith(failedAttempts: 0, clearLock: true));
    _sessionUserId = user.id;
    await _commit();
    return AuthResult.ok(_users[_indexOf(user.id)]);
  }

  Future<AuthResult> loginVolunteer({required String email, required String password}) async {
    return _loginByEmail(email: email, password: password, role: UserRole.volunteer);
  }

  Future<AuthResult> loginCoordinator({required String email, required String password}) async {
    return _loginByEmail(email: email, password: password, role: UserRole.coordinator);
  }

  Future<AuthResult> _loginByEmail({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final user = _users.cast<VitaUser?>().firstWhere(
          (u) => u != null && u.role == role && u.email?.toLowerCase() == email.toLowerCase() && u.status != AccountStatus.deleted,
          orElse: () => null,
        );
    if (user == null) return const AuthResult.error('No encontramos ese correo.');
    final gate = _finishLogin(user);
    if (!gate.isOk) return gate;
    if (user.secretHash != hashSecret(password)) return _registerFailedAttempt(user);
    _replaceUser(user.copyWith(failedAttempts: 0, clearLock: true));
    _sessionUserId = user.id;
    await _commit();
    return AuthResult.ok(_users[_indexOf(user.id)]);
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
    final age = _ageFrom(birthDate);
    if (age < 60) return const AuthResult.error('El servicio es para personas de 60 años o más.');
    if (_users.any((u) => u.phone == phone && u.status != AccountStatus.deleted)) {
      return const AuthResult.error('Ese teléfono ya está registrado.');
    }
    final user = VitaUser(
      id: _uuid.v4(),
      role: UserRole.elderly,
      displayName: name.trim(),
      status: AccountStatus.active,
      phone: phone.trim(),
      secretHash: hashSecret(pin),
      birthDate: birthDate,
      familyName: familyName.trim(),
      familyPhone: familyPhone.trim(),
      alternateName: alternateName.trim(),
      alternatePhone: alternatePhone.trim(),
      consentAccepted: true,
      createdAt: _now(),
    );
    _users.add(user);
    _sessionUserId = user.id;
    await _commit();
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
    if (_users.any((u) => u.email?.toLowerCase() == email.toLowerCase() && u.status != AccountStatus.deleted)) {
      return const AuthResult.error('Ese correo ya está registrado.');
    }
    if (_users.any((u) => u.documentId == documentId && u.status != AccountStatus.deleted)) {
      return const AuthResult.error('Ese documento ya está registrado.');
    }
    final user = VitaUser(
      id: _uuid.v4(),
      role: UserRole.volunteer,
      displayName: name.trim(),
      status: AccountStatus.pending,
      phone: phone.trim(),
      email: email.trim(),
      documentId: documentId.trim(),
      secretHash: hashSecret(password),
      birthDate: birthDate,
      consentAccepted: true,
      conductAccepted: true,
      inductionDone: true,
      createdAt: _now(),
    );
    _users.add(user);
    await _commit();
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
    _sessionUserId = null;
    await _commit();
  }

  Future<String> startPinRecovery(String phone) async {
    final user = _users.cast<VitaUser?>().firstWhere(
          (u) => u != null && u.role == UserRole.elderly && u.phone == phone && u.status != AccountStatus.deleted,
          orElse: () => null,
        );
    if (user == null) {
      throw Exception('No encontramos ese teléfono.');
    }
    _recoveryUserId = user.id;
    _recoveryCode = (_random.nextInt(900000) + 100000).toString();
    return _recoveryCode!;
  }

  Future<void> completePinRecovery({required String code, required String newPin}) async {
    if (code != _recoveryCode || _recoveryUserId == null) {
      throw Exception('El código no es válido.');
    }
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      throw Exception('El PIN debe tener 4 dígitos.');
    }
    final user = _users.firstWhere((u) => u.id == _recoveryUserId);
    _replaceUser(user.copyWith(secretHash: hashSecret(newPin), failedAttempts: 0, clearLock: true));
    _recoveryCode = null;
    _recoveryUserId = null;
    await _commit();
  }

  Future<String> startPasswordRecovery(String email) async {
    final user = _users.cast<VitaUser?>().firstWhere(
          (u) => u != null && u.role == UserRole.volunteer && u.email?.toLowerCase() == email.toLowerCase(),
          orElse: () => null,
        );
    if (user == null) throw Exception('No encontramos ese correo.');
    _recoveryUserId = user.id;
    _recoveryCode = (_random.nextInt(900000) + 100000).toString();
    return _recoveryCode!;
  }

  Future<void> completePasswordRecovery({required String code, required String password}) async {
    if (code != _recoveryCode || _recoveryUserId == null) {
      throw Exception('El código no es válido.');
    }
    final user = _users.firstWhere((u) => u.id == _recoveryUserId);
    _replaceUser(user.copyWith(secretHash: hashSecret(password), failedAttempts: 0, clearLock: true));
    _recoveryCode = null;
    _recoveryUserId = null;
    await _commit();
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

  Future<void> requestAccountDeletion() async {
    final user = currentUser;
    if (user == null) return;
    _replaceUser(user.copyWith(status: AccountStatus.deleted, available: false));
    _sessionUserId = null;
    await _commit();
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

  Future<CallRequest> startCallRequest() async {
    final user = currentUser;
    if (user == null || user.role != UserRole.elderly) {
      throw Exception('Debes ingresar como adulto mayor.');
    }
    if (!isWithinServiceHours) {
      throw Exception('Fuera de horario. $serviceHoursLabel');
    }
    final existing = activeRequest;
    if (existing != null) return existing;

    final request = CallRequest(
      id: _uuid.v4(),
      elderlyId: user.id,
      roomName: 'VITA_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      joinCode: (_random.nextInt(9000) + 1000).toString(),
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
    var request = _requests[index];
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
    var request = _requests[index];
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
    var request = _requests[index];
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

  Future<CallRequest> joinByCode(String code) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.volunteer) {
      throw Exception('Ingresa como voluntario para unirte.');
    }
    final index = _requests.indexWhere(
      (r) =>
          r.joinCode == code.trim() &&
          (r.status == CallRequestStatus.searching || r.status == CallRequestStatus.ringing),
    );
    if (index < 0) throw Exception('No hay una solicitud con ese código.');
    _requests[index] = _requests[index].copyWith(
      volunteerId: user.id,
      status: CallRequestStatus.connected,
      startedAt: _now(),
    );
    _replaceUser(user.copyWith(available: false));
    await _commit();
    return _requests[index];
  }

  /// En un solo dispositivo, el voluntario demo acepta para poder entrar a Jitsi.
  Future<CallRequest> autoAcceptDemo(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Solicitud no encontrada.');
    final request = _requests[index];
    if (request.volunteerId == 'volunteer-demo' && request.status == CallRequestStatus.ringing) {
      _requests[index] = request.copyWith(status: CallRequestStatus.connected, startedAt: _now());
      await _commit();
    }
    return _requests[index];
  }

  Future<void> finishCall(String requestId, {CallRequestStatus status = CallRequestStatus.completed}) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    final request = _requests[index];
    _requests[index] = request.copyWith(status: status, endedAt: _now());
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
      onTerminated: () {
        finishCall(request.id);
      },
    );
  }

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
        available: decision == ReportStatus.suspended || decision == ReportStatus.blocked ? false : _users[reportedIndex].available,
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
    _users[i] = _users[i].copyWith(status: status, available: status == AccountStatus.active ? _users[i].available : false);
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
}
