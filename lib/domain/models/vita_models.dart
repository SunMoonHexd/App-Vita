enum UserRole { elderly, volunteer, coordinator }

enum AccountStatus { pending, active, suspended, blocked, deleted }

enum CallRequestStatus { searching, ringing, connected, cancelled, expired, completed, interrupted }

enum ReportStatus { pending, archived, warned, suspended, blocked }

class VitaUser {
  const VitaUser({
    required this.id,
    required this.role,
    required this.displayName,
    required this.status,
    this.phone,
    this.email,
    this.documentId,
    this.secretHash,
    this.birthDate,
    this.familyName,
    this.familyPhone,
    this.alternateName,
    this.alternatePhone,
    this.consentAccepted = false,
    this.conductAccepted = false,
    this.inductionDone = false,
    this.available = false,
    this.onboardingDone = false,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.lastCallAt,
    this.lastSeenAt,
    this.createdAt,
    this.emailVerified = false,
    this.photoBase64,
  });

  final String id;
  final UserRole role;
  final String displayName;
  final AccountStatus status;
  final String? phone;
  final String? email;
  final String? documentId;
  final String? secretHash;
  final DateTime? birthDate;
  final String? familyName;
  final String? familyPhone;
  final String? alternateName;
  final String? alternatePhone;
  final bool consentAccepted;
  final bool conductAccepted;
  final bool inductionDone;
  final bool available;
  final bool onboardingDone;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime? lastCallAt;
  /// Último "latido" del voluntario: sirve para saber si de verdad tiene la app abierta.
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  /// RF3: el voluntario confirmó que el correo es suyo (lo certifica Firebase Auth).
  final bool emailVerified;

  /// Foto de perfil (JPEG reducido, en base64). Es opcional y vive en el documento privado:
  /// solo la ve la propia persona y coordinación.
  final String? photoBase64;

  VitaUser copyWith({
    AccountStatus? status,
    String? displayName,
    String? phone,
    String? familyName,
    String? familyPhone,
    String? alternateName,
    String? alternatePhone,
    String? secretHash,
    bool? available,
    bool? onboardingDone,
    bool? consentAccepted,
    bool? conductAccepted,
    bool? inductionDone,
    int? failedAttempts,
    DateTime? lockedUntil,
    DateTime? lastCallAt,
    DateTime? lastSeenAt,
    bool? emailVerified,
    String? photoBase64,
    bool clearPhoto = false,
    bool clearLock = false,
  }) {
    return VitaUser(
      id: id,
      role: role,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email,
      documentId: documentId,
      secretHash: secretHash ?? this.secretHash,
      birthDate: birthDate,
      familyName: familyName ?? this.familyName,
      familyPhone: familyPhone ?? this.familyPhone,
      alternateName: alternateName ?? this.alternateName,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      conductAccepted: conductAccepted ?? this.conductAccepted,
      inductionDone: inductionDone ?? this.inductionDone,
      available: available ?? this.available,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
      lastCallAt: lastCallAt ?? this.lastCallAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      emailVerified: emailVerified ?? this.emailVerified,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'displayName': displayName,
        'status': status.name,
        'phone': phone,
        'email': email,
        'documentId': documentId,
        'secretHash': secretHash,
        'birthDate': birthDate?.toIso8601String(),
        'familyName': familyName,
        'familyPhone': familyPhone,
        'alternateName': alternateName,
        'alternatePhone': alternatePhone,
        'consentAccepted': consentAccepted,
        'conductAccepted': conductAccepted,
        'inductionDone': inductionDone,
        'available': available,
        'onboardingDone': onboardingDone,
        'failedAttempts': failedAttempts,
        'lockedUntil': vitaIsoN(lockedUntil),
        'lastCallAt': vitaIsoN(lastCallAt),
        'lastSeenAt': vitaIsoN(lastSeenAt),
        'emailVerified': emailVerified,
        'photoBase64': photoBase64,
        'createdAt': vitaIsoN(createdAt),
      };

  factory VitaUser.fromJson(Map<String, dynamic> json) {
    return VitaUser(
      id: json['id'] as String,
      role: UserRole.values.byName(json['role'] as String),
      displayName: json['displayName'] as String,
      status: AccountStatus.values.byName(json['status'] as String),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      documentId: json['documentId'] as String?,
      secretHash: json['secretHash'] as String?,
      birthDate: json['birthDate'] == null ? null : DateTime.parse(json['birthDate'] as String),
      familyName: json['familyName'] as String?,
      familyPhone: json['familyPhone'] as String?,
      alternateName: json['alternateName'] as String?,
      alternatePhone: json['alternatePhone'] as String?,
      consentAccepted: json['consentAccepted'] as bool? ?? false,
      conductAccepted: json['conductAccepted'] as bool? ?? false,
      inductionDone: json['inductionDone'] as bool? ?? false,
      available: json['available'] as bool? ?? false,
      onboardingDone: json['onboardingDone'] as bool? ?? false,
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      lockedUntil: json['lockedUntil'] == null ? null : DateTime.parse(json['lockedUntil'] as String),
      lastCallAt: json['lastCallAt'] == null ? null : DateTime.parse(json['lastCallAt'] as String),
      lastSeenAt: json['lastSeenAt'] == null ? null : DateTime.parse(json['lastSeenAt'] as String),
      emailVerified: json['emailVerified'] as bool? ?? false,
      photoBase64: json['photoBase64'] as String?,
      createdAt: json['createdAt'] == null ? null : DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CallRequest {
  const CallRequest({
    required this.id,
    required this.elderlyId,
    required this.roomName,
    required this.joinCode,
    required this.status,
    required this.createdAt,
    this.volunteerId,
    this.attempts = 1,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String elderlyId;
  final String? volunteerId;
  final String roomName;
  final String joinCode;
  final CallRequestStatus status;
  final DateTime createdAt;
  final int attempts;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Duration get duration {
    final start = startedAt;
    final end = endedAt ?? DateTime.now();
    if (start == null) return Duration.zero;
    return end.difference(start);
  }

  CallRequest copyWith({
    String? volunteerId,
    CallRequestStatus? status,
    int? attempts,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return CallRequest(
      id: id,
      elderlyId: elderlyId,
      volunteerId: volunteerId ?? this.volunteerId,
      roomName: roomName,
      joinCode: joinCode,
      status: status ?? this.status,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  /// La misma llamada sin datos personales (F18.7).
  CallRequest anonymized() => CallRequest(
      id: id,
      elderlyId: kAnonymized,
      roomName: 'anonimizada',
      joinCode: '000000',
      status: status,
      createdAt: createdAt,
      volunteerId: volunteerId == null ? null : kAnonymized,
      attempts: attempts,
      startedAt: startedAt,
      endedAt: endedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'elderlyId': elderlyId,
        'volunteerId': volunteerId,
        'roomName': roomName,
        'joinCode': joinCode,
        'status': status.name,
        'createdAt': vitaIso(createdAt),
        'attempts': attempts,
        'startedAt': vitaIsoN(startedAt),
        'endedAt': vitaIsoN(endedAt),
      };

  factory CallRequest.fromJson(Map<String, dynamic> json) {
    return CallRequest(
      id: json['id'] as String,
      elderlyId: json['elderlyId'] as String,
      volunteerId: json['volunteerId'] as String?,
      roomName: json['roomName'] as String,
      joinCode: json['joinCode'] as String,
      status: CallRequestStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: json['attempts'] as int? ?? 1,
      startedAt: json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null ? null : DateTime.parse(json['endedAt'] as String),
    );
  }
}

class UserReport {
  const UserReport({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.callId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String reporterId;
  final String reportedId;
  final String callId;
  final String reason;
  final String? comment;
  final ReportStatus status;
  final DateTime createdAt;

  UserReport copyWith({ReportStatus? status}) {
    return UserReport(
      id: id,
      reporterId: reporterId,
      reportedId: reportedId,
      callId: callId,
      reason: reason,
      comment: comment,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  /// La misma reporte sin datos personales (F18.7).
  UserReport anonymized() => UserReport(
      id: id,
      reporterId: kAnonymized,
      reportedId: kAnonymized,
      callId: callId,
      reason: reason,
      status: status,
      createdAt: createdAt,
      comment: null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterId': reporterId,
        'reportedId': reportedId,
        'callId': callId,
        'reason': reason,
        'comment': comment,
        'status': status.name,
        'createdAt': vitaIso(createdAt),
      };

  factory UserReport.fromJson(Map<String, dynamic> json) {
    return UserReport(
      id: json['id'] as String,
      reporterId: json['reporterId'] as String,
      reportedId: json['reportedId'] as String,
      callId: json['callId'] as String,
      reason: json['reason'] as String,
      comment: json['comment'] as String?,
      status: ReportStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Estado del seguimiento de una alerta de emergencia (F8.11).
enum AlertStatus { open, inProgress, resolved }

/// Resultado de intentar comunicarse con el familiar o con el contacto alternativo (F8.7 y F8.9).
enum FamilyOutcome { pending, reached, noAnswer }

/// Valor que reemplaza a los datos personales cuando se anonimizan registros vencidos (F18.7).
const String kAnonymized = 'anonimizado';

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

DateTime? _dateOrNull(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

/// Alerta de emergencia y su seguimiento por parte de coordinación (RF11 · F8.7, F8.9 y F8.11).
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.callId,
    required this.triggeredById,
    required this.elderlyId,
    required this.createdAt,
    this.note,
    this.status = AlertStatus.open,
    this.takenById,
    this.takenAt,
    this.familyNotifiedAt,
    this.familyChannel,
    this.familyOutcome = FamilyOutcome.pending,
    this.alternateNotifiedAt,
    this.alternateOutcome = FamilyOutcome.pending,
    this.resolvedAt,
    this.resolvedById,
    this.resolutionNote,
  });

  final String id;
  final String callId;
  final String triggeredById;
  final String elderlyId;
  final DateTime createdAt;
  final String? note;
  final AlertStatus status;
  final String? takenById;
  final DateTime? takenAt;
  final DateTime? familyNotifiedAt;
  final String? familyChannel;
  final FamilyOutcome familyOutcome;
  final DateTime? alternateNotifiedAt;
  final FamilyOutcome alternateOutcome;
  final DateTime? resolvedAt;
  final String? resolvedById;
  final String? resolutionNote;

  bool get isAnonymized => elderlyId == kAnonymized;

  EmergencyAlert copyWith({
    AlertStatus? status,
    String? takenById,
    DateTime? takenAt,
    DateTime? familyNotifiedAt,
    String? familyChannel,
    FamilyOutcome? familyOutcome,
    DateTime? alternateNotifiedAt,
    FamilyOutcome? alternateOutcome,
    DateTime? resolvedAt,
    String? resolvedById,
    String? resolutionNote,
  }) {
    return EmergencyAlert(
      id: id,
      callId: callId,
      triggeredById: triggeredById,
      elderlyId: elderlyId,
      createdAt: createdAt,
      note: note,
      status: status ?? this.status,
      takenById: takenById ?? this.takenById,
      takenAt: takenAt ?? this.takenAt,
      familyNotifiedAt: familyNotifiedAt ?? this.familyNotifiedAt,
      familyChannel: familyChannel ?? this.familyChannel,
      familyOutcome: familyOutcome ?? this.familyOutcome,
      alternateNotifiedAt: alternateNotifiedAt ?? this.alternateNotifiedAt,
      alternateOutcome: alternateOutcome ?? this.alternateOutcome,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedById: resolvedById ?? this.resolvedById,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }

  /// La misma alerta sin datos personales (F18.7): conserva fechas, estado y resultado, para estadísticas.
  EmergencyAlert anonymized() {
    return EmergencyAlert(
      id: id,
      callId: callId,
      triggeredById: kAnonymized,
      elderlyId: kAnonymized,
      createdAt: createdAt,
      status: status,
      takenById: takenById == null ? null : kAnonymized,
      takenAt: takenAt,
      familyNotifiedAt: familyNotifiedAt,
      familyChannel: familyChannel,
      familyOutcome: familyOutcome,
      alternateNotifiedAt: alternateNotifiedAt,
      alternateOutcome: alternateOutcome,
      resolvedAt: resolvedAt,
      resolvedById: resolvedById == null ? null : kAnonymized,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'callId': callId,
        'triggeredById': triggeredById,
        'elderlyId': elderlyId,
        'note': note,
        'createdAt': vitaIso(createdAt),
        'status': status.name,
        'takenById': takenById,
        'takenAt': vitaIsoN(takenAt),
        'familyNotifiedAt': vitaIsoN(familyNotifiedAt),
        'familyChannel': familyChannel,
        'familyOutcome': familyOutcome.name,
        'alternateNotifiedAt': vitaIsoN(alternateNotifiedAt),
        'alternateOutcome': alternateOutcome.name,
        'resolvedAt': vitaIsoN(resolvedAt),
        'resolvedById': resolvedById,
        'resolutionNote': resolutionNote,
      };

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) => EmergencyAlert(
        id: json['id'] as String,
        callId: json['callId'] as String,
        triggeredById: json['triggeredById'] as String,
        elderlyId: json['elderlyId'] as String,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: _enumByName(AlertStatus.values, json['status'], AlertStatus.open),
        takenById: json['takenById'] as String?,
        takenAt: _dateOrNull(json['takenAt']),
        familyNotifiedAt: _dateOrNull(json['familyNotifiedAt']),
        familyChannel: json['familyChannel'] as String?,
        familyOutcome: _enumByName(FamilyOutcome.values, json['familyOutcome'], FamilyOutcome.pending),
        alternateNotifiedAt: _dateOrNull(json['alternateNotifiedAt']),
        alternateOutcome: _enumByName(FamilyOutcome.values, json['alternateOutcome'], FamilyOutcome.pending),
        resolvedAt: _dateOrNull(json['resolvedAt']),
        resolvedById: json['resolvedById'] as String?,
        resolutionNote: json['resolutionNote'] as String?,
      );
}

class CallSurvey {
  const CallSurvey({
    required this.callId,
    required this.userId,
    required this.experience,
    this.feltAccompanied,
  });

  final String callId;
  final String userId;
  final int experience;
  final int? feltAccompanied;

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'userId': userId,
        'experience': experience,
        'feltAccompanied': feltAccompanied,
      };

  factory CallSurvey.fromJson(Map<String, dynamic> json) {
    return CallSurvey(
      callId: json['callId'] as String,
      userId: json['userId'] as String,
      experience: json['experience'] as int,
      feltAccompanied: json['feltAccompanied'] as int?,
    );
  }
}

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.id,
    required this.volunteerId,
    required this.weekday,
    required this.startHour,
    required this.endHour,
  });

  final String id;
  final String volunteerId;
  final int weekday;
  final int startHour;
  final int endHour;

  Map<String, dynamic> toJson() => {
        'id': id,
        'volunteerId': volunteerId,
        'weekday': weekday,
        'startHour': startHour,
        'endHour': endHour,
      };

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'] as String,
      volunteerId: json['volunteerId'] as String,
      weekday: json['weekday'] as int,
      startHour: json['startHour'] as int,
      endHour: json['endHour'] as int,
    );
  }
}

class AuthResult {
  const AuthResult.ok(this.user) : error = null;
  const AuthResult.error(this.error) : user = null;

  final VitaUser? user;
  final String? error;
  bool get isOk => user != null;
}

/// Fecha en formato ISO-8601 **en UTC** (termina en "Z"). Sin esto, `toIso8601String()` de una
/// hora local no incluye la zona horaria y otro celular (u otro emulador) con zona distinta la
/// interpreta corrida varias horas.
String vitaIso(DateTime d) => d.toUtc().toIso8601String();

/// Igual que [vitaIso], pero acepta fechas nulas.
String? vitaIsoN(DateTime? d) => d == null ? null : vitaIso(d);
