import 'models/vita_models.dart';

/// Duración estable de una llamada, con [now] como fin si aún no tiene fecha de cierre.
Duration callDurationAt(CallRequest request, DateTime now) {
  final startedAt = request.startedAt;
  if (startedAt == null) return Duration.zero;
  return (request.endedAt ?? now).difference(startedAt);
}

/// Tiempo de llamadas completadas de un voluntario.
Duration volunteerCallTime(
  List<CallRequest> requests,
  String volunteerId,
  DateTime now,
) {
  var total = Duration.zero;
  for (final request in requests) {
    if (request.volunteerId == volunteerId &&
        request.status == CallRequestStatus.completed) {
      total += callDurationAt(request, now);
    }
  }
  return total;
}

int completedCallCount(List<CallRequest> requests) => requests
    .where((request) => request.status == CallRequestStatus.completed)
    .length;

/// Promedio de duración de llamadas completadas que tienen hora de inicio.
Duration averageCompletedCallDuration(
  List<CallRequest> requests,
  DateTime now,
) {
  final completed = requests
      .where(
        (request) =>
            request.status == CallRequestStatus.completed &&
            request.startedAt != null,
      )
      .toList();
  if (completed.isEmpty) return Duration.zero;
  final totalMilliseconds = completed.fold<int>(
    0,
    (total, request) => total + callDurationAt(request, now).inMilliseconds,
  );
  return Duration(milliseconds: totalMilliseconds ~/ completed.length);
}
