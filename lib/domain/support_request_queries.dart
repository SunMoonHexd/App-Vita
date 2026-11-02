import 'models/vita_models.dart';

const Duration kSupportRequestMaxAge = Duration(hours: 4);

bool _isRecent(SupportRequest request, DateTime now, Duration maxAge) =>
    now.difference(request.createdAt) <= maxAge;

/// Solicitud abierta o aceptada de una llamada que todavía puede atenderse.
SupportRequest? activeSupportFor(
  List<SupportRequest> requests,
  String callId,
  DateTime now, {
  Duration maxAge = kSupportRequestMaxAge,
}) {
  for (final request in requests) {
    if (request.callId == callId &&
        _isRecent(request, now, maxAge) &&
        (request.status == SupportStatus.open ||
            request.status == SupportStatus.accepted)) {
      return request;
    }
  }
  return null;
}

/// Solicitudes nuevas para el panel del psicólogo, ordenadas de la más antigua.
List<SupportRequest> openSupportRequests(
  List<SupportRequest> requests,
  DateTime now, {
  Duration maxAge = kSupportRequestMaxAge,
}) =>
    requests
        .where(
          (request) =>
              request.status == SupportStatus.open &&
              _isRecent(request, now, maxAge),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

/// Solicitudes aceptadas por un psicólogo que aún están dentro de su vigencia.
List<SupportRequest> supportInProgressFor(
  List<SupportRequest> requests,
  String? psychologistId,
  DateTime now, {
  Duration maxAge = kSupportRequestMaxAge,
}) {
  if (psychologistId == null) return const [];
  return requests
      .where(
        (request) =>
            request.status == SupportStatus.accepted &&
            request.psychologistId == psychologistId &&
            _isRecent(request, now, maxAge),
      )
      .toList();
}
