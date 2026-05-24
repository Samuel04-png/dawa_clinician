import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MotherRecord extends FirestoreRecord {
  MotherRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "dateOfBirth" field.
  DateTime? _dateOfBirth;
  DateTime? get dateOfBirth => _dateOfBirth;
  bool hasDateOfBirth() => _dateOfBirth != null;

  // "occupation" field.
  String? _occupation;
  String get occupation => _occupation ?? '';
  bool hasOccupation() => _occupation != null;

  // "address" field.
  String? _address;
  String get address => _address ?? '';
  bool hasAddress() => _address != null;

  // "user_Id" field.
  DocumentReference? _userId;
  DocumentReference? get userId => _userId;
  bool hasUserId() => _userId != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "mother_id" field.
  String? _motherId;
  String get motherId => _motherId ?? '';
  bool hasMotherId() => _motherId != null;

  // "first_encounter_id" field.
  DocumentReference? _firstEncounterId;
  DocumentReference? get firstEncounterId => _firstEncounterId;
  bool hasFirstEncounterId() => _firstEncounterId != null;

  void _initializeFields() {
    _dateOfBirth = snapshotData['dateOfBirth'] as DateTime?;
    _occupation = snapshotData['occupation'] as String?;
    _address = snapshotData['address'] as String?;
    _userId = snapshotData['user_Id'] as DocumentReference?;
    _name = snapshotData['name'] as String?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _motherId = snapshotData['mother_id'] as String?;
    _firstEncounterId =
        snapshotData['first_encounter_id'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('mother');

  static Stream<MotherRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MotherRecord.fromSnapshot(s));

  static Future<MotherRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MotherRecord.fromSnapshot(s));

  static MotherRecord fromSnapshot(DocumentSnapshot snapshot) => MotherRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MotherRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MotherRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MotherRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MotherRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMotherRecordData({
  DateTime? dateOfBirth,
  String? occupation,
  String? address,
  DocumentReference? userId,
  String? name,
  String? phoneNumber,
  String? motherId,
  DocumentReference? firstEncounterId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'dateOfBirth': dateOfBirth,
      'occupation': occupation,
      'address': address,
      'user_Id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'mother_id': motherId,
      'first_encounter_id': firstEncounterId,
    }.withoutNulls,
  );

  return firestoreData;
}

class MotherRecordDocumentEquality implements Equality<MotherRecord> {
  const MotherRecordDocumentEquality();

  @override
  bool equals(MotherRecord? e1, MotherRecord? e2) {
    return e1?.dateOfBirth == e2?.dateOfBirth &&
        e1?.occupation == e2?.occupation &&
        e1?.address == e2?.address &&
        e1?.userId == e2?.userId &&
        e1?.name == e2?.name &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.motherId == e2?.motherId &&
        e1?.firstEncounterId == e2?.firstEncounterId;
  }

  @override
  int hash(MotherRecord? e) => const ListEquality().hash([
        e?.dateOfBirth,
        e?.occupation,
        e?.address,
        e?.userId,
        e?.name,
        e?.phoneNumber,
        e?.motherId,
        e?.firstEncounterId
      ]);

  @override
  bool isValidKey(Object? o) => o is MotherRecord;
}
