String _two(int n) => n.toString().padLeft(2, '0');

/// 45 min  /  1 h 30 min
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) return '${d.inMinutes} min';
  return '$hours h $minutes min';
}

/// 14/10/2026 · 3:20 p. m.
String formatDateTime(DateTime d) {
  final local = d.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour < 12 ? 'a. m.' : 'p. m.';
  return '${_two(local.day)}/${_two(local.month)}/${local.year} · $hour12:${_two(local.minute)} $suffix';
}

/// Solo el primer nombre (o "Cuenta eliminada" tal cual).
String shortName(String name, {String fallback = 'Adulto mayor'}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed == 'Cuenta eliminada') return trimmed;
  return trimmed.split(' ').first;
}
