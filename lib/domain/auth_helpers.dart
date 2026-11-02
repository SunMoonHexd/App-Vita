String phoneDigits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

String elderlyAuthEmail(String phone) =>
    '${phoneDigits(phone)}@telefono.vita.invalid';

String elderlyAuthPassword(String pin, String phone) =>
    'vita-$pin-${phoneDigits(phone)}';

String elderlyLockKey(String phone) => 'elderly:${phoneDigits(phone)}';

String emailLockKey(String role, String email) =>
    '$role:${email.trim().toLowerCase()}';

String authErrorMessage(String code, {required String wrong}) {
  switch (code) {
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
      return 'No se pudo completar la acción ($code).';
  }
}

String? activeLockMessage({
  required String key,
  required DateTime lockedUntil,
  required DateTime now,
}) {
  if (!now.isBefore(lockedUntil)) return null;
  final minutes = lockedUntil.difference(now).inMinutes + 1;
  final help = key.startsWith('elderly:')
      ? ' También puedes restablecer el PIN con ayuda de tu familiar.'
      : ' También puedes restablecer tu contraseña desde el correo.';
  return 'Cuenta bloqueada por intentos fallidos. Espera $minutes minuto(s).$help';
}

class FailedAttemptDecision {
  const FailedAttemptDecision({
    required this.failedAttempts,
    required this.lockedUntil,
    required this.message,
  });

  final int failedAttempts;
  final DateTime? lockedUntil;
  final String message;
}

FailedAttemptDecision failedAttemptDecision({
  required String key,
  required int previousAttempts,
  required DateTime? previousLockedUntil,
  required DateTime now,
  required String wrong,
  int maxAttempts = 5,
  Duration lockDuration = const Duration(minutes: 15),
}) {
  final attempts =
      previousLockedUntil != null && !now.isBefore(previousLockedUntil)
      ? 0
      : previousAttempts;
  final next = attempts + 1;
  if (next >= maxAttempts) {
    final until = now.add(lockDuration);
    final help = key.startsWith('elderly:')
        ? ' Recupera el PIN con tu familiar o espera 15 minutos.'
        : ' Espera 15 minutos o restablece tu contraseña.';
    return FailedAttemptDecision(
      failedAttempts: next,
      lockedUntil: until,
      message: 'Cuenta bloqueada por 15 minutos tras 5 intentos fallidos.$help',
    );
  }
  return FailedAttemptDecision(
    failedAttempts: next,
    lockedUntil: null,
    message: '$wrong Te quedan ${maxAttempts - next} intento(s).',
  );
}
