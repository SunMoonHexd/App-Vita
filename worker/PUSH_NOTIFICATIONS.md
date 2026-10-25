# Avisos de solicitudes al voluntario

La app guarda el token FCM del voluntario en `pushTokens/{uid}`. Después de asignar una solicitud,
el adulto mayor llama a `/notifications/incoming-call` en este Worker. El Worker valida la sesión,
comprueba en Firestore que la solicitud siga asignada a ese voluntario y envía la notificación con
FCM HTTP v1. El token de FCM y las credenciales de servicio no se exponen en la app.

## Configuración única del Worker

1. En Google Cloud, crea una cuenta de servicio para el proyecto Firebase y habilita Firebase Cloud
   Messaging API (HTTP v1).
2. Asígnale los roles **Firebase Cloud Messaging API Admin** y **Cloud Datastore User**. El primero
   permite enviar mensajes FCM; el segundo permite consultar y actualizar los documentos usados para
   validar la solicitud y evitar duplicados.
3. Guarda el correo de la cuenta y su clave privada como secretos del Worker, con los nombres
   `GOOGLE_SERVICE_ACCOUNT_EMAIL` y `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`. Agrégalos en el panel de
   Cloudflare Workers o con Wrangler. Nunca los guardes en Git, Flutter ni en `wrangler.toml`.
4. Vuelve a desplegar `worker` para que la nueva ruta `/notifications/incoming-call` esté disponible.

La app debe registrar el token del voluntario y tener permiso de notificaciones antes de marcarlo
disponible. El emparejamiento ya no depende de que el latido de la pantalla siga activo mientras la
app está minimizada. Si no responde, la solicitud conserva el temporizador y puede reasignarse.

## Alcance actual

La notificación abre VITA; el voluntario todavía debe aceptar la solicitud desde la app. No es una
ventana de llamada sobre la pantalla bloqueada. El envío depende de FCM y de que el sistema operativo
permita las notificaciones de VITA.
