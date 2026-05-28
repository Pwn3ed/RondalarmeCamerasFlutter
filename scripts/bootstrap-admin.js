#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const part = argv[i];
    if (!part.startsWith('--')) continue;
    const key = part.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function requiredArg(args, name) {
  const value = args[name];
  if (!value || value === true) {
    throw new Error(`Missing required argument --${name}`);
  }
  return String(value).trim();
}

function loadConfigFile(configPath) {
  const resolved = path.resolve(configPath);
  ensureFile(resolved);
  const raw = fs.readFileSync(resolved, 'utf8');
  return JSON.parse(raw);
}

function printUsage() {
  console.log(`
Usage:
  node scripts/bootstrap-admin.js \\
    --service-account /path/service-account.json \\
    --email admin@exemplo.com \\
    --password "SenhaForte123" \\
    --display-name "Administrador" \\
    --wipe-users true \\
    --wipe-cameras false \\
    --confirm WIPE_ALL

Required:
  --service-account  Path to Firebase service account JSON
  --email            Admin email to create
  --password         Admin password (min 8 chars)
  --display-name     Admin display name

Safety:
  --wipe-users true  Deletes all Auth users and users/sessions/audit_logs docs
  --wipe-cameras     Optional. If true, deletes all cameras docs too
  --confirm WIPE_ALL Required when --wipe-users true
`);
}

function toBool(value, fallback = false) {
  if (value === undefined) return fallback;
  if (typeof value === 'boolean') return value;
  return ['1', 'true', 'yes', 'y'].includes(String(value).toLowerCase());
}

function ensureFile(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
}

async function listAllAuthUsers() {
  const users = [];
  let nextPageToken;
  do {
    const res = await admin.auth().listUsers(1000, nextPageToken);
    users.push(...res.users);
    nextPageToken = res.pageToken;
  } while (nextPageToken);
  return users;
}

async function deleteAuthUsersInBatches(uids) {
  const batchSize = 1000;
  let deleted = 0;

  for (let i = 0; i < uids.length; i += batchSize) {
    const batch = uids.slice(i, i + batchSize);
    if (batch.length === 0) continue;
    const result = await admin.auth().deleteUsers(batch);
    deleted += result.successCount;
    if (result.failureCount > 0) {
      console.warn(
        `Warning: failed to delete ${result.failureCount} auth user(s) in batch ${Math.floor(i / batchSize) + 1}.`
      );
    }
  }

  return deleted;
}

async function deleteCollection(collectionName, pageSize = 300) {
  const db = admin.firestore();
  let totalDeleted = 0;

  while (true) {
    const snap = await db.collection(collectionName).limit(pageSize).get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    totalDeleted += snap.size;
  }

  return totalDeleted;
}

async function wipeData({ wipeCameras }) {
  console.log('Deleting all Firebase Auth users...');
  const users = await listAllAuthUsers();
  const userUids = users.map((u) => u.uid);
  const authDeleted = await deleteAuthUsersInBatches(userUids);
  console.log(`Auth users deleted: ${authDeleted}`);

  console.log('Deleting Firestore collection: users');
  const usersDeleted = await deleteCollection('users');
  console.log(`Firestore users docs deleted: ${usersDeleted}`);

  console.log('Deleting Firestore collection: sessions');
  const sessionsDeleted = await deleteCollection('sessions');
  console.log(`Firestore sessions docs deleted: ${sessionsDeleted}`);

  console.log('Deleting Firestore collection: audit_logs');
  const logsDeleted = await deleteCollection('audit_logs');
  console.log(`Firestore audit_logs docs deleted: ${logsDeleted}`);

  let camerasDeleted = 0;
  if (wipeCameras) {
    console.log('Deleting Firestore collection: cameras');
    camerasDeleted = await deleteCollection('cameras');
    console.log(`Firestore cameras docs deleted: ${camerasDeleted}`);
  }

  return { authDeleted, usersDeleted, sessionsDeleted, logsDeleted, camerasDeleted };
}

async function createOrUpdateAdminProfile({ email, password, displayName }) {
  let userRecord;

  try {
    userRecord = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(userRecord.uid, {
      password,
      displayName,
      disabled: false,
    });
    console.log(`Updated existing Auth user: ${userRecord.uid}`);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
      disabled: false,
    });
    console.log(`Created Auth user: ${userRecord.uid}`);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await admin.firestore().collection('users').doc(userRecord.uid).set(
    {
      email,
      displayName,
      role: 'admin',
      mustChangePassword: false,
      disabled: false,
      maxDevices: 99,
      createdAt: now,
    },
    { merge: true }
  );

  return userRecord.uid;
}

async function main() {
  const cliArgs = parseArgs(process.argv);
  const configPath =
      typeof cliArgs.config === 'string' ? cliArgs.config : null;
  const configArgs = configPath ? loadConfigFile(configPath) : {};
  const args = { ...configArgs, ...cliArgs };
  if (args.help || args.h) {
    printUsage();
    return;
  }

  const serviceAccountPath = path.resolve(requiredArg(args, 'service-account'));
  const email = requiredArg(args, 'email');
  const password = requiredArg(args, 'password');
  const displayName = requiredArg(args, 'display-name');
  const wipeUsers = toBool(args['wipe-users'], false);
  const wipeCameras = toBool(args['wipe-cameras'], false);
  const confirm = String(args.confirm || '');

  if (password.length < 8) {
    throw new Error('Password must have at least 8 characters.');
  }

  if (wipeUsers && confirm !== 'WIPE_ALL') {
    throw new Error(
      'Refusing to wipe users without explicit confirmation. Use --confirm WIPE_ALL'
    );
  }

  ensureFile(serviceAccountPath);
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  if (wipeUsers) {
    await wipeData({ wipeCameras });
  } else {
    console.log('Skipping wipe step (--wipe-users not enabled).');
  }

  const uid = await createOrUpdateAdminProfile({ email, password, displayName });
  console.log(`Admin bootstrap complete. UID: ${uid}`);
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exit(1);
});
