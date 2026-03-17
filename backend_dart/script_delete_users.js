const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config();

async function main() {
  console.log('Starting user wipe script (Node.js Admin SDK)...');

  const base64String = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!base64String) {
    console.error('FIREBASE_SERVICE_ACCOUNT_BASE64 missing from environment.');
    process.exit(1);
  }

  try {
    const jsonString = Buffer.from(base64String, 'base64').toString('utf-8');
    const serviceAccount = JSON.parse(jsonString);

    // Clean private key just like Dart wrapper does
    if (serviceAccount.private_key) {
       serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');
    }

    const app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });

    const firestore = admin.firestore(app);
    const auth = admin.auth(app);

    console.log('Fetching Firestore users...');
    const snapshot = await firestore.collection('users').get();
    console.log(`Found ${snapshot.docs.length} users in Firestore.`);
    
    // Batch delete Firestore users
    const batch = firestore.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      console.log(`Prepared deletion of Firestore doc: ${doc.id}`);
    });
    
    if (snapshot.docs.length > 0) {
      await batch.commit();
      console.log('Firestore batch delete committed successfully.');
    }

    // console.log('\Fetching Firebase Auth users...');
    // let listUsersResult = await auth.listUsers(1000);
    // let authUsers = listUsersResult.users;
    // console.log(`Found ${authUsers.length} users in Firebase Auth.`);
    // 
    // for (const user of authUsers) {
    //   await auth.deleteUser(user.uid);
    //   console.log(`Deleted Auth user: ${user.uid} (${user.email || 'No email'})`);
    // }

    console.log('\nSuccessfully wiped all users from Firestore.');
    process.exit(0);
  } catch (error) {
    console.error('Error during deletion:', error);
    process.exit(1);
  }
}

main();
