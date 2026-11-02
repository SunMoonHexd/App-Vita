import 'models/vita_models.dart';

const Duration kOpenCallMaxAge = Duration(minutes: 10);
const Duration kConnectedCallMaxAge = Duration(hours: 4);

/// Convierte solicitudes viejas en estados finales para que no queden colgadas.
CallRequest normalizeCallRequest(CallRequest request, DateTime now) {
  if ((request.status == CallRequestStatus.searching ||
          request.status == CallRequestStatus.ringing) &&
      now.difference(request.createdAt) > kOpenCallMaxAge) {
    return request.copyWith(status: CallRequestStatus.expired);
  }
  if (request.status == CallRequestStatus.connected &&
      now.difference(request.startedAt ?? request.createdAt) >
          kConnectedCallMaxAge) {
    return request.copyWith(status: CallRequestStatus.interrupted);
  }
  return request;
}

/// Solicitud activa del usuario, si es participante y sigue en curso.
CallRequest? activeCallFor(List<CallRequest> requests, String? userId) {
  if (userId == null) return null;
  for (final request in requests) {
    final isParticipant =
        request.elderlyId == userId || request.volunteerId == userId;
    final isActive =
        request.status == CallRequestStatus.searching ||
        request.status == CallRequestStatus.ringing ||
        request.status == CallRequestStatus.connected;
    if (isParticipant && isActive) return request;
  }
  return null;
}
