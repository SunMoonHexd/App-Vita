import { createRemoteJWKSet, jwtVerify } from 'jose';
import {
  AccessToken,
  EgressClient,
  EncodedFileOutput,
  EncodedFileType,
  S3Upload,
} from 'livekit-server-sdk';

const JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
);

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

/** Solo acepta a quien haya iniciado sesión en la app (token de Firebase Auth). */
async function verifyFirebaseUser(request, env) {
  const auth = request.headers.get('authorization') || '';
  if (!auth.startsWith('Bearer ')) throw new Error('Falta iniciar sesión.');
  const { payload } = await jwtVerify(auth.slice(7), JWKS, {
    issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
    audience: env.FIREBASE_PROJECT_ID,
  });
  if (!payload.sub) throw new Error('Sesión inválida.');
  return payload.sub; // uid de Firebase
}

const validRoom = (r) => typeof r === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(r);

function egressClient(env) {
  const host = env.LIVEKIT_URL.replace('wss://', 'https://');
  return new EgressClient(host, env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET);
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return json({ error: 'Método no permitido' }, 405);
    const path = new URL(request.url).pathname;

    let uid;
    try {
      uid = await verifyFirebaseUser(request, env);
    } catch (e) {
      return json({ error: 'No autorizado' }, 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Cuerpo inválido' }, 400);
    }

    try {
      // ---- Entrar a una sala ----
      if (path === '/token') {
        if (!validRoom(body.roomName)) return json({ error: 'Sala inválida' }, 400);
        const name = String(body.displayName || 'Participante').slice(0, 60);
        const at = new AccessToken(env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET, {
          identity: uid,
          name,
          ttl: '3h',
        });
        at.addGrant({ roomJoin: true, room: body.roomName, canPublish: true, canSubscribe: true, canPublishData: true });
        return json({ token: await at.toJwt(), url: env.LIVEKIT_URL });
      }

      // ---- Empezar a grabar (solo cuando la app lo pide, tras el consentimiento) ----
      if (path === '/record/start') {
        if (!validRoom(body.roomName)) return json({ error: 'Sala inválida' }, 400);
        const stamp = new Date().toISOString().replace(/[:.]/g, '-');
        const output = new EncodedFileOutput({
          fileType: EncodedFileType.MP4,
          filepath: `${body.roomName}/${stamp}.mp4`,
          output: {
            case: 's3',
            value: new S3Upload({
              accessKey: env.S3_ACCESS_KEY,
              secret: env.S3_SECRET,
              endpoint: env.S3_ENDPOINT,
              region: env.S3_REGION,
              bucket: env.S3_BUCKET,
              forcePathStyle: true,
            }),
          },
        });
        const info = await egressClient(env).startRoomCompositeEgress(body.roomName, output, { layout: 'grid' });
        return json({ egressId: info.egressId });
      }

      // ---- Detener la grabación ----
      if (path === '/record/stop') {
        if (typeof body.egressId !== 'string' || body.egressId.length > 80) return json({ error: 'Id inválido' }, 400);
        await egressClient(env).stopEgress(body.egressId);
        return json({ ok: true });
      }

      return json({ error: 'No encontrado' }, 404);
    } catch (e) {
      return json({ error: 'Error del servidor', detail: String(e.message || e) }, 500);
    }
  },
};
