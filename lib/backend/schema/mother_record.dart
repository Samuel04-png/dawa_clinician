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

  // "nrc" field.
  String? _nrc;
  String get nrc => _nrc ?? '';
  bool hasNrc() => _nrc != null;

  // "village" field.
  String? _village;
  String get village => _village ?? '';
  bool hasVillage() => _village != null;

  // "clinic_name" field.
  String? _clinicName;
  String get clinicName => _clinicName ?? '';
  bool hasClinicName() => _clinicName != null;

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

  // Patient-provided pregnancy state from the separate Dawa Mom project.
  String? _sourcePregnancyStatus;
  String get sourcePregnancyStatus => _sourcePregnancyStatus ?? '';
  bool hasSourcePregnancyStatus() => _sourcePregnancyStatus != null;

  DateTime? _sourcePregnancyLnmp;
  DateTime? get sourcePregnancyLnmp => _sourcePregnancyLnmp;
  bool hasSourcePregnancyLnmp() => _sourcePregnancyLnmp != null;

  DateTime? _sourcePregnancyEstimatedDueDate;
  DateTime? get sourcePregnancyEstimatedDueDate =>
      _sourcePregnancyEstimatedDueDate;
  bool hasSourcePregnancyEstimatedDueDate() =>
      _sourcePregnancyEstimatedDueDate != null;

  DateTime? _sourcePregnancyUpdatedAt;
  DateTime? get sourcePregnancyUpdatedAt => _sourcePregnancyUpdatedAt;
  bool hasSourcePregnancyUpdatedAt() => _sourcePregnancyUpdatedAt != null;

  String? _sourcePregnancyProvenance;
  String get sourcePregnancyProvenance => _sourcePregnancyProvenance ?? '';
  bool hasSourcePregnancyProvenance() => _sourcePregnancyProvenance != null;

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
    _nrc = snapshotData['nrc'] as String?;
    _village = snapshotData['village'] as String?;
    _clinicName = snapshotData['clinic_name'] as String?;
    _sourceProject = snapshotData['source_project'] as String?;
    _sourceMotherId = snapshotData['source_mother_id'] as String?;
    _sourceUserId = snapshotData['source_user_id'] as String?;
    _registrationSource = snapshotData['registration_source'] as String?;
    _syncedAt = snapshotData['synced_at'] as DateTime?;
    _sourceDeletedAt = snapshotData['source_deleted_at'] as DateTime?;
    _sourcePregnancyStatus = snapshotData['source_pregnancy_status'] as String?;
    _sourcePregnancyLnmp = snapshotData['source_pregnancy_lnmp'] as DateTime?;
    _sourcePregnancyEstimatedDueDate =
        snapshotData['source_pregnancy_estimated_due_date'] as DateTime?;
    _sourcePregnancyUpdatedAt =
        snapshotData['source_pregnancy_updated_at'] as DateTime?;
    _sourcePregnancyProvenance =
        snapshotData['source_pregnancy_provenance'] as String?;
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
  String? nrc,
  String? village,
  String? clinicName,
  String? sourceProject,
  String? sourceMotherId,
  String? sourceUserId,
  String? registrationSource,
  DateTime? syncedAt,
  DateTime? sourceDeletedAt,
  String? sourcePregnancyStatus,
  DateTime? sourcePregnancyLnmp,
  DateTime? sourcePregnancyEstimatedDueDate,
  DateTime? sourcePregnancyUpdatedAt,
  String? sourcePregnancyProvenance,
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
      'nrc': nrc,
      'village': village,
      'clinic_name': clinicName,
      'source_project': sourceProject,
      'source_mother_id': sourceMotherId,
      'source_user_id': sourceUserId,
      'registration_source': registrationSource,
      'synced_at': syncedAt,
      'source_deleted_at': sourceDeletedAt,
      'source_pregnancy_status': sourcePregnancyStatus,
      'source_pregnancy_lnmp': sourcePregnancyLnmp,
      'source_pregnancy_estimated_due_date': sourcePregnancyEstimatedDueDate,
      'source_pregnancy_updated_at': sourcePregnancyUpdatedAt,
      'source_pregnancy_provenance': sourcePregnancyProvenance,
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
        e1?.nrc == e2?.nrc &&
        e1?.village == e2?.village &&
        e1?.clinicName == e2?.clinicName &&
        e1?.sourceProject == e2?.sourceProject &&
        e1?.sourceMotherId == e2?.sourceMotherId &&
        e1?.sourceUserId == e2?.sourceUserId &&
        e1?.registrationSource == e2?.registrationSource &&
        e1?.syncedAt == e2?.syncedAt &&
        e1?.sourceDeletedAt == e2?.sourceDeletedAt &&
        e1?.sourcePregnancyStatus == e2?.sourcePregnancyStatus &&
        e1?.sourcePregnancyLnmp == e2?.sourcePregnancyLnmp &&
        e1?.sourcePregnancyEstimatedDueDate ==
            e2?.sourcePregnancyEstimatedDueDate &&
        e1?.sourcePregnancyUpdatedAt == e2?.sourcePregnancyUpdatedAt &&
        e1?.sourcePregnancyProvenance == e2?.sourcePregnancyProvenance;
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
        e?.nrc,
        e?.village,
        e?.clinicName,
        e?.sourceProject,
        e?.sourceMotherId,
        e?.sourceUserId,
        e?.registrationSource,
        e?.syncedAt,
        e?.sourceDeletedAt,
        e?.sourcePregnancyStatus,
        e?.sourcePregnancyLnmp,
        e?.sourcePregnancyEstimatedDueDate,
        e?.sourcePregnancyUpdatedAt,
        e?.sourcePregnancyProvenance,
      ]);

  @override
  bool isValidKey(Object? o) => o is MotherRecord;
}
