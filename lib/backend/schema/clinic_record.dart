import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ClinicRecord extends FirestoreRecord {
  ClinicRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "address" field.
  String? _address;
  String get address => _address ?? '';
  bool hasAddress() => _address != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _address = snapshotData['address'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('clinic');

  static Stream<ClinicRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ClinicRecord.fromSnapshot(s));

  static Future<ClinicRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ClinicRecord.fromSnapshot(s));

  static ClinicRecord fromSnapshot(DocumentSnapshot snapshot) => ClinicRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ClinicRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ClinicRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ClinicRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ClinicRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createClinicRecordData({
  String? name,
  String? address,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'address': address,
    }.withoutNulls,
  );

  return firestoreData;
}

class ClinicRecordDocumentEquality implements Equality<ClinicRecord> {
  const ClinicRecordDocumentEquality();

  @override
  bool equals(ClinicRecord? e1, ClinicRecord? e2) {
    return e1?.name == e2?.name && e1?.address == e2?.address;
  }

  @override
  int hash(ClinicRecord? e) => const ListEquality().hash([e?.name, e?.address]);

  @override
  bool isValidKey(Object? o) => o is ClinicRecord;
}
