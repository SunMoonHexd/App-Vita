import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose';
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

let googleAccessTokenCache;
let googleAccessTokenExpiresAt = 0;

async function getGoogleAccessToken(env) {
  if (googleAccessTokenCache && Date.now() < googleAccessTokenExpiresAt - 60_000) {
    return googleAccessTokenCache;
  }
  if (!env.GOOGLE_SERVICE_ACCOUNT_EMAIL || !env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY) {
    throw new Error('Falta configurar la cuenta de servicio para notificaciones.');
  }

  const privateKey = env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, '\n');
  const key = await importPKCS8(privateKey, 'RS256');
  const assertion = await new SignJWT({
    scope: [
      'https://www.googleapis.com/auth/datastore',
      'https://www.googleapis.com/auth/firebase.messaging',
    ].join(' '),
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(env.GOOGLE_SERVICE_ACCOUNT_EMAIL)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error('No se pudo autenticar el servicio de notificaciones.');
  const data = await response.json();
  googleAccessTokenCache = data.access_token;
  googleAccessTokenExpiresAt = Date.now() + Number(data.expires_in || 3600) * 1000;
  return googleAccessTokenCache;
}

async function getFirestoreDocument(env, accessToken, documentPath) {
  const path = documentPath.split('/').map(encodeURIComponent).join('/');
  const url = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`;
  const response = await fetch(url, { headers: { authorization: `Bearer ${accessToken}` } });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error('No se pudo consultar la solicitud en Firestore.');
  return response.json();
}

async function patchFirestoreDocument(env, accessToken, documentPath, fields) {
  const path = documentPath.split('/').map(encodeURIComponent).join('/');
  const url = new URL(`https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`);
  for (const field of Object.keys(fields)) url.searchParams.append('updateMask.fieldPaths', field);
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!response.ok) throw new Error('No se pudo actualizar el registro de notificación.');
}

async function purgeExpiredIdentityDocuments(env) {
  const accessToken = await getGoogleAccessToken(env);
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const queryUrl = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery`;
  const response = await fetch(queryUrl, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'private' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'idDocumentsUploadedAt' },
            op: 'LESS_THAN',
            value: { stringValue: cutoff },
          },
        },
        limit: 500,
      },
    }),
  });
  if (!response.ok) throw new Error('No se pudo buscar cédulas vencidas en Firestore.');
  const rows = await response.json();
  const expired = rows.map((row) => row.document).filter((doc) =>
    doc?.fields?.idFrontBase64?.stringValue || doc?.fields?.idBackBase64?.stringValue,
  );
  const deletedAt = new Date().toISOString();
  for (let i = 0; i < expired.length; i += 20) {
    await Promise.all(expired.slice(i, i + 20).map(async (document) => {
      const documentId = document.name.split('/').at(-1);
      const path = `private/${documentId}`;
      const url = new URL(`https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`);
      for (const field of ['idFrontBase64', 'idBackBase64', 'documentId', 'idDocumentsUploadedAt', 'identityDocumentsDeletedAt']) {
        url.searchParams.append('updateMask.fieldPaths', field);
      }
      const deleteResponse = await fetch(url, {
        method: 'PATCH',
        headers: {
          authorization: `Bearer ${accessToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          fields: { identityDocumentsDeletedAt: { timestampValue: deletedAt } },
        }),
      });
      if (!deleteResponse.ok) throw new Error('No se pudo eliminar una cédula vencida de Firestore.');
    }));
  }
  return expired.length;
}

const stringField = (document, name) => document?.fields?.[name]?.stringValue;
const boolField = (document, name) => document?.fields?.[name]?.booleanValue === true;
const integerField = (document, name) => Number(document?.fields?.[name]?.integerValue || 0);

async function notifyIncomingCall(request, uid, env) {
  const requestId = request.requestId;
  if (typeof requestId !== 'string' || !/^[A-Za-z0-9_-]{1,120}$/.test(requestId)) {
    return json({ error: 'Solicitud inválida' }, 400);
  }

  const accessToken = await getGoogleAccessToken(env);
  const call = await getFirestoreDocument(env, accessToken, `requests/${requestId}`);
  if (!call || stringField(call, 'elderlyId') !== uid) {
    return json({ error: 'Solicitud no encontrada' }, 404);
  }
  if (stringField(call, 'status') !== 'ringing') {
    return json({ ok: true, delivered: false, reason: 'not_ringing' });
  }

  const volunteerId = stringField(call, 'volunteerId');
  if (!volunteerId) return json({ ok: true, delivered: false, reason: 'no_volunteer' });
  const volunteer = await getFirestoreDocument(env, accessToken, `users/${volunteerId}`);
  if (
    stringField(volunteer, 'role') !== 'volunteer' ||
    stringField(volunteer, 'status') !== 'active' ||
    !boolField(volunteer, 'available')
  ) {
    return json({ ok: true, delivered: false, reason: 'volunteer_unavailable' });
  }

  const tokenDocument = await getFirestoreDocument(env, accessToken, `pushTokens/${volunteerId}`);
  const token = stringField(tokenDocument, 'token');
  if (!token) return json({ ok: true, delivered: false, reason: 'token_missing' });

  const attempt = integerField(call, 'attempts');
  const audioOnly = boolField(call, 'audioOnly');
  if (
    stringField(call, 'pushNotificationSentToVolunteer') === volunteerId &&
    integerField(call, 'pushNotificationSentAtAttempt') === attempt
  ) {
    return json({ ok: true, delivered: true, duplicate: true });
  }

  await patchFirestoreDocument(env, accessToken, `requests/${requestId}`, {
    pushNotificationSentToVolunteer: { stringValue: volunteerId },
    pushNotificationSentAtAttempt: { integerValue: String(attempt) },
  });

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: audioOnly ? 'Te invitan a conversar por voz' : '¡Hay alguien esperando compañía!',
            body: audioOnly
              ? 'Tienes una solicitud de llamada de voz en VITA. Toca para responder.'
              : 'Tienes una solicitud de videollamada en VITA. Toca para responder.',
          },
          data: { type: 'incoming_call', requestId },
          android: {
            priority: 'HIGH',
            notification: {
              icon: 'ic_stat_vita',
              color: '#14877A',
              sound: 'default',
            },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );
  if (!response.ok) {
    await patchFirestoreDocument(env, accessToken, `requests/${requestId}`, {
      pushNotificationSentToVolunteer: { nullValue: null },
      pushNotificationSentAtAttempt: { nullValue: null },
    });
    throw new Error('Firebase no pudo entregar la notificación.');
  }
  return json({ ok: true, delivered: true });
}

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

const validId = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,120}$/.test(v);

/**
 * ¿Puede este usuario entrar a la sala como profesional de apoyo?
 * Debe ser un psicólogo activo y tener una solicitud de apoyo ACEPTADA por él,
 * de esta misma llamada y de esta misma sala.
 */
async function canJoinAsPsychologist(env, accessToken, uid, body) {
  if (!validId(body.supportRequestId)) return false;
  const [user, support] = await Promise.all([
    getFirestoreDocument(env, accessToken, `users/${uid}`),
    getFirestoreDocument(env, accessToken, `supportRequests/${body.supportRequestId}`),
  ]);
  return (
    !!user &&
    !!support &&
    stringField(user, 'role') === 'psychologist' &&
    stringField(user, 'status') === 'active' &&
    stringField(support, 'status') === 'accepted' &&
    stringField(support, 'psychologistId') === uid &&
    stringField(support, 'callId') === body.requestId &&
    stringField(support, 'roomName') === body.roomName
  );
}

const validRoom = (r) => typeof r === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(r);

function egressClient(env) {
  const host = env.LIVEKIT_URL.replace('wss://', 'https://');
  return new EgressClient(host, env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET);
}

export default {
  async scheduled(_controller, env) {
    const deleted = await purgeExpiredIdentityDocuments(env);
    console.log(`Se eliminaron ${deleted} documentos de identidad vencidos.`);
  },

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
      if (path === '/notifications/incoming-call') {
        return await notifyIncomingCall(body, uid, env);
      }

      // ---- Entrar a una sala ----
      if (path === '/token') {
        if (!validRoom(body.roomName)) return json({ error: 'Sala inválida' }, 400);
        if (typeof body.requestId !== 'string' || !/^[A-Za-z0-9_-]{1,120}$/.test(body.requestId)) {
          return json({ error: 'Solicitud inválida' }, 400);
        }
        const accessToken = await getGoogleAccessToken(env);
        const call = await getFirestoreDocument(env, accessToken, `requests/${body.requestId}`);
        const isParticipant =
          stringField(call, 'elderlyId') === uid || stringField(call, 'volunteerId') === uid;
        // Un psicólogo no es parte de la llamada: entra solo con una solicitud de apoyo aceptada.
        const isSupport =
          !!call && !isParticipant && (await canJoinAsPsychologist(env, accessToken, uid, body));
        if (
          !call ||
          !(isParticipant || isSupport) ||
          stringField(call, 'status') !== 'connected' ||
          stringField(call, 'roomName') !== body.roomName
        ) {
          return json({ error: 'No tienes acceso a esta llamada.' }, 403);
        }
        const name = String(body.displayName || 'Participante').slice(0, 60);
        const at = new AccessToken(env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET, {
          identity: uid,
          name,
          ttl: '3h',
        });
        at.addGrant({
          roomJoin: true,
          room: body.roomName,
          canPublish: true,
          canSubscribe: true,
          canPublishData: true,
          canUpdateOwnMetadata: true,
        });
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
