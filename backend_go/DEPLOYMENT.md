# Cloud Run Deployment Guide

To deploy the Go backend to Cloud Run, follow these steps:

### 1. Install Google Cloud SDK
Ensure you have the `gcloud` CLI installed and authenticated:
```bash
gcloud auth login
gcloud config set project [YOUR_PROJECT_ID]
```

### 2. Deploy to Cloud Run
Run the following command in the `backend_go` directory:
```bash
gcloud run deploy safeshell-backend --source . --platform managed --allow-unauthenticated --region us-central1
```

### 3. Set Firebase Credentials Secrets
For security, do NOT upload the JSON file. Instead, set the environment variable in Cloud Run:
```bash
# Get the content of your JSON file and set it
gcloud run services update safeshell-backend --set-env-vars="FIREBASE_SERVICE_ACCOUNT_JSON=$(cat firebase-credentials.json)"
```

### 4. Update Mobile App
Once deployed, Cloud Run will give you a public URL (e.g., `https://safeshell-backend-xyz.a.run.app`). 
Update `lib/core/constants.dart` in the Flutter app with this new URL.
