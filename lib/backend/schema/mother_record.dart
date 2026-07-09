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

  // "source_project" field.
  String? _sourceProject;
  String get sourceProject => _sourceProject ?? '';
  bool hasSourceProject() => _sourceProject != null;

  // "source_mother_id" field.
  String? _sourceMotherId;
  String get sourceMotherId => _sourceMotherId ?? '';
  bool hasSourceMotherId() => _sourceMotherId != null;

  // "source_user_id" field.
  String? _sourceUserId;
  String get sourceUserId => _sourceUserId ?? '';
  bool hasSourceUserId() => _sourceUserId != null;

  // "registration_source" field.
  String? _registrationSource;
  String get registrationSource => _registrationSource ?? '';
  bool hasRegistrationSource() => _registrationSource != null;

  // "synced_at" field.
  DateTime? _syncedAt;
  DateTime? get syncedAt => _syncedAt;
  bool hasSyncedAt() => _syncedAt != null;

  // "source_deleted_at" field.
  DateTime? _sourceDeletedAt;
  DateTime? get sourceDeletedAt => _sourceDeletedAt;
  bool hasSourceDeletedAt() => _sourceDeletedAt != null;

  bool get isImportedFromDawaMom =>
      sourceProject == 'dawa_mom' || registrationSource == 'dawa_mom';

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
    _sourceProject = snapshotData['source_project'] as String?;
    _sourceMotherId = snapshotData['source_mother_id'] as String?;
    _sourceUserId = snapshotData['source_user_id'] as String?;
    _registrationSource = snapshotData['registration_source'] as String?;
    _syncedAt = snapshotData['synced_at'] as DateTime?;
    _sourceDeletedAt = snapshotData['source_deleted_at'] as DateTime?;
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
  String? sourceProject,
  String? sourceMotherId,
  String? sourceUserId,
  String? registrationSource,
  DateTime? syncedAt,
  DateTime? sourceDeletedAt,
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
      'source_project': sourceProject,
      'source_mother_id': sourceMotherId,
      'source_user_id': sourceUserId,
      'registration_source': registrationSource,
      'synced_at': syncedAt,
      'source_deleted_at': sourceDeletedAt,
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
        e1?.firstEncounterId == e2?.firstEncounterId &&
        e1?.sourceProject == e2?.sourceProject &&
        e1?.sourceMotherId == e2?.sourceMotherId &&
        e1?.sourceUserId == e2?.sourceUserId &&
        e1?.registrationSource == e2?.registrationSource &&
        e1?.syncedAt == e2?.syncedAt &&
        e1?.sourceDeletedAt == e2?.sourceDeletedAt;
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
        e?.firstEncounterId,
        e?.sourceProject,
        e?.sourceMotherId,
        e?.sourceUserId,
        e?.registrationSource,
        e?.syncedAt,
        e?.sourceDeletedAt
      ]);

  @override
  bool isValidKey(Object? o) => o is MotherRecord;
}
