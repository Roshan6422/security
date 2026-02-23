# SafeShell Project Stack

SafeShell is a multi-component security application consisting of a Flutter mobile app, a Dart-based backend, and a React-based admin dashboard.

## Project Structure

- `safe_shell_mobile/`: Flutter mobile application for Android and iOS.
- `backend_dart/`: Dart (Shelf) backend server providing APIs.
- `admin/`: React + Vite admin dashboard for managing users and system data.

## Getting Started

### 1. Backend Setup (`backend_dart`)
1.  Navigate to the directory: `cd backend_dart`
2.  Install dependencies: `dart pub get`
3.  Create a `.env` file based on `.env.example` and fill in your secrets.
4.  Run the server: `dart run bin/server.dart` (Default port: 8000)

### 2. Admin Dashboard Setup (`admin`)
1.  Navigate to the directory: `cd admin`
2.  Install dependencies: `npm install`
3.  Create a `.env` file based on `.env.example`.
4.  Run in development mode: `npm run dev` (Default port: 5173)

### 3. Mobile App Setup (`safe_shell_mobile`)
1.  Navigate to the directory: `cd safe_shell_mobile`
2.  Install dependencies: `flutter pub get`
3.  Config settings: Update `lib/core/constants.dart` with your local IP if running on a physical device.
4.  Run the app: `flutter run`

## Prerequisites
- **Flutter SDK**: Required for the mobile app.
- **Dart SDK**: Required for the backend.
- **Node.js & npm**: Required for the admin dashboard.

## Key Features
- **App Lock**: Universal application protection.
- **Secure Vault**: Encrypted file storage (AES-GCM).
- **Calculator Disguise**: Stealth mode with icon swapping.
- **Admin Dashboard**: Real-time analytics and user management.

---
Created with ❤️ by the SafeShell Team.
