import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/notification_model.dart';
import 'package:uuid/uuid.dart';

class NotificationsRepository {
  NotificationsRepository(this._firestore);

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  Stream<List<NotificationModel>> watchForUser(String uid) {
    return _notifications
        .where('recipientId', whereIn: [uid, 'all'])
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs.map(NotificationModel.fromSnapshot).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Future<void> create({
    required String recipientId,
    required String title,
    required String body,
    required NotificationKind type,
    Map<String, String> data = const {},
  }) {
    final id = _uuid.v4();
    final notification = NotificationModel(
      id: id,
      recipientId: recipientId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      data: data,
    );
    return _notifications.doc(id).set(notification.toMap());
  }

  Future<void> createBroadcast({
    required AppUser actor,
    required String title,
    required String body,
    bool pinned = true,
    Map<String, String> data = const {},
  }) {
    final id = _uuid.v4();
    final notification = NotificationModel(
      id: id,
      recipientId: 'all',
      title: title,
      body: body,
      type: NotificationKind.adminAnnouncement,
      createdAt: DateTime.now(),
      data: {...data, 'pinned': pinned.toString(), 'createdBy': actor.uid},
    );
    return _notifications.doc(id).set({
      ...notification.toMap(),
      'pinned': pinned,
      'createdBy': actor.uid,
      'createdByLogin': actor.login,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBroadcast({
    required NotificationModel notification,
    required AppUser actor,
    required String title,
    required String body,
  }) async {
    await _ensureCanManage(notification, actor);
    await _notifications.doc(notification.id).set({
      'title': title.trim(),
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor.uid,
      'updatedByLogin': actor.login,
    }, SetOptions(merge: true));
  }

  Future<void> deleteBroadcast({
    required NotificationModel notification,
    required AppUser actor,
  }) async {
    await _ensureCanManage(notification, actor);
    await _notifications.doc(notification.id).delete();
  }

  Future<void> markRead(String id) {
    return _notifications.doc(id).update({'read': true});
  }

  Future<void> _ensureCanManage(
    NotificationModel notification,
    AppUser actor,
  ) async {
    if (actor.isAdmin) return;
    final ownerId = notification.data['createdBy'];
    if (ownerId != null && ownerId == actor.uid) return;
    final doc = await _notifications.doc(notification.id).get();
    final createdBy = doc.data()?['createdBy']?.toString();
    if (createdBy == actor.uid) return;
    throw StateError('Nie masz uprawnień do tego komunikatu.');
  }
}
