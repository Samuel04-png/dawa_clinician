import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DoctorRecord extends FirestoreRecord {
  DoctorRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "speciality" field.
  String? _speciality;
  String get speciality => _speciality ?? '';
  bool hasSpeciality() => _speciality != null;

  // "user_Id" field.
  DocumentReference? _userId;
  DocumentReference? get userId => _userId;
  bool hasUserId() => _userId != null;

  // "clinic_name" field.
  String? _clinicName;
  String get clinicName => _clinicName ?? '';
  bool hasClinicName() => _clinicName != null;

  // "clinic_id" field.
  String? _clinicId;
  String get clinicId => _clinicId ?? '';
  bool hasClinicId() => _clinicId != null;

  // "start_time" field.
  String? _startTime;
  String get startTime => _startTime ?? '';
  bool hasStartTime() => _startTime != null;

  // "end_time" field.
  String? _endTime;
  String get endTime => _endTime ?? '';
  bool hasEndTime() => _endTime != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "doctor_id" field.
  String? _doctorId;
  String get doctorId => _doctorId ?? '';
  bool hasDoctorId() => _doctorId != null;

  void _initializeFields() {
    _speciality = snapshotData['speciality'] as String?;
    _userId = snapshotData['user_Id'] as DocumentReference?;
    _clinicName = snapshotData['clinic_name'] as String?;
    _clinicId = snapshotData['clinic_id'] as String?;
    _startTime = snapshotData['start_time'] as String?;
    _endTime = snapshotData['end_time'] as String?;
    _name = snapshotData['name'] as String?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _doctorId = snapshotData['doctor_id'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('doctor');

  static Stream<DoctorRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => DoctorRecord.fromSnapshot(s));

  static Future<DoctorRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => DoctorRecord.fromSnapshot(s));

  static DoctorRecord fromSnapshot(DocumentSnapshot snapshot) => DoctorRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static DoctorRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      DoctorRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'DoctorRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is DoctorRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createDoctorRecordData({
  String? speciality,
  DocumentReference? userId,
  String? clinicName,
  String? clinicId,
  String? startTime,
  String? endTime,
  String? name,
  String? phoneNumber,
  String? doctorId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'speciality': speciality,
      'user_Id': userId,
      'clinic_name': clinicName,
      'clinic_id': clinicId,
      'start_time': startTime,
      'end_time': endTime,
      'name': name,
      'phone_number': phoneNumber,
      'doctor_id': doctorId,
    }.withoutNulls,
  );

  return firestoreData;
}

class DoctorRecordDocumentEquality implements Equality<DoctorRecord> {
  const DoctorRecordDocumentEquality();

  @override
  bool equals(DoctorRecord? e1, DoctorRecord? e2) {
    return e1?.speciality == e2?.speciality &&
        e1?.userId == e2?.userId &&
        e1?.clinicName == e2?.clinicName &&
        e1?.clinicId == e2?.clinicId &&
        e1?.startTime == e2?.startTime &&
        e1?.endTime == e2?.endTime &&
        e1?.name == e2?.name &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.doctorId == e2?.doctorId;
  }

  @override
  int hash(DoctorRecord? e) => const ListEquality().hash([
        e?.speciality,
        e?.userId,
        e?.clinicName,
        e?.clinicId,
        e?.startTime,
        e?.endTime,
        e?.name,
        e?.phoneNumber,
        e?.doctorId
      ]);

  @override
  bool isValidKey(Object? o) => o is DoctorRecord;
}
