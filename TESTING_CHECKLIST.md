# Manual testing checklist

- Splash i onboarding uruchamiają się bez błędu.
- Rejestracja loginem zwykłego użytkownika tworzy `users/{uid}` ze statusem `pending`.
- Pierwsze logowanie `badura_admin` tworzy admina tylko wtedy, gdy nie istnieje `app_settings/adminBootstrap_badura_admin`.
- Pierwsze logowanie `robak_admin` tworzy admina tylko wtedy, gdy nie istnieje `app_settings/adminBootstrap_robak_admin`.
- Rejestracja zwykłego użytkownika wymaga aktywnego dokumentu w `invite_codes`.
- Pending user nie widzi czatów.
- Admin aktywuje użytkownika.
- Active user widzi pulpit, czat główny, kanał jednostki, prywatne rozmowy i profil.
- Wiadomość tekstowa pojawia się realtime.
- Zdjęcie trafia do Firebase Storage.
- Reakcje emoji zapisują się w Firestore.
- Przypinanie i usuwanie działa dla moderatora/admina.
- Private chat jest widoczny tylko dla uczestników.
- Raport pojawia się w panelu admina.
- FCM token zapisuje się w profilu użytkownika.
