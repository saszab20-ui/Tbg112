# Tarnobrzeg 112

Prywatny komunikator informacyjny dla społeczności Tarnobrzeg 112, strażaków, ratowników, moderatorów i administratorów.

Ta aplikacja nie jest oficjalnym systemem alarmowym 112 i nie zastępuje numeru alarmowego 112.

## Funkcje MVP

- Firebase Auth: login/hasło, rejestracja, reset hasła, sesja trwała.
- Status konta: pending, active, rejected, banned, suspended.
- Role: user, moderator, admin.
- Firestore realtime: czat główny, kanały jednostek, rozmowy prywatne.
- Załączniki: zdjęcia i pliki przez Firebase Storage.
- Moderacja: usuwanie, przypinanie, raporty, logi, mute i block write w modelu danych.
- Kody zaproszeń w kolekcji `invite_codes`.
- Bootstrap adminów: pierwsze logowanie `badura_admin` i `robak_admin` ustawia hasło podane przez użytkownika i tworzy konto admin/active tylko raz.
- FCM i lokalne powiadomienia.
- Premium ciemny UI z Riverpod i go_router.
- Przygotowanie pod Android teraz oraz iOS/Web/Desktop później.

## Start lokalny

```powershell
flutter pub get
flutter run
```

Przed logowaniem podmień konfigurację Firebase w `lib/firebase/firebase_options.dart` oraz dodaj natywne pliki Firebase według `SETUP_FIREBASE.md`.

Użytkownik podaje login, a aplikacja tworzy w tle techniczny adres Firebase Auth: `login@tarnobrzeg112.local`. Ten adres nie jest pokazywany w UI.

## Najważniejsze foldery

- `lib/models` - modele Firestore.
- `lib/repositories` - dostęp do Firebase.
- `lib/providers` - Riverpod.
- `lib/screens` - ekrany aplikacji.
- `lib/widgets` - wspólne elementy UI.
- `firestore.rules` i `storage.rules` - reguły bezpieczeństwa.
- `play_store_assets` - grafiki i teksty do Google Play.

## Logo

Docelowe logo aplikacji jest w `assets/images/logo.png`. Ten sam znak zasila launcher icon, adaptive icon, splash screen, ekran logowania, ekran rejestracji, panel użytkownika oraz grafiki Google Play.
