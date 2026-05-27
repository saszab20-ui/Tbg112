import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class TypingUser {
  const TypingUser({
    required this.uid,
    required this.displayName,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final DateTime updatedAt;

  static TypingUser fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final timestamp = data['updatedAt'];
    return TypingUser(
      uid: (data['uid'] as String?) ?? snapshot.id,
      displayName: TextUtils.repairPolishText(
        (data['displayName'] as String?) ?? 'Ktoś',
      ),
      updatedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
