import admin from "npm:firebase-admin@11.11.0";

const serviceAccountKey = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

if (!serviceAccountKey) {
  throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret.");
}

if (admin.apps.length === 0) {
  const serviceAccount = JSON.parse(serviceAccountKey);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    });
  }

  try {
    // [NEW] We added chatId, senderId, and senderName to the extraction list
    const { fcmToken, title, body, chatId, senderId, senderName } = await req.json();

    if (!fcmToken) {
      return new Response(JSON.stringify({ error: "Missing FCM Token" }), { status: 400 });
    }

    const payload = {
      notification: { title, body },
      // [NEW] This is the hidden suitcase of data that Google will deliver to your app!
      // (Google requires all values inside 'data' to be strings)
      data: {
        chatId: String(chatId || ''),
        senderId: String(senderId || ''),
        senderName: String(senderName || ''),
      },
      token: fcmToken
    };

    const response = await admin.messaging().send(payload);

    return new Response(JSON.stringify({ success: true, messageId: response }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    });

  } catch (error: any) {
    console.error("Error sending message:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});