# Kontynuacja po limicie

## Zrobiono

- Wygenerowano projekt Flutter.
- Dodano zależności Firebase, Riverpod, go_router, FCM, Storage, animacje i media.
- Zaimplementowano modele, repozytoria, providery, routing i ekrany MVP.
- Dodano reguły Firestore i Storage.
- Dodano assety Google Play i dokumentację.
- `flutter pub get`, `flutter analyze`, `flutter test`, APK i AAB przeszły lokalnie.
- Finalizacja Android/Firebase: podłączono `android/app/google-services.json`, zaktualizowano `lib/firebase/firebase_options.dart` dla Androida, podmieniono branding na `assets/images/logo.png`, wygenerowano launcher/adaptive/notification/splash/Google Play assets, dodano bootstrap adminów `badura_admin` i `robak_admin` przy pierwszym logowaniu oraz poprawiono reguły Firestore/Storage.
- Nowy release APK został zbudowany w `build/app/outputs/flutter-apk/app-release.apk`.
- Nowy release AAB został zbudowany w `build/app/outputs/bundle/release/app-release.aab`.

## Jeżeli trzeba wznowić

1. Podłącz prawdziwy projekt Firebase.
2. Zaloguj pierwszy raz `badura_admin` i/lub `robak_admin`; wpisane hasło zostanie ustawione jako hasło konta.
3. Utwórz aktywne dokumenty `invite_codes` dla zwykłych testowych kont.
4. Przetestuj aplikację na fizycznym Androidzie.
5. Skonfiguruj docelowy upload key przed produkcją.

## Prompt po wznowieniu

Kontynuuj projekt Tarnobrzeg 112 w folderze `C:\Users\badur\Desktop\Tbg112`. Nie zaczynaj od zera. Sprawdź `CONTINUE_AFTER_LIMIT.md`, uruchom `flutter analyze`, `flutter test`, `flutter build apk --release` i napraw błędy.
