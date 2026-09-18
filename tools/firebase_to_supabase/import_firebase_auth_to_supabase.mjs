import 'dotenv/config';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { Client } from 'pg';

const toolsDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolsDir, '..', '..');
const defaultExportPath = path.join(rootDir, 'migration_exports', 'firebase_auth_users.json');
const firebaseAuthExport = process.env.FIREBASE_AUTH_EXPORT || defaultExportPath;
const databaseUrl =
  process.env.SUPABASE_DB_URL ||
  readTextIfExists(path.join(rootDir, 'supabase', '.temp', 'pooler-url'));

if (!databaseUrl) {
  throw new Error('SUPABASE_DB_URL is required, or supabase/.temp/pooler-url must exist.');
}

if (!fs.existsSync(firebaseAuthExport)) {
  throw new Error(`Firebase Auth export not found: ${firebaseAuthExport}`);
}

const exportData = JSON.parse(fs.readFileSync(firebaseAuthExport, 'utf8'));
const firebaseUsers = exportData.users || [];
const client = new Client({
  connectionString: databaseUrl,
  ssl: { rejectUnauthorized: false },
});

function readTextIfExists(filePath) {
  if (!fs.existsSync(filePath)) return '';
  return fs.readFileSync(filePath, 'utf8').trim();
}

function uuidFromFirebaseUid(uid) {
  const hash = crypto.createHash('sha256').update(`firebase:${uid}`).digest();
  hash[6] = (hash[6] & 0x0f) | 0x40;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = hash.subarray(0, 16).toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function toIso(value) {
  if (!value) return null;
  if (/^\d+$/.test(String(value))) return new Date(Number(value)).toISOString();
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function providersFor(user) {
  const providers = (user.providerUserInfo || [])
    .map((provider) => provider.providerId)
    .filter(Boolean)
    .map((provider) => provider.replace('.com', ''));
  if (user.email && !providers.includes('email')) providers.push('email');
  return providers.length ? providers : ['email'];
}

function identityData(user, provider) {
  const providerInfo = (user.providerUserInfo || []).find((item) =>
    item.providerId?.replace('.com', '') === provider
  );
  return {
    sub: providerInfo?.rawId || providerInfo?.federatedId || user.localId,
    email: providerInfo?.email || user.email,
    email_verified: user.emailVerified === true,
    phone_verified: false,
    name: providerInfo?.displayName || user.displayName || null,
    picture: providerInfo?.photoUrl || user.photoUrl || null,
    firebase_uid: user.localId,
  };
}

async function tableColumns(tableName) {
  const result = await client.query(
    `
      select column_name
      from information_schema.columns
      where table_schema = 'auth' and table_name = $1
    `,
    [tableName],
  );
  return new Set(result.rows.map((row) => row.column_name));
}

function pickColumns(data, columns) {
  return Object.fromEntries(
    Object.entries(data).filter(([key, value]) => columns.has(key) && value !== undefined),
  );
}

async function upsert(tableName, data, conflictColumn) {
  const keys = Object.keys(data);
  const params = keys.map((_, index) => `$${index + 1}`).join(', ');
  const columns = keys.map((key) => `"${key}"`).join(', ');
  const updates = keys
    .filter((key) => key !== conflictColumn)
    .map((key) => `"${key}" = excluded."${key}"`)
    .join(', ');
  await client.query(
    `
      insert into auth.${tableName} (${columns})
      values (${params})
      on conflict ("${conflictColumn}")
      do update set ${updates || `"${conflictColumn}" = excluded."${conflictColumn}"`}
    `,
    Object.values(data),
  );
}

async function main() {
  await client.connect();
  const usersColumns = await tableColumns('users');
  const identitiesColumns = await tableColumns('identities');

  let importedUsers = 0;
  let importedIdentities = 0;

  for (const user of firebaseUsers) {
    if (!user.localId || !user.email) continue;

    const id = uuidFromFirebaseUid(user.localId);
    const providers = providersFor(user);
    const createdAt = toIso(user.createdAt || user.createdAtTime || user.metadata?.creationTime) || new Date().toISOString();
    const lastSignInAt = toIso(user.lastLoginAt || user.lastRefreshAt || user.metadata?.lastSignInTime);
    const appMeta = {
      provider: providers[0],
      providers,
      firebase_uid: user.localId,
      migrated_from: 'firebase',
    };
    const userMeta = {
      firebase_uid: user.localId,
      display_name: user.displayName || null,
      full_name: user.displayName || null,
      name: user.displayName || null,
      avatar_url: user.photoUrl || null,
      picture: user.photoUrl || null,
      firebase_password_hash_present: Boolean(user.passwordHash),
    };

    const userRow = pickColumns({
      instance_id: '00000000-0000-0000-0000-000000000000',
      id,
      aud: 'authenticated',
      role: 'authenticated',
      email: user.email,
      encrypted_password: '',
      email_confirmed_at: user.emailVerified ? createdAt : null,
      invited_at: null,
      confirmation_token: '',
      confirmation_sent_at: null,
      recovery_token: '',
      recovery_sent_at: null,
      email_change_token_new: '',
      email_change: '',
      email_change_sent_at: null,
      last_sign_in_at: lastSignInAt,
      raw_app_meta_data: appMeta,
      raw_user_meta_data: userMeta,
      is_super_admin: false,
      created_at: createdAt,
      updated_at: new Date().toISOString(),
      phone: user.phoneNumber || null,
      phone_confirmed_at: user.phoneNumber ? createdAt : null,
      phone_change: '',
      phone_change_token: '',
      phone_change_sent_at: null,
      email_change_token_current: '',
      email_change_confirm_status: 0,
      banned_until: user.disabled ? '9999-12-31T23:59:59.999Z' : null,
      reauthentication_token: '',
      reauthentication_sent_at: null,
      is_sso_user: false,
      deleted_at: null,
      is_anonymous: false,
    }, usersColumns);

    await upsert('users', userRow, 'id');
    importedUsers += 1;

    for (const provider of providers.filter((item) => item !== 'email')) {
      const providerInfo = (user.providerUserInfo || []).find((item) =>
        item.providerId?.replace('.com', '') === provider
      );
      const providerId = providerInfo?.rawId || providerInfo?.federatedId || user.localId;
      const identityId = uuidFromFirebaseUid(`${provider}:${providerId}`);
      const identityRow = pickColumns({
        id: identityId,
        user_id: id,
        identity_data: identityData(user, provider),
        provider,
        provider_id: providerId,
        last_sign_in_at: lastSignInAt,
        created_at: createdAt,
        updated_at: new Date().toISOString(),
        email: user.email,
      }, identitiesColumns);

      await upsert('identities', identityRow, 'id');
      importedIdentities += 1;
    }

    await client.query(
      `
        insert into public."user" (id, email, display_name, photo_url, uid, firebase_uid, created_time, phone_number, role)
        values ($1, $2, $3, $4, $5, $6, $7, $8, coalesce($9, 'clinician'))
        on conflict (id) do update set
          email = excluded.email,
          display_name = excluded.display_name,
          photo_url = excluded.photo_url,
          uid = excluded.uid,
          firebase_uid = excluded.firebase_uid,
          created_time = excluded.created_time,
          phone_number = excluded.phone_number,
          role = coalesce(public."user".role, excluded.role)
      `,
      [
        id,
        user.email,
        user.displayName || null,
        user.photoUrl || null,
        id,
        user.localId,
        createdAt,
        user.phoneNumber || null,
        user.customAttributes ? JSON.parse(user.customAttributes).role : null,
      ],
    );
  }

  const authCount = await client.query('select count(*)::int as count from auth.users');
  const identityCount = await client.query('select count(*)::int as count from auth.identities');
  const publicUserCount = await client.query('select count(*)::int as count from public."user"');
  console.log(JSON.stringify({
    firebaseExportUsers: firebaseUsers.length,
    importedUsers,
    importedIdentities,
    supabaseAuthUsers: authCount.rows[0].count,
    supabaseIdentities: identityCount.rows[0].count,
    publicUsers: publicUserCount.rows[0].count,
  }, null, 2));
}

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await client.end().catch(() => {});
  });
