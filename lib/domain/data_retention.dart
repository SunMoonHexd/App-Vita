/// Retención y anonimización de datos (RF44 · F18.7).

/// Tiempo que se conservan los datos de llamadas, reportes y alertas antes de anonimizarlos.
const int kDefaultRetentionDays = 365;

/// Menos que esto no se permite, para no borrar datos que todavía se necesitan.
const int kMinRetentionDays = 30;

/// Más que esto tampoco: conservar datos personales para siempre no es razonable.
const int kMaxRetentionDays = 3650;

/// Deja los días de retención dentro del rango permitido.
int clampRetention(int days) {
  if (days < kMinRetentionDays) return kMinRetentionDays;
  if (days > kMaxRetentionDays) return kMaxRetentionDays;
  return days;
}

/// ¿Ya pasó más tiempo del permitido desde [createdAt]?
bool isExpired(DateTime createdAt, DateTime now, int retentionDays) {
  return now.difference(createdAt) > Duration(days: retentionDays);
}
