# Admin guide

## Akceptacja kont

Panel admina -> Użytkownicy -> Akceptuj. Konto zmienia `accountStatus` na `active`.

## Role

Admin może nadać rolę `moderator` lub `admin`. Moderator może moderować wiadomości, ale nie zarządza globalną konfiguracją ani adminami.

## Jednostki

Panel admina -> Jednostki pozwala tworzyć i dezaktywować jednostki. Użytkownik ma przypisane `unitId`, `unitName` i `unitType`.

## Moderacja

Przytrzymanie wiadomości otwiera menu: odpowiedź, reakcja, przypięcie, usunięcie, zgłoszenie.

## Administratorzy startowi

Loginy `badura_admin` i `robak_admin` są zarezerwowane. Przy pierwszym logowaniu aplikacja tworzy konto Firebase Auth z hasłem wpisanym przez użytkownika i zapisuje profil `admin/active`. Każdy z tych loginów można aktywować tylko raz.

## Bezpieczeństwo

Reguły Firestore ograniczają dostęp do aktywnych kont, roli admin/moderator, członków jednostek i uczestników prywatnych rozmów.
