# Firebase setup

1. Utwórz projekt Firebase, np. `tarnobrzeg-112`.
2. Dodaj aplikację Android z pakietem `pl.tarnobrzeg112.app`.
3. Pobierz `google-services.json` i umieść go w `android/app/google-services.json`.
4. Dodaj aplikację iOS z bundle id `pl.tarnobrzeg112.app` i pobierz `GoogleService-Info.plist`.
5. Uruchom FlutterFire CLI lub ręcznie podmień wartości w `lib/firebase/firebase_options.dart`.
6. Włącz Firebase Auth z metodą Email/Password.
7. Utwórz Cloud Firestore w trybie production.
8. Utwórz Firebase Storage.
9. Wgraj reguły:

```powershell
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Administratorzy startowi

1. Na ekranie logowania wpisz `badura_admin` i docelowe hasło. Jeżeli konto nie istnieje, aplikacja utworzy Firebase Auth, profil `admin/active` i zapisze `app_settings/adminBootstrap_badura_admin`.
2. Tak samo działa drugi admin `robak_admin`, zapisując `app_settings/adminBootstrap_robak_admin`.
3. Hasło nie jest zapisane w kodzie. Pierwsze hasło jest zawsze tym, które użytkownik poda przy pierwszym logowaniu.
4. Po aktywacji admin loguje się już normalnie loginem i hasłem.

## Kody zaproszeń

Przykładowy dokument w `invite_codes/TEST112`:

```json
{
  "code": "TEST112",
  "serviceType": "osp",
  "unitName": "OSP Gorzyce",
  "active": true,
  "maxUses": 20,
  "usedCount": 0,
  "createdBy": "badura_admin",
  "createdAt": "serverTimestamp"
}
```

Zwykły użytkownik musi podać aktywny kod zaproszenia.

## Kolekcje

Projekt używa kolekcji: `users`, `units`, `global_chat`, `unit_chats`, `private_chats`, `notifications`, `reports`, `moderation_logs`, `pinned_messages`, `app_settings`, `invite_codes`.
