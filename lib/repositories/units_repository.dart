import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/unit_model.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class UnitsRepository {
  UnitsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _units =>
      _firestore.collection(FirestoreCollections.units);

  Stream<List<UnitModel>> watchUnits() {
    return _units
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UnitModel.fromSnapshot).toList());
  }

  Stream<UnitModel?> watchUnit(String unitId) {
    return _units.doc(unitId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UnitModel.fromSnapshot(doc);
    });
  }

  Future<void> createOrUpdate({
    required String name,
    required UnitType type,
    required String voivodeship,
    required String county,
    String description = '',
  }) {
    final id = TextUtils.normalizeId(name);
    return _units.doc(id).set({
      'id': id,
      'name': name.trim(),
      'type': type.name,
      'voivodeship': voivodeship.trim(),
      'county': county.trim(),
      'description': description.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setActive(String unitId, bool active) {
    return _units.doc(unitId).update({'active': active});
  }
}
