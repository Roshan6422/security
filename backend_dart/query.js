const admin = require('firebase-admin');
const fs = require('fs');

const env = fs.readFileSync('.env', 'utf8');
const match = env.match(/FIREBASE_SERVICE_ACCOUNT_BASE64=(.+)/);
const serviceAccountString = Buffer.from(match[1], 'base64').toString('utf8');
const serviceAccount = JSON.parse(serviceAccountString);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function run() {
  const snapshot = await db.collection('vaultItems').get();
  console.log(`Found ${snapshot.size} items in vaultItems`);
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`${data.name} | user=${data.user} | type=${data.type}`);
  });
  
  const snapshot2 = await db.collection('vault_items').get();
  console.log(`Found ${snapshot2.size} items in vault_items`);
  snapshot2.forEach(doc => {
    const data = doc.data();
    console.log(`${data.name} | user=${data.user} | type=${data.type}`);
  });
}

run().catch(console.error);
