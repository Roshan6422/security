# Koyeb Firebase Setup Instructions

I have prepared the necessary configuration for connecting your backend to Firebase on Koyeb.

## 1. Get the Service Account Key

I have generated the correct Base64-encoded Service Account Key for you. It is saved in `d:\security\firebase_key_b64.txt`.

Copy the entire content of that file. It should look like this (but much longer):

```
eyJ0eXBlIjoic2VydmljZV9hY2NvdW50IiwicHJvamVjdF9pZCI6InNhZmVzaGF...
```

## 2. Configure Koyeb

1. Go to your **Koyeb Dashboard**.
2. Select your Service.
3. Go to **Settings** -> **Environment Variables**.
4. Add a new variable:
   - **Key**: `FIREBASE_SERVICE_ACCOUNT_BASE64`
   - **Value**: (Paste the long string you copied from `d:\security\firebase_key_b64.txt`)
5. Save the changes.
6. **Redeploy** your service.

## 3. Verify Connection

Once redeployed, check the Koyeb logs. You should see:
```
[FIREBASE] Found FIREBASE_SERVICE_ACCOUNT_BASE64 env variable
...
✅ Firebase Admin SDK Initialized
✅ Firestore connection verified
```

If you see these checks pass, your backend is successfully connected to Firebase!
