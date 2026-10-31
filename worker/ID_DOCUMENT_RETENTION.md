# Retención de documentos de identidad

- Al verificar una cédula, la app borra las dos imágenes, el número del documento y la fecha de carga del documento privado de Firestore. Conserva el estado de verificación, la fecha y el identificador de coordinación que la revisó.
- El trigger diario del Worker elimina imágenes, número y fecha de carga de cualquier cédula no verificada que lleve más de 30 días almacenada.
- El Worker usa la cuenta de servicio existente y el alcance `datastore` de Firestore. Después de actualizar el código y `wrangler.toml`, vuelve a desplegarlo desde `worker/` con `npx wrangler deploy` para activar el trigger programado.
