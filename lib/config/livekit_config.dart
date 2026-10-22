/// Dirección del servidor que entrega los "pases" de LiveKit y controla la grabación
/// (el Cloudflare Worker de la carpeta worker/). Aquí NO va ninguna clave secreta.
/// Se ve así después de desplegar:  https://vita-livekit.TU-USUARIO.workers.dev
const String kTokenServerUrl = 'https://vita-livekit.vita-livekit-demo-2026.workers.dev';

bool get livekitConfigured => !kTokenServerUrl.contains('CAMBIA');
