import 'package:vita_app/domain/models/vita_models.dart';

/// Paso que sigue en la atención de una alerta de emergencia (RF11 · F8.7, F8.9 y F8.11).
enum EmergencyStep {
  /// Falta avisarle al familiar.
  contactFamily,

  /// Ya se le avisó al familiar; falta anotar si respondió.
  awaitFamily,

  /// El familiar no respondió (o no hay): se prueba con el contacto alternativo.
  contactAlternate,

  /// Ya se le avisó al contacto alternativo; falta anotar si respondió.
  awaitAlternate,

  /// Nadie respondió: se recomienda llamar al 123 o pedir una visita.
  escalate,

  /// Alguien respondió: la alerta se puede cerrar.
  readyToClose,

  /// La alerta ya está cerrada.
  closed,
}

/// Qué debe hacer coordinación ahora con esta alerta.
EmergencyStep nextEmergencyStep(
  EmergencyAlert alert, {
  required bool hasFamilyPhone,
  required bool hasAlternatePhone,
}) {
  if (alert.status == AlertStatus.resolved) return EmergencyStep.closed;
  if (alert.familyOutcome == FamilyOutcome.reached || alert.alternateOutcome == FamilyOutcome.reached) {
    return EmergencyStep.readyToClose;
  }
  if (hasFamilyPhone && alert.familyOutcome == FamilyOutcome.pending) {
    return alert.familyNotifiedAt == null ? EmergencyStep.contactFamily : EmergencyStep.awaitFamily;
  }
  if (hasAlternatePhone && alert.alternateOutcome == FamilyOutcome.pending) {
    return alert.alternateNotifiedAt == null ? EmergencyStep.contactAlternate : EmergencyStep.awaitAlternate;
  }
  return EmergencyStep.escalate;
}

/// Mensaje que se le envía al familiar (F8.7). Dice cuándo fue y qué hacer, sin datos de salud.
String buildFamilyMessage({required String elderlyName, required DateTime when}) {
  final local = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${two(local.day)}/${two(local.month)}';
  final hour = '${two(local.hour)}:${two(local.minute)}';
  return 'VITA: $elderlyName activó una alerta de emergencia el $day a las $hour. '
      'Por favor comuníquese con esta persona lo antes posible. Si hay riesgo vital, llame al 123.';
}

/// Teléfono para WhatsApp: solo dígitos y, si son 10 (celular colombiano), con el 57 delante.
String internationalPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length == 10 ? '57$digits' : digits;
}

/// Primero las alertas abiertas, luego las que están en atención y al final las cerradas;
/// dentro de cada grupo, las más recientes primero.
List<EmergencyAlert> sortAlerts(List<EmergencyAlert> alerts) {
  final sorted = List<EmergencyAlert>.from(alerts);
  sorted.sort((a, b) {
    final byStatus = a.status.index.compareTo(b.status.index);
    return byStatus != 0 ? byStatus : b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}
