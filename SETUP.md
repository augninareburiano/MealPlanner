# Setup guide (fresh clone / handover)

Follow these once on a new machine to get FoodGApp building and running. The
`android/` platform files are already in the repo, so there is **no** need to
run `flutter create`.

The only things not in the repo are the **Firebase config files** (they hold
project keys and are intentionally gitignored) — you regenerate them in step 3.

## 1. Install tooling

- **Flutter SDK** (includes Dart): https://docs.flutter.dev/get-started/install
- **Android SDK** — either install **Android Studio** (easiest; bundles the SDK,
  a JDK, and an emulator manager), or the **command-line tools** plus a JDK 17.
- To run the app you need an **Android emulator** or a **physical Android device**
  with USB debugging enabled.
- Confirm the toolchain is healthy (you want a green *Flutter* and
  *Android toolchain*; Chrome/Visual Studio lines don't matter — this is
  Android-only):
  ```
  flutter doctor
  ```

## 2. Get packages

From the repo root:
```
flutter pub get
```

## 3. Firebase (needs a Google account + a browser)

1. In the [Firebase console](https://console.firebase.google.com), open the
   project (or **create** one, e.g. "FoodGApp").
2. In **Build → Authentication → Sign-in method**, enable **Email/Password**.
3. Install the CLIs and sign in:
   ```
   dart pub global activate flutterfire_cli
   npm install -g firebase-tools        # or see https://firebase.google.com/docs/cli
   firebase login
   ```
4. From the repo root, generate the config for this project:
   ```
   flutterfire configure
   ```
   Select the Firebase project and the **Android** platform. This creates
   `lib/firebase_options.dart` and `android/app/google-services.json`.
   - Both files are **gitignored on purpose — never commit them.**
   - No code change is needed: `lib/main.dart` already initializes Firebase with
     `DefaultFirebaseOptions.currentPlatform`.

## 4. Run the app

Start an emulator (or plug in a device), then:
```
flutter run
```
Verify the core flow:
- **Register** a new account → you land on **Home**.
- **Sign out** → back to **Login**.
- **Log in** again → **Home**.

## 5. Spoonacular API key

Recipe search and the nutrition facts lookup get their nutritional values from
Spoonacular, so the app needs a key to show them. Without one it still runs:
recipe search falls back to TheMealDB, which finds dishes by name but carries
no nutrition, and the facts screen says so up front rather than showing blanks.

1. Get a free key at https://spoonacular.com/food-api (the free tier is enough
   for development).
2. Copy `lib/config/api_config.example.dart` to `lib/config/api_config.dart`
   and fill in `spoonacularApiKey`. That file is gitignored, so the key is
   never committed.

## 6. Building a release APK

`flutter build apk --release` produces
`build/app/outputs/flutter-apk/app-release.apk`.

Release builds are signed with the project keystore, which is **not** in the
repo. Without it the build still succeeds, falling back to a debug key — fine
for testing, but an APK signed with a different key **cannot be installed as an
update** over an existing install; the user has to uninstall first, losing
their local data. To sign as the same app, place the keystore somewhere private
and create `android/key.properties` (gitignored, and it must be saved **without
a UTF-8 BOM** or Gradle fails to read it):

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=foodgapp
storeFile=C:/path/to/foodgapp-release.jks
```

Confirm which key an APK carries with:

```
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```
