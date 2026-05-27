import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.name,
    required this.dateTime,
    required this.place,
    required this.description,
    required this.organizerId,
    required this.organizerName,
    required this.createdAt,
    this.posterUrl = '',
    this.interestedIds = const [],
    this.attendeeIds = const [],
    this.notifyUsers = false,
  });

  final String id;
  final String name;
  final DateTime dateTime;
  final String place;
  final String description;
  final String organizerId;
  final String organizerName;
  final DateTime createdAt;
  final String posterUrl;
  final List<String> interestedIds;
  final List<String> attendeeIds;
  final bool notifyUsers;

  bool get hasPoster => posterUrl.trim().isNotEmpty;
  bool get isAssetPoster => posterUrl.startsWith('asset:');
  String get assetPosterPath => posterUrl.replaceFirst('asset:', '');

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'dateTime': Timestamp.fromDate(dateTime),
      'place': place,
      'description': description,
      'posterUrl': posterUrl,
      'organizerId': organizerId,
      'eventOwnerId': organizerId,
      'organizerName': organizerName,
      'interestedIds': interestedIds,
      'attendeeIds': attendeeIds,
      'notifyUsers': notifyUsers,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory EventModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return EventModel.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }

  factory EventModel.fromMap(
    Map<String, Object?> map, {
    String fallbackId = '',
  }) {
    return EventModel(
      id: _string(map['id'], fallback: fallbackId),
      name: _text(map['name']),
      dateTime: DateTimeUtils.fromJson(map['dateTime']) ?? DateTime.now(),
      place: _text(map['place']),
      description: _text(map['description']),
      posterUrl: _string(map['posterUrl']),
      organizerId: _string(
        map['organizerId'],
        fallback: _string(map['eventOwnerId']),
      ),
      organizerName: _text(map['organizerName']),
      interestedIds: _stringList(map['interestedIds']),
      attendeeIds: _stringList(map['attendeeIds']),
      notifyUsers: _bool(map['notifyUsers']),
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String _text(Object? value, {String fallback = ''}) {
  return TextUtils.repairPolishText(_string(value, fallback: fallback));
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}
