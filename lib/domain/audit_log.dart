import 'package:vita_app/domain/models/vita_models.dart';

/// Una acción de seguridad hecha por coordinación (RF44 · F18.7, historia 18.7.3).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.createdAt,
    this.targetId,
    this.detail,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String? targetId;
  final String? detail;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'actorId': actorId,
        'actorName': actorName,
        'action': action,
        'targetId': targetId,
        'detail': detail,
        'createdAt': vitaIso(createdAt),
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as String? ?? '',
        actorId: json['actorId'] as String? ?? '',
        actorName: json['actorName'] as String? ?? 'Coordinación',
        action: json['action'] as String? ?? '',
        targetId: json['targetId'] as String?,
        detail: json['detail'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

const Map<String, String> kAuditLabels = {
  'volunteer_approved': 'Aprobó a un voluntario',
  'volunteer_rejected': 'Rechazó a un voluntario',
  'volunteer_profile_approved': 'Aprobó la presentación de un voluntario',
  'volunteer_profile_rejected': 'Rechazó la presentación de un voluntario',
  'volunteer_identity_verified': 'Verificó la identidad de un voluntario',
  'account_suspended': 'Suspendió una cuenta',
  'account_blocked': 'Bloqueó una cuenta',
  'account_reactivated': 'Reactivó una cuenta',
  'report_resolved': 'Resolvió un reporte',
  'pin_reset': 'Restableció el PIN de un adulto mayor',
  'alert_resolved': 'Cerró una alerta de emergencia',
  'retention_changed': 'Cambió el tiempo de retención de datos',
  'data_anonymized': 'Anonimizó datos vencidos',
};

/// Texto legible de una acción; si no se conoce, se muestra tal cual.
String auditLabel(String action) => kAuditLabels[action] ?? action;
