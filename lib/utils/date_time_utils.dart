import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DateTimeUtils {
  const DateTimeUtils._();

  static DateTime? fromJson(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Object toJson(DateTime? value) {
    if (value == null) return FieldValue.serverTimestamp();
    return Timestamp.fromDate(value);
  }

  static String chatTime(DateTime value) => DateFormat('HH:mm').format(value);

  static String compactDate(DateTime value) =>
      DateFormat('dd.MM.yyyy HH:mm').format(value);
}
