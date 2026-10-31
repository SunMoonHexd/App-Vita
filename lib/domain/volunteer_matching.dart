import 'package:vita_app/domain/models/vita_models.dart';

/// Tiempo máximo sin "latido" para considerar que un voluntario sigue conectado.
const Duration kPresenceWindow = Duration(seconds: 90);

/// Hora de Colombia (UTC-5, sin horario de verano) a partir de cualquier instante.
/// Las franjas de los voluntarios se miden con esta hora, sin importar la zona del celular.
DateTime colombiaTime(DateTime instant) => instant.toUtc().subtract(const Duration(hours: 5));

/// ¿Está el voluntario dentro de alguna de sus franjas? Sin franjas guardadas, siempre está en turno.
/// [colombiaNow] debe venir de [colombiaTime]. La hora final de cada franja no se incluye.
bool isInShift(List<AvailabilitySlot> volunteerSlots, DateTime colombiaNow) {
  if (volunteerSlots.isEmpty) return true;
  return volunteerSlots.any(
    (s) => s.weekday == colombiaNow.weekday && colombiaNow.hour >= s.startHour && colombiaNow.hour < s.endHour,
  );
}

/// Voluntarios que pueden recibir una llamada ahora, del que lleva más tiempo sin llamadas al que menos.
///
/// Un voluntario entra si: es voluntario, tiene la cuenta activa, está marcado disponible, está
/// dentro de su turno y no está ocupado en otra solicitud que suena o está conectada. Si
/// [requireRecentPresence] es true, también se exige un latido reciente.
///
/// [requests] debe venir ya normalizada (sin solicitudes vencidas). [ignoreRequestId] evita que la
/// propia solicitud que se está asignando cuente como "ocupado".
List<VitaUser> selectVolunteers({
  required List<VitaUser> users,
  required List<CallRequest> requests,
  required List<AvailabilitySlot> slots,
  required DateTime now,
  String? excludeId,
  String? ignoreRequestId,
  Duration presenceWindow = kPresenceWindow,
  bool requireRecentPresence = true,
}) {
  final colombiaNow = colombiaTime(now);
  final list = users.where((u) {
    if (u.role != UserRole.volunteer) return false;
    if (u.status != AccountStatus.active) return false;
    if (!u.identityVerified) return false;
    if (!u.available) return false;
    if (requireRecentPresence) {
      final seen = u.lastSeenAt;
      if (seen == null || now.difference(seen) > presenceWindow) return false;
    }
    if (excludeId != null && u.id == excludeId) return false;
    if (!isInShift(slots.where((s) => s.volunteerId == u.id).toList(), colombiaNow)) return false;
    final busy = requests.any(
      (r) =>
          r.id != ignoreRequestId &&
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

/// Elige a quién le suena la solicitud [requestId], o null si no hay nadie.
///
/// 1. Se descarta al voluntario al que ya le había sonado ([previousVolunteerId]) para rotar.
/// 2. Si así no queda nadie, se le vuelve a avisar a ese mismo (único voluntario disponible).
/// 3. Si hay un [preferredId] disponible (RF35, "Llamar de nuevo"), pasa al primer lugar.
VitaUser? chooseVolunteer({
  required List<VitaUser> users,
  required List<CallRequest> requests,
  required List<AvailabilitySlot> slots,
  required DateTime now,
  required String requestId,
  String? previousVolunteerId,
  String? preferredId,
  Duration presenceWindow = kPresenceWindow,
  bool requireRecentPresence = true,
}) {
  var candidates = selectVolunteers(
    users: users,
    requests: requests,
    slots: slots,
    now: now,
    excludeId: previousVolunteerId,
    ignoreRequestId: requestId,
    presenceWindow: presenceWindow,
    requireRecentPresence: requireRecentPresence,
  );
  if (candidates.isEmpty) {
    candidates = selectVolunteers(
      users: users,
      requests: requests,
      slots: slots,
      now: now,
      ignoreRequestId: requestId,
      presenceWindow: presenceWindow,
      requireRecentPresence: requireRecentPresence,
    );
  }
  if (preferredId != null) {
    final i = candidates.indexWhere((u) => u.id == preferredId);
    if (i > 0) candidates.insert(0, candidates.removeAt(i));
  }
  return candidates.isEmpty ? null : candidates.first;
}
