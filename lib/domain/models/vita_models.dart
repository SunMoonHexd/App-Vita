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
    this.createdAt,
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
  final DateTime? createdAt;

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
        'lockedUntil': lockedUntil?.toIso8601String(),
        'lastCallAt': lastCallAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'elderlyId': elderlyId,
        'volunteerId': volunteerId,
        'roomName': roomName,
        'joinCode': joinCode,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterId': reporterId,
        'reportedId': reportedId,
        'callId': callId,
        'reason': reason,
        'comment': comment,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
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

class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.callId,
    required this.triggeredById,
    required this.elderlyId,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String callId;
  final String triggeredById;
  final String elderlyId;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'callId': callId,
        'triggeredById': triggeredById,
        'elderlyId': elderlyId,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      id: json['id'] as String,
      callId: json['callId'] as String,
      triggeredById: json['triggeredById'] as String,
      elderlyId: json['elderlyId'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
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
