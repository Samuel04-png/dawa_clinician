import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolsDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolsDir, '..', '..');
const inputPath =
  process.env.FIREBASE_AUTH_EXPORT ||
  path.join(rootDir, 'migration_exports', 'firebase_auth_users.json');
const outputPath =
  process.env.AUTH_IMPORT_SQL ||
  path.join(rootDir, 'migration_exports', 'import_auth_users.sql');

if (!fs.existsSync(inputPath)) {
  throw new Error(`Firebase Auth export not found: ${inputPath}`);
}

const firebaseUsers = JSON.parse(fs.readFileSync(inputPath, 'utf8')).users || [];

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

function sqlString(value) {
  if (value == null) return 'null';
  return `'${String(value).replaceAll("'", "''")}'`;
}

function sqlJson(value) {
  return `${sqlString(JSON.stringify(value))}::jsonb`;
}

function sqlTimestamp(value) {
  return value ? `${sqlString(value)}::timestamptz` : 'null';
}

function providersFor(user) {
  const providers = (user.providerUserInfo || [])
    .map((provider) => provider.providerId)
    .filter(Boolean)
    .map((provider) => provider.replace('.com', ''));
  if (user.email && !providers.includes('email')) providers.push('email');
  return providers.length ? providers : ['email'];
}

function identityData(user, provider, providerId) {
  const providerInfo = (user.providerUserInfo || []).find((item) =>
    item.providerId?.replace('.com', '') === provider
  );
  return {
    sub: providerId,
    email: providerInfo?.email || user.email,
    email_verified: user.emailVerified === true,
    phone_verified: false,
    name: providerInfo?.displayName || user.displayName || null,
    picture: providerInfo?.photoUrl || user.photoUrl || null,
    firebase_uid: user.localId,
  };
}

function customRole(user) {
  if (!user.customAttributes) return null;
  try {
    return JSON.parse(user.customAttributes).role || null;
  } catch {
    return null;
  }
}

const statements = [
  'begin;',
  'create extension if not exists pgcrypto;',
];

let generatedUsers = 0;
let generatedIdentities = 0;

for (const user of firebaseUsers) {
  if (!user.localId || !user.email) continue;

  const id = uuidFromFirebaseUid(user.localId);
  const providers = providersFor(user);
  const createdAt =
    toIso(user.createdAt || user.createdAtTime || user.metadata?.creationTime) ||
    new Date().toISOString();
  const lastSignInAt = toIso(user.lastLoginAt || user.lastRefreshAt || user.metadata?.lastSignInTime);
  const randomPassword = crypto.randomBytes(24).toString('base64url');
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
    firebase_password_hash: user.passwordHash || null,
    firebase_password_salt: user.salt || null,
    firebase_password_hash_algorithm: 'SCRYPT',
  };

  statements.push(`
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  invited_at, confirmation_token, confirmation_sent_at, recovery_token,
  recovery_sent_at, email_change_token_new, email_change, email_change_sent_at,
  last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
  created_at, updated_at, phone, phone_confirmed_at, phone_change,
  phone_change_token, phone_change_sent_at, email_change_token_current,
  email_change_confirm_status, banned_until, reauthentication_token,
  reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000'::uuid,
  ${sqlString(id)}::uuid,
  'authenticated',
  'authenticated',
  ${sqlString(user.email)},
  crypt(${sqlString(randomPassword)}, gen_salt('bf')),
  ${user.emailVerified ? sqlTimestamp(createdAt) : 'null'},
  null,
  '',
  null,
  '',
  null,
  '',
  '',
  null,
  ${sqlTimestamp(lastSignInAt)},
  ${sqlJson(appMeta)},
  ${sqlJson(userMeta)},
  false,
  ${sqlTimestamp(createdAt)},
  now(),
  ${sqlString(user.phoneNumber || null)},
  ${user.phoneNumber ? sqlTimestamp(createdAt) : 'null'},
  '',
  '',
  null,
  '',
  0,
  ${user.disabled ? "'9999-12-31T23:59:59.999Z'::timestamptz" : 'null'},
  '',
  null,
  false,
  null,
  false
) on conflict (id) do update set
  email = excluded.email,
  raw_app_meta_data = excluded.raw_app_meta_data,
  raw_user_meta_data = excluded.raw_user_meta_data,
  updated_at = now();
`);
  generatedUsers += 1;

  const emailIdentityId = uuidFromFirebaseUid(`email:${id}`);
  statements.push(`
insert into auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) values (
  ${sqlString(emailIdentityId)}::uuid,
  ${sqlString(id)}::uuid,
  ${sqlJson(identityData(user, 'email', id))},
  'email',
  ${sqlString(id)},
  ${sqlTimestamp(lastSignInAt)},
  ${sqlTimestamp(createdAt)},
  now()
) on conflict (provider_id, provider) do update set
  user_id = excluded.user_id,
  identity_data = excluded.identity_data,
  updated_at = now();
`);
  generatedIdentities += 1;

  for (const provider of providers.filter((item) => item !== 'email')) {
    const providerInfo = (user.providerUserInfo || []).find((item) =>
      item.providerId?.replace('.com', '') === provider
    );
    const providerId = providerInfo?.rawId || providerInfo?.federatedId || user.localId;
    const identityId = uuidFromFirebaseUid(`${provider}:${providerId}`);
    statements.push(`
insert into auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) values (
  ${sqlString(identityId)}::uuid,
  ${sqlString(id)}::uuid,
  ${sqlJson(identityData(user, provider, providerId))},
  ${sqlString(provider)},
  ${sqlString(providerId)},
  ${sqlTimestamp(lastSignInAt)},
  ${sqlTimestamp(createdAt)},
  now()
) on conflict (provider_id, provider) do update set
  user_id = excluded.user_id,
  identity_data = excluded.identity_data,
  updated_at = now();
`);
    generatedIdentities += 1;
  }

  statements.push(`
insert into public."user" (
  id, email, display_name, photo_url, uid, firebase_uid, created_time, phone_number, role
) values (
  ${sqlString(id)},
  ${sqlString(user.email)},
  ${sqlString(user.displayName || null)},
  ${sqlString(user.photoUrl || null)},
  ${sqlString(id)},
  ${sqlString(user.localId)},
  ${sqlTimestamp(createdAt)},
  ${sqlString(user.phoneNumber || null)},
  coalesce(${sqlString(customRole(user))}, 'clinician')
) on conflict (id) do update set
  email = excluded.email,
  display_name = excluded.display_name,
  photo_url = excluded.photo_url,
  uid = excluded.uid,
  firebase_uid = excluded.firebase_uid,
  created_time = excluded.created_time,
  phone_number = excluded.phone_number,
  role = coalesce(public."user".role, excluded.role);
`);
}

statements.push('commit;');
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, statements.join('\n'), 'utf8');

console.log(JSON.stringify({
  outputPath,
  firebaseExportUsers: firebaseUsers.length,
  generatedUsers,
  generatedIdentities,
}, null, 2));
