import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const toolsDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(toolsDir, '..', '..');
const outputDir = path.join(rootDir, 'migration_exports', 'firestore_sql');
const projectId = process.env.FIREBASE_PROJECT_ID || 'dawa-ca263';

const schemas = {
  user: {
    table: 'user',
    columns: {
      id: 'text',
      email: 'text',
      display_name: 'text',
      photo_url: 'text',
      uid: 'text',
      firebase_uid: 'text',
      created_time: 'timestamptz',
      phone_number: 'text',
      role: 'text',
    },
  },
  clinic: {
    table: 'clinic',
    columns: {
      id: 'text',
      name: 'text',
      address: 'text',
    },
  },
  doctor: {
    table: 'doctor',
    columns: {
      id: 'text',
      speciality: 'text',
      user_Id: 'text',
      clinic_name: 'text',
      start_time: 'text',
      end_time: 'text',
      name: 'text',
      phone_number: 'text',
      doctor_id: 'text',
    },
  },
  mother: {
    table: 'mother',
    columns: {
      id: 'text',
      dateOfBirth: 'timestamptz',
      occupation: 'text',
      address: 'text',
      user_Id: 'text',
      name: 'text',
      phone_number: 'text',
      mother_id: 'text',
      first_encounter_id: 'text',
    },
  },
  first_encounter: {
    table: 'first_encounter',
    columns: {
      id: 'text',
      gravidity: 'text',
      diabetes_mellitus: 'text',
      hypertension: 'text',
      perceiving_foetal_movement: 'text',
      draining_any_liquor: 'text',
      mother_Id: 'text',
      sign_of_imminent_eclampsia: 'text[]',
      signs_of_anaemia: 'text[]',
      symptoms_of_uti: 'text[]',
      estimated_due_date: 'timestamptz',
      last_vl: 'text',
      lnmp: 'timestamptz',
      hiv_status: 'text',
      cardiac_disease: 'text',
      parity: 'int',
      herbs_taken: 'text',
      any_allergies: 'text',
      side_effect: 'text',
      menstruation_regular: 'text',
      cacx: 'text',
      cd4: 'text',
      epilepsy: 'text',
      asthma: 'text',
      tb: 'text',
      sickle_cell: 'text',
      cacx_date_of_screen: 'timestamptz',
      booked_date: 'timestamptz',
      duration_of_menstruation: 'text',
      drugs_taken: 'text[]',
      age_of_menarche: 'text',
      parity_id: 'text[]',
      sti: 'text[]',
      anc_dates: 'timestamptz[]',
    },
  },
  encounter: {
    table: 'encounter',
    columns: {
      id: 'text',
      bp: 'text',
      pulse: 'int',
      next_visit: 'timestamptz',
      comment: 'text',
      us_obstetrics: 'text',
      leucocytes_esterase: 'text',
      nitrates: 'text',
      urologobulin: 'text',
      protein: 'text',
      ph: 'text',
      blood: 'text',
      ketones: 'text',
      bilirubin: 'text',
      glucose: 'text',
      color: 'text',
      clarity: 'text',
      odor: 'text',
      casts: 'text',
      date: 'timestamptz',
      mother_id: 'text',
      refer_for_anemia: 'text',
      heart_beat: 'int',
      heart_beat_quality: 'text',
      womb_position: 'text',
      estimated_baby_size: 'int',
      hemocheck: 'int',
      specific_gravity: 'text',
      foetal_hemocheck: 'int',
      clinic_id: 'text',
      doctor_id: 'text',
      status: 'text',
      is_instant: 'boolean',
      time: 'text',
      performed_by: 'text',
      date_performed: 'timestamptz',
    },
  },
  parity: {
    table: 'parity',
    columns: {
      id: 'text',
      weight: 'text',
      state: 'text',
      mode_of_delivery: 'text',
      complications: 'text[]',
      first_encounter_id: 'text',
      year_of_birth: 'text',
      marital_status: 'text',
      mothers_height: 'text',
      prepregnancy_weight: 'text',
      mothers_education: 'text',
      fathers_age: 'text',
      fathers_education: 'text',
      kids_alive: 'int',
      kids_dead: 'int',
      miscarriages: 'int',
      birth_number: 'int',
      prenatal_care_start: 'int',
      expected_prenatal_visits: 'int',
      cigarettes_before_pregnancy: 'int',
      cigarettes_during_1st_trim: 'int',
      cigarettes_during_2nd_trim: 'int',
      cigarettes_during_3rd_trim: 'int',
      risk_factors: 'text',
      delivery_information: 'text',
      induced_labor: 'text',
      augmented_labor: 'text',
      antibiotics: 'text',
      method_of_delivery: 'text',
    },
  },
  appointments: {
    table: 'appointments',
    columns: {
      id: 'text',
      mother_Id: 'text',
      mother_id: 'text',
      doctor_id: 'text',
      status: 'text',
      date: 'timestamptz',
      time: 'text',
      payload: 'jsonb',
    },
  },
};

function uuidFromFirebaseUid(uid) {
  const hash = crypto.createHash('sha256').update(`firebase:${uid}`).digest();
  hash[6] = (hash[6] & 0x0f) | 0x40;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = hash.subarray(0, 16).toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function remapReferencePath(pathValue) {
  if (typeof pathValue !== 'string') return pathValue;
  if (!pathValue.startsWith('user/')) return pathValue;
  const firebaseUid = pathValue.slice('user/'.length);
  return `user/${uuidFromFirebaseUid(firebaseUid)}`;
}

function normalizeValue(value) {
  if (value == null) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (value instanceof admin.firestore.DocumentReference) return remapReferencePath(value.path);
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

function sqlString(value) {
  if (value == null || value === '') return 'null';
  return `'${String(value).replaceAll("'", "''")}'`;
}

function sqlValue(value, type) {
  if (value == null || value === '') return 'null';
  if (type === 'int') {
    const number = Number(value);
    return Number.isFinite(number) ? String(Math.trunc(number)) : 'null';
  }
  if (type === 'boolean') return value === true ? 'true' : value === false ? 'false' : 'null';
  if (type === 'timestamptz') return `${sqlString(value)}::timestamptz`;
  if (type === 'jsonb') return `${sqlString(JSON.stringify(value))}::jsonb`;
  if (type === 'text[]') {
    if (!Array.isArray(value)) return 'null';
    return `array[${value.map((item) => sqlString(item)).join(', ')}]::text[]`;
  }
  if (type === 'timestamptz[]') {
    if (!Array.isArray(value)) return 'null';
    return `array[${value.map((item) => `${sqlString(item)}::timestamptz`).join(', ')}]::timestamptz[]`;
  }
  return sqlString(value);
}

function sqlIdentifier(name) {
  return `"${name.replaceAll('"', '""')}"`;
}

async function fetchCollection(collectionName) {
  const snapshot = await admin.firestore().collection(collectionName).get();
  return snapshot.docs.map((doc) => {
    const data = normalizeValue(doc.data());
    if (collectionName === 'user') {
      const id = uuidFromFirebaseUid(doc.id);
      return {
        id,
        ...data,
        uid: id,
        firebase_uid: doc.id,
      };
    }
    if (collectionName === 'appointments') {
      return {
        id: doc.id,
        ...data,
        payload: data,
      };
    }
    return {
      id: doc.id,
      ...data,
    };
  });
}

function createSql(collectionName, rows) {
  const schema = schemas[collectionName];
  const columns = Object.keys(schema.columns);
  const tableName = schema.table === 'user' ? 'public."user"' : `public.${sqlIdentifier(schema.table)}`;
  const header = [
    'begin;',
    `-- ${collectionName}: ${rows.length} rows`,
  ];
  if (!rows.length) return [...header, 'commit;'].join('\n');

  const values = rows.map((row) => {
    const rowValues = columns.map((column) => sqlValue(row[column], schema.columns[column]));
    return `(${rowValues.join(', ')})`;
  });
  const updates = columns
    .filter((column) => column !== 'id')
    .map((column) => `${sqlIdentifier(column)} = excluded.${sqlIdentifier(column)}`)
    .join(',\n  ');

  return [
    ...header,
    `insert into ${tableName} (${columns.map(sqlIdentifier).join(', ')}) values`,
    values.join(',\n'),
    `on conflict ("id") do update set\n  ${updates};`,
    'commit;',
  ].join('\n');
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId,
    credential: admin.credential.applicationDefault(),
  });
}

fs.mkdirSync(outputDir, { recursive: true });
const selectedCollections = process.argv.slice(2);
const collectionNames = selectedCollections.length ? selectedCollections : Object.keys(schemas);
const summary = {};

for (const collectionName of collectionNames) {
  if (!schemas[collectionName]) throw new Error(`Unknown collection: ${collectionName}`);
  const rows = await fetchCollection(collectionName);
  const outputPath = path.join(outputDir, `${collectionName}.sql`);
  fs.writeFileSync(outputPath, createSql(collectionName, rows), 'utf8');
  summary[collectionName] = { rows: rows.length, outputPath };
}

console.log(JSON.stringify(summary, null, 2));
