// Backfill missing createdAt for services collection
// Usage:
// 1) Place your Firebase service account JSON at admn/serviceAccountKey.json OR set GOOGLE_APPLICATION_CREDENTIALS env var
// 2) In project root (d:/jenisha/admn) run: node scripts/backfill_service_createdAt.js

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Try to load service account from env or file
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.join(__dirname, '..', 'serviceAccountKey.json');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS && !fs.existsSync(serviceAccountPath)) {
  console.error('Service account JSON not found. Place it at admn/serviceAccountKey.json or set GOOGLE_APPLICATION_CREDENTIALS env var.');
  process.exit(1);
}

try {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp();
  } else {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
} catch (err) {
  console.error('Failed to initialize Firebase Admin SDK:', err);
  process.exit(1);
}

const db = admin.firestore();

async function backfill() {
  console.log('Starting backfill of services.createdAt');
  const snapshot = await db.collection('services').get();
  console.log(`Found ${snapshot.size} service documents`);
  let updated = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!data.createdAt) {
      console.log(`Updating ${doc.id} -> setting createdAt`);
      await db.collection('services').doc(doc.id).update({ createdAt: admin.firestore.FieldValue.serverTimestamp() });
      updated++;
    }
  }

  console.log(`Backfill complete. Documents updated: ${updated}`);
  process.exit(0);
}

backfill().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
