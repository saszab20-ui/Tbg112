import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ErrorUtils {
  const ErrorUtils._();

  static String readable(Object error) {
    debugPrint('APP ERROR: $error');
    final message = error.toString();
    if (message.contains('type ') ||
        message.contains('cast') ||
        message.contains('subtype')) {
      return 'Dane mają niepoprawny format. Spróbuj ponownie.';
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'invalid-credential' ||
          error.code == 'wrong-password' ||
          error.code == 'user-not-found') {
        return 'Nieprawidłowy login lub hasło';
      }
      return 'Operacja logowania nie powiodła się.';
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Brak uprawnień do wykonania tej operacji.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Brak połączenia z Firebase. Spróbuj ponownie.';
      }
      return 'Operacja Firebase nie powiodła się.';
    }
    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  static String chatLoad(Object error) {
    debugPrint('CHAT LOAD ERROR: $error');
    return 'Nie udało się załadować czatu. Spróbuj ponownie.';
  }

  static String chatSend(Object error, {bool image = false}) {
    debugPrint('CHAT SEND ERROR: $error');
    return image
        ? 'Nie udało się wysłać zdjęcia.'
        : 'Nie udało się wysłać wiadomości.';
  }
}
