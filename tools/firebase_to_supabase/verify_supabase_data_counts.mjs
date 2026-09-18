import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { Client } from 'pg';

const toolsDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolsDir, '..', '..');
const databaseUrl =
  process.env.SUPABASE_DB_URL ||
  readTextIfExists(path.join(rootDir, 'supabase', '.temp', 'pooler-url'));

if (!databaseUrl) {
  throw new Error('SUPABASE_DB_URL is required, or supabase/.temp/pooler-url must exist.');
}

function readTextIfExists(filePath) {
  if (!fs.existsSync(filePath)) return '';
  return fs.readFileSync(filePath, 'utf8').trim();
}

const tables = [
  'user',
  'clinic',
  'doctor',
  'mother',
  'first_encounter',
  'encounter',
  'parity',
  'appointments',
];

const client = new Client({
  connectionString: databaseUrl,
  ssl: { rejectUnauthorized: false },
});

await client.connect();

const authUsers = await client.query('select count(*)::int as count from auth.users');
const identities = await client.query('select count(*)::int as count from auth.identities');
const tableCounts = {};

for (const table of tables) {
  const result = await client.query(`select count(*)::int as count from public."${table}"`);
  tableCounts[table] = result.rows[0].count;
}

console.log(JSON.stringify({
  authUsers: authUsers.rows[0].count,
  identities: identities.rows[0].count,
  tables: tableCounts,
}, null, 2));

await client.end();
