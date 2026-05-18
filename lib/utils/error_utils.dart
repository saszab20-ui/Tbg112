import 'package:firebase_auth/firebase_auth.dart';

class ErrorUtils {
  const ErrorUtils._();

  static String readable(Object error) {
    if (error is FirebaseAuthException) {
      return '[firebase_auth/${error.code}] '
          '${error.message ?? 'Operacja logowania nie powiodła się.'}';
    }
    if (error is FirebaseException) {
      final message = error.message?.trim();
      return '[${error.plugin}/${error.code}] '
          '${message == null || message.isEmpty ? 'Operacja Firebase nie powiodła się.' : message}';
    }
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }
}
