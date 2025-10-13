dart run easy_localization:generate --source-dir assets/translations/ -f keys -o locale_keys.g.dart
dart run easy_localization:generate --source-dir assets/translations/
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
#/Users/glebklimov/Library/Android/sdk/platform-tools/adb reverse tcp:8080 tcp:8080