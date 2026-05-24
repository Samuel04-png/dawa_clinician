import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ParityRecord extends FirestoreRecord {
  ParityRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "weight" field.
  String? _weight;
  String get weight => _weight ?? '';
  bool hasWeight() => _weight != null;

  // "state" field.
  String? _state;
  String get state => _state ?? '';
  bool hasState() => _state != null;

  // "mode_of_delivery" field.
  String? _modeOfDelivery;
  String get modeOfDelivery => _modeOfDelivery ?? '';
  bool hasModeOfDelivery() => _modeOfDelivery != null;

  // "complications" field.
  List<String>? _complications;
  List<String> get complications => _complications ?? const [];
  bool hasComplications() => _complications != null;

  // "first_encounter_id" field.
  DocumentReference? _firstEncounterId;
  DocumentReference? get firstEncounterId => _firstEncounterId;
  bool hasFirstEncounterId() => _firstEncounterId != null;

  // "year_of_birth" field.
  String? _yearOfBirth;
  String get yearOfBirth => _yearOfBirth ?? '';
  bool hasYearOfBirth() => _yearOfBirth != null;

  // "marital_status" field.
  String? _maritalStatus;
  String get maritalStatus => _maritalStatus ?? '';
  bool hasMaritalStatus() => _maritalStatus != null;

  // "mothers_height" field.
  String? _mothersHeight;
  String get mothersHeight => _mothersHeight ?? '';
  bool hasMothersHeight() => _mothersHeight != null;

  // "prepregnancy_weight" field.
  String? _prepregnancyWeight;
  String get prepregnancyWeight => _prepregnancyWeight ?? '';
  bool hasPrepregnancyWeight() => _prepregnancyWeight != null;

  // "mothers_education" field.
  String? _mothersEducation;
  String get mothersEducation => _mothersEducation ?? '';
  bool hasMothersEducation() => _mothersEducation != null;

  // "fathers_age" field.
  String? _fathersAge;
  String get fathersAge => _fathersAge ?? '';
  bool hasFathersAge() => _fathersAge != null;

  // "fathers_education" field.
  String? _fathersEducation;
  String get fathersEducation => _fathersEducation ?? '';
  bool hasFathersEducation() => _fathersEducation != null;

  // "kids_alive" field.
  int? _kidsAlive;
  int get kidsAlive => _kidsAlive ?? 0;
  bool hasKidsAlive() => _kidsAlive != null;

  // "kids_dead" field.
  int? _kidsDead;
  int get kidsDead => _kidsDead ?? 0;
  bool hasKidsDead() => _kidsDead != null;

  // "miscarriages" field.
  int? _miscarriages;
  int get miscarriages => _miscarriages ?? 0;
  bool hasMiscarriages() => _miscarriages != null;

  // "birth_number" field.
  int? _birthNumber;
  int get birthNumber => _birthNumber ?? 0;
  bool hasBirthNumber() => _birthNumber != null;

  // "prenatal_care_start" field.
  int? _prenatalCareStart;
  int get prenatalCareStart => _prenatalCareStart ?? 0;
  bool hasPrenatalCareStart() => _prenatalCareStart != null;

  // "expected_prenatal_visits" field.
  int? _expectedPrenatalVisits;
  int get expectedPrenatalVisits => _expectedPrenatalVisits ?? 0;
  bool hasExpectedPrenatalVisits() => _expectedPrenatalVisits != null;

  // "cigarettes_before_pregnancy" field.
  int? _cigarettesBeforePregnancy;
  int get cigarettesBeforePregnancy => _cigarettesBeforePregnancy ?? 0;
  bool hasCigarettesBeforePregnancy() => _cigarettesBeforePregnancy != null;

  // "cigarettes_during_1st_trim" field.
  int? _cigarettesDuring1stTrim;
  int get cigarettesDuring1stTrim => _cigarettesDuring1stTrim ?? 0;
  bool hasCigarettesDuring1stTrim() => _cigarettesDuring1stTrim != null;

  // "cigarettes_during_2nd_trim" field.
  int? _cigarettesDuring2ndTrim;
  int get cigarettesDuring2ndTrim => _cigarettesDuring2ndTrim ?? 0;
  bool hasCigarettesDuring2ndTrim() => _cigarettesDuring2ndTrim != null;

  // "cigarettes_during_3rd_trim" field.
  int? _cigarettesDuring3rdTrim;
  int get cigarettesDuring3rdTrim => _cigarettesDuring3rdTrim ?? 0;
  bool hasCigarettesDuring3rdTrim() => _cigarettesDuring3rdTrim != null;

  // "risk_factors" field.
  String? _riskFactors;
  String get riskFactors => _riskFactors ?? '';
  bool hasRiskFactors() => _riskFactors != null;

  // "delivery_information" field.
  String? _deliveryInformation;
  String get deliveryInformation => _deliveryInformation ?? '';
  bool hasDeliveryInformation() => _deliveryInformation != null;

  // "induced_labor" field.
  String? _inducedLabor;
  String get inducedLabor => _inducedLabor ?? '';
  bool hasInducedLabor() => _inducedLabor != null;

  // "augmented_labor" field.
  String? _augmentedLabor;
  String get augmentedLabor => _augmentedLabor ?? '';
  bool hasAugmentedLabor() => _augmentedLabor != null;

  // "antibiotics" field.
  String? _antibiotics;
  String get antibiotics => _antibiotics ?? '';
  bool hasAntibiotics() => _antibiotics != null;

  // "method_of_delivery" field.
  String? _methodOfDelivery;
  String get methodOfDelivery => _methodOfDelivery ?? '';
  bool hasMethodOfDelivery() => _methodOfDelivery != null;

  void _initializeFields() {
    _weight = snapshotData['weight'] as String?;
    _state = snapshotData['state'] as String?;
    _modeOfDelivery = snapshotData['mode_of_delivery'] as String?;
    _complications = getDataList(snapshotData['complications']);
    _firstEncounterId =
        snapshotData['first_encounter_id'] as DocumentReference?;
    _yearOfBirth = snapshotData['year_of_birth'] as String?;
    _maritalStatus = snapshotData['marital_status'] as String?;
    _mothersHeight = snapshotData['mothers_height'] as String?;
    _prepregnancyWeight = snapshotData['prepregnancy_weight'] as String?;
    _mothersEducation = snapshotData['mothers_education'] as String?;
    _fathersAge = snapshotData['fathers_age'] as String?;
    _fathersEducation = snapshotData['fathers_education'] as String?;
    _kidsAlive = castToType<int>(snapshotData['kids_alive']);
    _kidsDead = castToType<int>(snapshotData['kids_dead']);
    _miscarriages = castToType<int>(snapshotData['miscarriages']);
    _birthNumber = castToType<int>(snapshotData['birth_number']);
    _prenatalCareStart = castToType<int>(snapshotData['prenatal_care_start']);
    _expectedPrenatalVisits =
        castToType<int>(snapshotData['expected_prenatal_visits']);
    _cigarettesBeforePregnancy =
        castToType<int>(snapshotData['cigarettes_before_pregnancy']);
    _cigarettesDuring1stTrim =
        castToType<int>(snapshotData['cigarettes_during_1st_trim']);
    _cigarettesDuring2ndTrim =
        castToType<int>(snapshotData['cigarettes_during_2nd_trim']);
    _cigarettesDuring3rdTrim =
        castToType<int>(snapshotData['cigarettes_during_3rd_trim']);
    _riskFactors = snapshotData['risk_factors'] as String?;
    _deliveryInformation = snapshotData['delivery_information'] as String?;
    _inducedLabor = snapshotData['induced_labor'] as String?;
    _augmentedLabor = snapshotData['augmented_labor'] as String?;
    _antibiotics = snapshotData['antibiotics'] as String?;
    _methodOfDelivery = snapshotData['method_of_delivery'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('parity');

  static Stream<ParityRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ParityRecord.fromSnapshot(s));

  static Future<ParityRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ParityRecord.fromSnapshot(s));

  static ParityRecord fromSnapshot(DocumentSnapshot snapshot) => ParityRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ParityRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ParityRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ParityRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ParityRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createParityRecordData({
  String? weight,
  String? state,
  String? modeOfDelivery,
  DocumentReference? firstEncounterId,
  String? yearOfBirth,
  String? maritalStatus,
  String? mothersHeight,
  String? prepregnancyWeight,
  String? mothersEducation,
  String? fathersAge,
  String? fathersEducation,
  int? kidsAlive,
  int? kidsDead,
  int? miscarriages,
  int? birthNumber,
  int? prenatalCareStart,
  int? expectedPrenatalVisits,
  int? cigarettesBeforePregnancy,
  int? cigarettesDuring1stTrim,
  int? cigarettesDuring2ndTrim,
  int? cigarettesDuring3rdTrim,
  String? riskFactors,
  String? deliveryInformation,
  String? inducedLabor,
  String? augmentedLabor,
  String? antibiotics,
  String? methodOfDelivery,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'weight': weight,
      'state': state,
      'mode_of_delivery': modeOfDelivery,
      'first_encounter_id': firstEncounterId,
      'year_of_birth': yearOfBirth,
      'marital_status': maritalStatus,
      'mothers_height': mothersHeight,
      'prepregnancy_weight': prepregnancyWeight,
      'mothers_education': mothersEducation,
      'fathers_age': fathersAge,
      'fathers_education': fathersEducation,
      'kids_alive': kidsAlive,
      'kids_dead': kidsDead,
      'miscarriages': miscarriages,
      'birth_number': birthNumber,
      'prenatal_care_start': prenatalCareStart,
      'expected_prenatal_visits': expectedPrenatalVisits,
      'cigarettes_before_pregnancy': cigarettesBeforePregnancy,
      'cigarettes_during_1st_trim': cigarettesDuring1stTrim,
      'cigarettes_during_2nd_trim': cigarettesDuring2ndTrim,
      'cigarettes_during_3rd_trim': cigarettesDuring3rdTrim,
      'risk_factors': riskFactors,
      'delivery_information': deliveryInformation,
      'induced_labor': inducedLabor,
      'augmented_labor': augmentedLabor,
      'antibiotics': antibiotics,
      'method_of_delivery': methodOfDelivery,
    }.withoutNulls,
  );

  return firestoreData;
}

class ParityRecordDocumentEquality implements Equality<ParityRecord> {
  const ParityRecordDocumentEquality();

  @override
  bool equals(ParityRecord? e1, ParityRecord? e2) {
    const listEquality = ListEquality();
    return e1?.weight == e2?.weight &&
        e1?.state == e2?.state &&
        e1?.modeOfDelivery == e2?.modeOfDelivery &&
        listEquality.equals(e1?.complications, e2?.complications) &&
        e1?.firstEncounterId == e2?.firstEncounterId &&
        e1?.yearOfBirth == e2?.yearOfBirth &&
        e1?.maritalStatus == e2?.maritalStatus &&
        e1?.mothersHeight == e2?.mothersHeight &&
        e1?.prepregnancyWeight == e2?.prepregnancyWeight &&
        e1?.mothersEducation == e2?.mothersEducation &&
        e1?.fathersAge == e2?.fathersAge &&
        e1?.fathersEducation == e2?.fathersEducation &&
        e1?.kidsAlive == e2?.kidsAlive &&
        e1?.kidsDead == e2?.kidsDead &&
        e1?.miscarriages == e2?.miscarriages &&
        e1?.birthNumber == e2?.birthNumber &&
        e1?.prenatalCareStart == e2?.prenatalCareStart &&
        e1?.expectedPrenatalVisits == e2?.expectedPrenatalVisits &&
        e1?.cigarettesBeforePregnancy == e2?.cigarettesBeforePregnancy &&
        e1?.cigarettesDuring1stTrim == e2?.cigarettesDuring1stTrim &&
        e1?.cigarettesDuring2ndTrim == e2?.cigarettesDuring2ndTrim &&
        e1?.cigarettesDuring3rdTrim == e2?.cigarettesDuring3rdTrim &&
        e1?.riskFactors == e2?.riskFactors &&
        e1?.deliveryInformation == e2?.deliveryInformation &&
        e1?.inducedLabor == e2?.inducedLabor &&
        e1?.augmentedLabor == e2?.augmentedLabor &&
        e1?.antibiotics == e2?.antibiotics &&
        e1?.methodOfDelivery == e2?.methodOfDelivery;
  }

  @override
  int hash(ParityRecord? e) => const ListEquality().hash([
        e?.weight,
        e?.state,
        e?.modeOfDelivery,
        e?.complications,
        e?.firstEncounterId,
        e?.yearOfBirth,
        e?.maritalStatus,
        e?.mothersHeight,
        e?.prepregnancyWeight,
        e?.mothersEducation,
        e?.fathersAge,
        e?.fathersEducation,
        e?.kidsAlive,
        e?.kidsDead,
        e?.miscarriages,
        e?.birthNumber,
        e?.prenatalCareStart,
        e?.expectedPrenatalVisits,
        e?.cigarettesBeforePregnancy,
        e?.cigarettesDuring1stTrim,
        e?.cigarettesDuring2ndTrim,
        e?.cigarettesDuring3rdTrim,
        e?.riskFactors,
        e?.deliveryInformation,
        e?.inducedLabor,
        e?.augmentedLabor,
        e?.antibiotics,
        e?.methodOfDelivery
      ]);

  @override
  bool isValidKey(Object? o) => o is ParityRecord;
}
