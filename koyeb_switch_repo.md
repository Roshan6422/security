# Update Koyeb Repository Settings

Since we are switching to the `security` repository, you need to update Koyeb to pull code from there.

## Steps

1.  **Log in to Koyeb** and open your App/Service.
2.  Go to the **Settings** tab.
3.  Find the **Git** or **Source** section.
4.  Click **Edit** or **Change Repository**.
5.  **Run with these settings:**
    *   **Repository**: `Roshan6422/security`
    *   **Branch**: `main`
    *   **Work Directory** / **Build Command location**: `backend_dart`
        *(Important: You must specify this folder so it knows where the Dockefile is)*
    *   **Builder**: Dockerfile

## Environment Variables

Double check that your Environment Variables are still there:
*   `FIREBASE_SERVICE_ACCOUNT_BASE64`: (The long key)
*   `PORT`: `8000`

## Deploy

Click **Deploy** or **Save**. Koyeb will now pull the code (with my fixes) from the new repository and build it.
