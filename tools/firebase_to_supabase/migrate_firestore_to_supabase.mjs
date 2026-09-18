import 'dotenv/config';
import fs from 'node:fs';
import admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';

const defaultCollections = [
  'user',
  'clinic',
  'doctor',
  'mother',
  'first_encounter',
  'encounter',
  'parity',
  'appointments',
];

const projectId = process.env.FIREBASE_PROJECT_ID || 'dawa-ca263';
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const batchSize = Number(process.env.MIGRATION_BATCH_SIZE || 500);

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
}

if (!admin.apps.length) {
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const credential = credentialsPath && fs.existsSync(credentialsPath)
    ? admin.credential.cert(JSON.parse(fs.readFileSync(credentialsPath, 'utf8')))
    : admin.credential.applicationDefault();
  admin.initializeApp({ credential, projectId });
}

const firestore = admin.firestore();
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { persistSession: false },
});

function normalizeValue(value) {
  if (value == null) return value;
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (value instanceof admin.firestore.DocumentReference) return value.path;
  if (value instanceof admin.firestore.GeoPoint) {
    return { latitude: value.latitude, longitude: value.longitude };
  }
  if (Array.isArray(value)) return value.map(normalizeValue);
  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, normalizeValue(item)]),
    );
  }
  return value;
}

function normalizeDocument(doc) {
  return {
    id: doc.id,
    ...normalizeValue(doc.data()),
  };
}

async function migrateCollection(collectionName) {
  let migrated = 0;
  let lastDoc = null;

  while (true) {
    let query = firestore
      .collection(collectionName)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(batchSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const rows = snapshot.docs.map(normalizeDocument);
    const { error } = await supabase
      .from(collectionName)
      .upsert(rows, { onConflict: 'id' });
    if (error) throw new Error(`${collectionName}: ${error.message}`);

    migrated += rows.length;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < batchSize) break;
  }

  return migrated;
}

const collections = process.argv.slice(2);
const selectedCollections = collections.length ? collections : defaultCollections;
const results = {};

for (const collectionName of selectedCollections) {
  results[collectionName] = await migrateCollection(collectionName);
}

console.log(JSON.stringify(results, null, 2));
