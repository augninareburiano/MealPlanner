# Setup checklist (things only you can do)

This project's source was scaffolded without a local Flutter install, so the
platform files and Firebase config still need to be generated on your machine.
Do these once, in order.

## 1. Install tooling (if not already installed)

- Flutter SDK (includes Dart): https://docs.flutter.dev/get-started/install
- Confirm with:
  ```
  flutter doctor
  ```

## 2. Generate the Android platform files

The `android/` folder (and the Gradle wrapper) isn't in the repo yet. From the
repo root, run:

```
flutter create . --project-name foodgapp --org com.example --platforms android
```

This backfills `android/`, `.metadata`, etc. It should leave the existing
`lib/` and `pubspec.yaml` alone — but if `git status` shows either was changed,
restore them (they are the source of truth):

```
git checkout -- lib/main.dart pubspec.yaml
```

Then resolve packages:

```
flutter pub get
```

## 3. Firebase (console — needs your account + a browser)

1. Go to https://console.firebase.google.com and **create a project** (e.g.
   "FoodGApp").
2. In **Build → Authentication → Sign-in method**, enable **Email/Password**.
3. Install the CLIs and log in:
   ```
   dart pub global activate flutterfire_cli
   npm install -g firebase-tools    # or see https://firebase.google.com/docs/cli
   firebase login
   ```
4. From the repo root, run:
   ```
   flutterfire configure
   ```
   Select your Firebase project and the **Android** platform. This creates
   `lib/firebase_options.dart` and `android/app/google-services.json`.
   - `firebase_options.dart` and `google-services.json` are **gitignored** on
     purpose — do not commit them.
   - Optional: switch `main.dart`'s `Firebase.initializeApp()` to
     `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

## 4. Run the app

```
flutter run
```

on your emulator or a connected Android device. Verify:
- Register a new account → you land on Home.
- Sign out → back to Login.
- Log in again → Home.

## 5. Later (not built yet)

- Add your Spoonacular key: copy `lib/config/api_config.example.dart` to
  `lib/config/api_config.dart` and fill in `spoonacularApiKey`. That file is
  gitignored, so the key never gets committed.
