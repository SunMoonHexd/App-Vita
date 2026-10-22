# Migración de JaaS a LiveKit (VITA, solo Android)

## Qué hay en esta carpeta
- `worker/`  Cloudflare Worker: entrega los pases de LiveKit y inicia/detiene la grabación.
- `lib/`     Archivos de Flutter. Cópialos encima de los de tu proyecto (misma ruta).
  - NUEVOS: `config/livekit_config.dart`, `config/app_navigator.dart`,
    `data/services/livekit_api.dart`, `data/services/livekit_call_service.dart`,
    `ui/features/call/livekit_call_screen.dart`
  - CAMBIADOS: `main.dart`, `data/repositories/vita_repository.dart` (solo el tipo del servicio),
    `ui/core/widgets/vita_widgets.dart` y `ui/features/shared/legal_text_view.dart` (texto de grabación)
- `pubspec.yaml` y `android_app_src_main/AndroidManifest.xml` (va en `android/app/src/main/`):
  cambian Jitsi por `livekit_client` y agregan dos permisos.

## Archivos que debes BORRAR de tu proyecto
- `lib/data/services/jitsi_call_service.dart`
- `lib/data/services/jaas_token.dart`
- `lib/config/jaas_secrets.dart`  (y revoca esa clave en JaaS si alguna vez estuvo en GitHub)

## Pasos
1. En Git: `git checkout -b livekit-migration`
2. **LiveKit Cloud** (cloud.livekit.io): crea un proyecto. Guarda la URL (`wss://...livekit.cloud`),
   la API Key y el API Secret (Settings > Keys).
3. **Supabase** (para guardar las grabaciones): crea un proyecto y un bucket PRIVADO llamado `recordings`.
   En Project Settings > Storage > S3 Connection copia el endpoint, la región y crea un par de claves S3.
4. **Worker**: edita `worker/wrangler.toml` con tus datos (el projectId de Firebase ya está: `app-vita-b55c4`). Luego, dentro de `worker/`:
   ```
   npm install
   npx wrangler login
   npx wrangler secret put LIVEKIT_API_KEY
   npx wrangler secret put LIVEKIT_API_SECRET
   npx wrangler secret put S3_ACCESS_KEY
   npx wrangler secret put S3_SECRET
   npx wrangler deploy
   ```
   Al terminar te da una dirección `https://vita-livekit.XXXX.workers.dev`.
5. **Flutter**: copia los archivos, borra los tres de arriba, pega esa dirección en
   `lib/config/livekit_config.dart`, y ejecuta `flutter pub get` y `flutter run` en un celular.
6. Prueba con DOS celulares (o un celular y otro dispositivo con otra cuenta).

## Lista de pruebas
- [ ] Una llamada normal conecta video y audio en ambos sentidos.
- [ ] Silenciar micrófono / apagar cámara funciona y la otra persona lo ve.
- [ ] Si uno cuelga, al otro se le cierra la llamada a los ~5 s y aparece la encuesta.
- [ ] Apagar el wifi a uno a mitad de llamada: muestra "Reconectando…" y luego vuelve o queda "interrumpida".
- [ ] Grabar: una persona pulsa Grabar, la otra ve el aviso, acepta, ambas ven "REC".
- [ ] Rechazar la grabación no graba nada.
- [ ] Detener: aparece un .mp4 en el bucket `recordings` de Supabase.

## Importante / limitaciones
- NO pude compilar ni ejecutar nada en mi entorno (sin Flutter y sin acceso a npm). El código está revisado
  contra la documentación de `livekit_client` 2.x pero puede haber errores de compilación pequeños en la
  primera ejecución: pásame el mensaje y lo corrijo.
- Grabar usa cuota de "transcode/egress" del plan gratis (60 min). Cada vez que una persona pulsa Detener,
  deja de consumir.
- El Worker comprueba que quien pide un pase tenga sesión de Firebase, pero no que pertenezca a esa
  llamada en concreto (los nombres de sala son aleatorios). Suficiente para una demo; para producción habría
  que validar contra Firestore.
- Nunca subas las claves de LiveKit, Supabase ni Cloudflare a GitHub. Van solo como "secrets" del Worker.
