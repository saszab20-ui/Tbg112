import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/event_model.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class EventsRepository {
  EventsRepository(this._firestore, this._storageService);

  final FirebaseFirestore _firestore;
  final StorageService _storageService;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection(FirestoreCollections.events);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  CollectionReference<Map<String, dynamic>> get _moderationLogs =>
      _firestore.collection(FirestoreCollections.moderationLogs);

  Stream<List<EventModel>> watchEvents({
    int limit = 50,
    bool includeExpired = false,
  }) {
    return _events
        .orderBy('dateTime')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final cutoff = now.subtract(const Duration(hours: 4));
          return snapshot.docs
              .map(EventModel.fromSnapshot)
              .where((event) => includeExpired || event.dateTime.isAfter(cutoff))
              .toList();
        });
  }

  Future<void> createEvent({
    required AppUser organizer,
    required String name,
    required DateTime dateTime,
    required String place,
    required String description,
    required bool notifyUsers,
    XFile? posterFile,
    String posterAsset = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 3) {
      throw StateError('Podaj nazwę wydarzenia.');
    }
    if (place.trim().isEmpty) {
      throw StateError('Podaj miejsce wydarzenia.');
    }

    final id = _uuid.v4();
    var posterUrl = posterAsset.trim();
    if (posterFile != null) {
      posterUrl = await _storageService.uploadEventPoster(
        eventId: id,
        file: posterFile,
      );
    }

    final event = EventModel(
      id: id,
      name: cleanName,
      dateTime: dateTime,
      place: place.trim(),
      description: description.trim(),
      posterUrl: posterUrl,
      organizerId: organizer.uid,
      organizerName: organizer.publicName,
      notifyUsers: notifyUsers,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(_events.doc(id), event.toMap());
    if (notifyUsers) {
      batch.set(_notifications.doc(_uuid.v4()), {
        'recipientId': 'all',
        'title': 'Nowe wydarzenie: $cleanName',
        'body': '${event.place} • ${_dateLabel(event.dateTime)}',
        'type': 'adminAnnouncement',
        'read': false,
        'data': {'eventId': id, 'pinned': 'true'},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateEvent({
    required EventModel event,
    required AppUser actor,
    required String name,
    required DateTime dateTime,
    required String place,
    required String description,
    required bool notifyUsers,
    XFile? posterFile,
  }) async {
    _ensureCanManage(event: event, actor: actor);
    final cleanName = name.trim();
    if (cleanName.length < 3) {
      throw StateError('Podaj nazwę wydarzenia.');
    }
    if (place.trim().isEmpty) {
      throw StateError('Podaj miejsce wydarzenia.');
    }

    var posterUrl = event.posterUrl;
    if (posterFile != null) {
      posterUrl = await _storageService.uploadEventPoster(
        eventId: event.id,
        file: posterFile,
      );
    }

    await _events.doc(event.id).set({
      'name': cleanName,
      'dateTime': Timestamp.fromDate(dateTime),
      'place': place.trim(),
      'description': description.trim(),
      'posterUrl': posterUrl,
      'notifyUsers': notifyUsers,
      'eventOwnerId': event.organizerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _logEventAction(
      action: 'event_updated',
      actor: actor,
      event: event,
      oldValue: {
        'name': event.name,
        'dateTime': Timestamp.fromDate(event.dateTime),
        'place': event.place,
        'description': event.description,
        'posterUrl': event.posterUrl,
        'notifyUsers': event.notifyUsers,
      },
      newValue: {
        'name': cleanName,
        'dateTime': Timestamp.fromDate(dateTime),
        'place': place.trim(),
        'description': description.trim(),
        'posterUrl': posterUrl,
        'notifyUsers': notifyUsers,
      },
    );
  }

  Future<void> deleteEvent({
    required EventModel event,
    required AppUser actor,
  }) async {
    _ensureCanManage(event: event, actor: actor);
    await _events.doc(event.id).delete();
    await _logEventAction(
      action: 'event_deleted',
      actor: actor,
      event: event,
      oldValue: {
        'name': event.name,
        'dateTime': Timestamp.fromDate(event.dateTime),
        'place': event.place,
        'description': event.description,
        'posterUrl': event.posterUrl,
        'notifyUsers': event.notifyUsers,
      },
      newValue: {'deleted': true},
    );
  }

  Future<void> toggleInterested({
    required EventModel event,
    required AppUser user,
  }) {
    final active = event.interestedIds.contains(user.uid);
    return _events.doc(event.id).set({
      'interestedIds': active
          ? FieldValue.arrayRemove([user.uid])
          : FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleAttending({
    required EventModel event,
    required AppUser user,
  }) {
    final active = event.attendeeIds.contains(user.uid);
    return _events.doc(event.id).set({
      'attendeeIds': active
          ? FieldValue.arrayRemove([user.uid])
          : FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _dateLabel(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  void _ensureCanManage({required EventModel event, required AppUser actor}) {
    if (actor.isAdmin ||
        actor.moderatorCan('manageEvents') ||
        event.organizerId == actor.uid) {
      return;
    }
    throw StateError('Nie masz uprawnień do tego wydarzenia.');
  }

  Future<void> _logEventAction({
    required String action,
    required AppUser actor,
    required EventModel event,
    required Map<String, Object?> oldValue,
    required Map<String, Object?> newValue,
  }) async {
    try {
      await _moderationLogs.doc(_uuid.v4()).set({
        'action': action,
        'eventId': event.id,
        'targetUserId': event.organizerId,
        'targetUserLogin': event.organizerName,
        'performedBy': actor.uid,
        'performedByLogin': actor.login,
        'oldValue': oldValue,
        'newValue': newValue,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on Object {
      // Log nie może blokować edycji lub usunięcia wydarzenia.
    }
  }
}
