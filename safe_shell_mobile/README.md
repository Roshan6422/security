# SafeShell Mobile (Flutter)

This is the new Flutter version of the SafeShell application.

## Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
- Valid Backend running at `http://localhost:5000`.

## Getting Started

1. Navigate to the project directory:
   ```bash
   cd d:\SafeShell\safe_shell_mobile
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   - For Android Emulator:
     ```bash
     flutter run
     # OR if C: drive is full:
     .\run_android.bat
     ```
   - For Physical Device:
     Ensure your phone is connected via USB and USB Debugging is enabled.
     Update `lib/core/constants.dart` with your computer's IP address instead of `10.0.2.2`.

## Project Structure
- `lib/main.dart`: Entry point.
- `lib/providers/`: State management (Auth).
- `lib/screens/`: UI Screens (Login, Register, Dashboard, Vault).
- `lib/services/`: API integration.
- `lib/models/`: Data models.
