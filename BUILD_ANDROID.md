# Android build

Pakiet: `pl.tarnobrzeg112.app`

Wersja: `1.0.0+1`

Android: `compileSdk 36`, `targetSdk 36`, `minSdk 23`.

## Komendy

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## Wyniki

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

Release build jest podpisywany lokalnym upload keystore:

- `android/app/upload-keystore.jks`
- `android/key.properties`

Ten klucz nadaje sie do testow wewnetrznych. Przed produkcja zabezpiecz go w menedzerze sekretow albo wygeneruj docelowy upload key i zaktualizuj `android/key.properties`.
