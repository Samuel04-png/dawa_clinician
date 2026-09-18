import 'dotenv/config';
import fs from 'node:fs';
import admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';

const collections = [
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

async function firebaseCount(collectionName) {
  const result = await firestore.collection(collectionName).count().get();
  return result.data().count;
}

async function supabaseTableCount(tableName) {
  const { count, error } = await supabase
    .from(tableName)
    .select('id', { count: 'exact', head: true });
  if (error) throw new Error(`${tableName}: ${error.message}`);
  return count ?? 0;
}

async function supabaseAuthCount() {
  let page = 1;
  let total = 0;
  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    const users = data?.users ?? [];
    total += users.length;
    if (users.length < 1000) break;
    page += 1;
  }
  return total;
}

function firebaseAuthExportCount() {
  const authExport = process.env.FIREBASE_AUTH_EXPORT;
  if (!authExport || !fs.existsSync(authExport)) return null;
  const data = JSON.parse(fs.readFileSync(authExport, 'utf8'));
  return (data.users || []).length;
}

const tables = {};
for (const collectionName of collections) {
  tables[collectionName] = {
    firebase: await firebaseCount(collectionName),
    supabase: await supabaseTableCount(collectionName),
  };
}

console.log(JSON.stringify({
  auth: {
    firebaseExport: firebaseAuthExportCount(),
    supabase: await supabaseAuthCount(),
  },
  tables,
}, null, 2));
