# FoodGApp

An Android meal-planning and nutrition app (school capstone). A user sets up a
profile, logs meals, gets recipe suggestions from a nutrition API, and sees
feedback comparing their intake to the Philippine **DOST-FNRI** nutrition
targets.

## Fixed technical decisions

- **Framework:** Flutter (Dart), **Android only**.
- **Login/accounts:** Firebase Authentication (Email/Password) — used **only**
  for login. No other data is stored in Firebase.
- **All app data:** stored on the phone with **SQLite (`sqflite`)**. Data does
  **not** sync across devices — this is intentional.
- **Recipe/nutrition data (later):** Spoonacular (primary) + TheMealDB (free
  backup), with local caching. Not built yet.
- **Meal-plan logic (later):** simple rule-based code, no machine learning.

## Project structure

```
lib/
  main.dart                App start; AuthGate shows Login (logged out) or Home (logged in).
  config/
    api_config.example.dart Template for API keys (committed).
    api_config.dart         Real keys (GITIGNORED, empty for now).
  models/
    user_profile.dart
    meal_log.dart
    saved_meal.dart
  screens/
    login_screen.dart
    register_screen.dart
    home_screen.dart        Placeholder with a working Sign Out.
  services/
    auth_service.dart       Wraps Firebase login; maps error codes to plain messages.
    database_helper.dart    SQLite setup + save/read methods.
```

### SQLite tables

- `user_profile` — `user_id` (TEXT PK, the Firebase user id), name, email,
  contact_number, age, gender, height_cm, weight_kg, activity_level,
  dietary_preferences, health_goal
- `meal_log` — id (auto), user_id (FK), meal_date (`yyyy-MM-dd`), meal_type
  (breakfast/lunch/dinner/snack), food_name, serving_size, calories, protein,
  carbs, fat, api_meal_id
- `saved_meals` — id (auto), user_id (FK), api_meal_id, meal_name, image_url
- `nutrition_cache` — api_meal_id (PK), meal_name, calories, protein, carbs,
  fat, raw_json, cached_at

Foreign keys are enabled (`PRAGMA foreign_keys = ON`); `meal_log` and
`saved_meals` reference `user_profile(user_id)`.

## Current status

The foundation is complete and runs on an Android emulator/device:

- ✅ Login, Register, and a placeholder Home screen (with Sign out)
- ✅ Firebase Email/Password auth wired up and working
- ✅ Local SQLite database with all four tables created
- ⛔ Not built yet: profile setup form, meal logging, DOST-FNRI feedback, and
  the Spoonacular/TheMealDB recipe features

## Getting started

The `android/` platform files are committed, so setup is short: install Flutter
+ the Android SDK, run `flutter pub get`, then generate the Firebase config with
`flutterfire configure`. **Full steps: [SETUP.md](SETUP.md).**

Once set up, day-to-day you just run:
```
flutter run
```
and use hot reload (save a file to see changes live on the device).
