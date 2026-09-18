import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class FirstEncounterRecord extends FirestoreRecord {
  FirstEncounterRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "gravidity" field.
  String? _gravidity;
  String get gravidity => _gravidity ?? '';
  bool hasGravidity() => _gravidity != null;

  // "diabetes_mellitus" field.
  String? _diabetesMellitus;
  String get diabetesMellitus => _diabetesMellitus ?? '';
  bool hasDiabetesMellitus() => _diabetesMellitus != null;

  // "hypertension" field.
  String? _hypertension;
  String get hypertension => _hypertension ?? '';
  bool hasHypertension() => _hypertension != null;

  // "perceiving_foetal_movement" field.
  String? _perceivingFoetalMovement;
  String get perceivingFoetalMovement => _perceivingFoetalMovement ?? '';
  bool hasPerceivingFoetalMovement() => _perceivingFoetalMovement != null;

  // "draining_any_liquor" field.
  String? _drainingAnyLiquor;
  String get drainingAnyLiquor => _drainingAnyLiquor ?? '';
  bool hasDrainingAnyLiquor() => _drainingAnyLiquor != null;

  // "mother_Id" field.
  DocumentReference? _motherId;
  DocumentReference? get motherId => _motherId;
  bool hasMotherId() => _motherId != null;

  // "sign_of_imminent_eclampsia" field.
  List<String>? _signOfImminentEclampsia;
  List<String> get signOfImminentEclampsia =>
      _signOfImminentEclampsia ?? const [];
  bool hasSignOfImminentEclampsia() => _signOfImminentEclampsia != null;

  // "signs_of_anaemia" field.
  List<String>? _signsOfAnaemia;
  List<String> get signsOfAnaemia => _signsOfAnaemia ?? const [];
  bool hasSignsOfAnaemia() => _signsOfAnaemia != null;

  // "symptoms_of_uti" field.
  List<String>? _symptomsOfUti;
  List<String> get symptomsOfUti => _symptomsOfUti ?? const [];
  bool hasSymptomsOfUti() => _symptomsOfUti != null;

  // "estimated_due_date" field.
  DateTime? _estimatedDueDate;
  DateTime? get estimatedDueDate => _estimatedDueDate;
  bool hasEstimatedDueDate() => _estimatedDueDate != null;

  // "last_vl" field.
  String? _lastVl;
  String get lastVl => _lastVl ?? '';
  bool hasLastVl() => _lastVl != null;

  // "lnmp" field.
  DateTime? _lnmp;
  DateTime? get lnmp => _lnmp;
  bool hasLnmp() => _lnmp != null;

  // "hiv_status" field.
  String? _hivStatus;
  String get hivStatus => _hivStatus ?? '';
  bool hasHivStatus() => _hivStatus != null;

  // "cardiac_disease" field.
  String? _cardiacDisease;
  String get cardiacDisease => _cardiacDisease ?? '';
  bool hasCardiacDisease() => _cardiacDisease != null;

  // "parity" field.
  int? _parity;
  int get parity => _parity ?? 0;
  bool hasParity() => _parity != null;

  // "herbs_taken" field.
  String? _herbsTaken;
  String get herbsTaken => _herbsTaken ?? '';
  bool hasHerbsTaken() => _herbsTaken != null;

  // "any_allergies" field.
  String? _anyAllergies;
  String get anyAllergies => _anyAllergies ?? '';
  bool hasAnyAllergies() => _anyAllergies != null;

  // "side_effect" field.
  String? _sideEffect;
  String get sideEffect => _sideEffect ?? '';
  bool hasSideEffect() => _sideEffect != null;

  // "menstruation_regular" field.
  String? _menstruationRegular;
  String get menstruationRegular => _menstruationRegular ?? '';
  bool hasMenstruationRegular() => _menstruationRegular != null;

  // "cacx" field.
  String? _cacx;
  String get cacx => _cacx ?? '';
  bool hasCacx() => _cacx != null;

  // "cd4" field.
  String? _cd4;
  String get cd4 => _cd4 ?? '';
  bool hasCd4() => _cd4 != null;

  // "epilepsy" field.
  String? _epilepsy;
  String get epilepsy => _epilepsy ?? '';
  bool hasEpilepsy() => _epilepsy != null;

  // "asthma" field.
  String? _asthma;
  String get asthma => _asthma ?? '';
  bool hasAsthma() => _asthma != null;

  // "tb" field.
  String? _tb;
  String get tb => _tb ?? '';
  bool hasTb() => _tb != null;

  // "sickle_cell" field.
  String? _sickleCell;
  String get sickleCell => _sickleCell ?? '';
  bool hasSickleCell() => _sickleCell != null;

  // "cacx_date_of_screen" field.
  DateTime? _cacxDateOfScreen;
  DateTime? get cacxDateOfScreen => _cacxDateOfScreen;
  bool hasCacxDateOfScreen() => _cacxDateOfScreen != null;

  // "booked_date" field.
  DateTime? _bookedDate;
  DateTime? get bookedDate => _bookedDate;
  bool hasBookedDate() => _bookedDate != null;

  // "duration_of_menstruation" field.
  String? _durationOfMenstruation;
  String get durationOfMenstruation => _durationOfMenstruation ?? '';
  bool hasDurationOfMenstruation() => _durationOfMenstruation != null;

  // "drugs_taken" field.
  List<String>? _drugsTaken;
  List<String> get drugsTaken => _drugsTaken ?? const [];
  bool hasDrugsTaken() => _drugsTaken != null;

  // "age_of_menarche" field.
  String? _ageOfMenarche;
  String get ageOfMenarche => _ageOfMenarche ?? '';
  bool hasAgeOfMenarche() => _ageOfMenarche != null;

  // "parity_id" field.
  List<DocumentReference>? _parityId;
  List<DocumentReference> get parityId => _parityId ?? const [];
  bool hasParityId() => _parityId != null;

  // "sti" field.
  List<String>? _sti;
  List<String> get sti => _sti ?? const [];
  bool hasSti() => _sti != null;

  // "anc_dates" field.
  List<DateTime>? _ancDates;
  List<DateTime> get ancDates => _ancDates ?? const [];
  bool hasAncDates() => _ancDates != null;

  void _initializeFields() {
    _gravidity = snapshotData['gravidity'] as String?;
    _diabetesMellitus = snapshotData['diabetes_mellitus'] as String?;
    _hypertension = snapshotData['hypertension'] as String?;
    _perceivingFoetalMovement =
        snapshotData['perceiving_foetal_movement'] as String?;
    _drainingAnyLiquor = snapshotData['draining_any_liquor'] as String?;
    _motherId = snapshotData['mother_Id'] as DocumentReference?;
    _signOfImminentEclampsia =
        getDataList(snapshotData['sign_of_imminent_eclampsia']);
    _signsOfAnaemia = getDataList(snapshotData['signs_of_anaemia']);
    _symptomsOfUti = getDataList(snapshotData['symptoms_of_uti']);
    _estimatedDueDate = snapshotData['estimated_due_date'] as DateTime?;
    _lastVl = snapshotData['last_vl'] as String?;
    _lnmp = snapshotData['lnmp'] as DateTime?;
    _hivStatus = snapshotData['hiv_status'] as String?;
    _cardiacDisease = snapshotData['cardiac_disease'] as String?;
    _parity = castToType<int>(snapshotData['parity']);
    _herbsTaken = snapshotData['herbs_taken'] as String?;
    _anyAllergies = snapshotData['any_allergies'] as String?;
    _sideEffect = snapshotData['side_effect'] as String?;
    _menstruationRegular = snapshotData['menstruation_regular'] as String?;
    _cacx = snapshotData['cacx'] as String?;
    _cd4 = snapshotData['cd4'] as String?;
    _epilepsy = snapshotData['epilepsy'] as String?;
    _asthma = snapshotData['asthma'] as String?;
    _tb = snapshotData['tb'] as String?;
    _sickleCell = snapshotData['sickle_cell'] as String?;
    _cacxDateOfScreen = snapshotData['cacx_date_of_screen'] as DateTime?;
    _bookedDate = snapshotData['booked_date'] as DateTime?;
    _durationOfMenstruation =
        snapshotData['duration_of_menstruation'] as String?;
    _drugsTaken = getDataList(snapshotData['drugs_taken']);
    _ageOfMenarche = snapshotData['age_of_menarche'] as String?;
    _parityId = getDataList(snapshotData['parity_id']);
    _sti = getDataList(snapshotData['sti']);
    _ancDates = getDataList(snapshotData['anc_dates']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('first_encounter');

  static Stream<FirstEncounterRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => FirstEncounterRecord.fromSnapshot(s));

  static Future<FirstEncounterRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => FirstEncounterRecord.fromSnapshot(s));

  static FirstEncounterRecord fromSnapshot(DocumentSnapshot snapshot) =>
      FirstEncounterRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static FirstEncounterRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      FirstEncounterRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'FirstEncounterRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is FirstEncounterRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createFirstEncounterRecordData({
  String? gravidity,
  String? diabetesMellitus,
  String? hypertension,
  String? perceivingFoetalMovement,
  String? drainingAnyLiquor,
  DocumentReference? motherId,
  DateTime? estimatedDueDate,
  String? lastVl,
  DateTime? lnmp,
  String? hivStatus,
  String? cardiacDisease,
  int? parity,
  String? herbsTaken,
  String? anyAllergies,
  String? sideEffect,
  String? menstruationRegular,
  String? cacx,
  String? cd4,
  String? epilepsy,
  String? asthma,
  String? tb,
  String? sickleCell,
  DateTime? cacxDateOfScreen,
  DateTime? bookedDate,
  String? durationOfMenstruation,
  String? ageOfMenarche,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'gravidity': gravidity,
      'diabetes_mellitus': diabetesMellitus,
      'hypertension': hypertension,
      'perceiving_foetal_movement': perceivingFoetalMovement,
      'draining_any_liquor': drainingAnyLiquor,
      'mother_Id': motherId,
      'estimated_due_date': estimatedDueDate,
      'last_vl': lastVl,
      'lnmp': lnmp,
      'hiv_status': hivStatus,
      'cardiac_disease': cardiacDisease,
      'parity': parity,
      'herbs_taken': herbsTaken,
      'any_allergies': anyAllergies,
      'side_effect': sideEffect,
      'menstruation_regular': menstruationRegular,
      'cacx': cacx,
      'cd4': cd4,
      'epilepsy': epilepsy,
      'asthma': asthma,
      'tb': tb,
      'sickle_cell': sickleCell,
      'cacx_date_of_screen': cacxDateOfScreen,
      'booked_date': bookedDate,
      'duration_of_menstruation': durationOfMenstruation,
      'age_of_menarche': ageOfMenarche,
    }.withoutNulls,
  );

  return firestoreData;
}

class FirstEncounterRecordDocumentEquality
    implements Equality<FirstEncounterRecord> {
  const FirstEncounterRecordDocumentEquality();

  @override
  bool equals(FirstEncounterRecord? e1, FirstEncounterRecord? e2) {
    const listEquality = ListEquality();
    return e1?.gravidity == e2?.gravidity &&
        e1?.diabetesMellitus == e2?.diabetesMellitus &&
        e1?.hypertension == e2?.hypertension &&
        e1?.perceivingFoetalMovement == e2?.perceivingFoetalMovement &&
        e1?.drainingAnyLiquor == e2?.drainingAnyLiquor &&
        e1?.motherId == e2?.motherId &&
        listEquality.equals(
            e1?.signOfImminentEclampsia, e2?.signOfImminentEclampsia) &&
        listEquality.equals(e1?.signsOfAnaemia, e2?.signsOfAnaemia) &&
        listEquality.equals(e1?.symptomsOfUti, e2?.symptomsOfUti) &&
        e1?.estimatedDueDate == e2?.estimatedDueDate &&
        e1?.lastVl == e2?.lastVl &&
        e1?.lnmp == e2?.lnmp &&
        e1?.hivStatus == e2?.hivStatus &&
        e1?.cardiacDisease == e2?.cardiacDisease &&
        e1?.parity == e2?.parity &&
        e1?.herbsTaken == e2?.herbsTaken &&
        e1?.anyAllergies == e2?.anyAllergies &&
        e1?.sideEffect == e2?.sideEffect &&
        e1?.menstruationRegular == e2?.menstruationRegular &&
        e1?.cacx == e2?.cacx &&
        e1?.cd4 == e2?.cd4 &&
        e1?.epilepsy == e2?.epilepsy &&
        e1?.asthma == e2?.asthma &&
        e1?.tb == e2?.tb &&
        e1?.sickleCell == e2?.sickleCell &&
        e1?.cacxDateOfScreen == e2?.cacxDateOfScreen &&
        e1?.bookedDate == e2?.bookedDate &&
        e1?.durationOfMenstruation == e2?.durationOfMenstruation &&
        listEquality.equals(e1?.drugsTaken, e2?.drugsTaken) &&
        e1?.ageOfMenarche == e2?.ageOfMenarche &&
        listEquality.equals(e1?.parityId, e2?.parityId) &&
        listEquality.equals(e1?.sti, e2?.sti) &&
        listEquality.equals(e1?.ancDates, e2?.ancDates);
  }

  @override
  int hash(FirstEncounterRecord? e) => const ListEquality().hash([
        e?.gravidity,
        e?.diabetesMellitus,
        e?.hypertension,
        e?.perceivingFoetalMovement,
        e?.drainingAnyLiquor,
        e?.motherId,
        e?.signOfImminentEclampsia,
        e?.signsOfAnaemia,
        e?.symptomsOfUti,
        e?.estimatedDueDate,
        e?.lastVl,
        e?.lnmp,
        e?.hivStatus,
        e?.cardiacDisease,
        e?.parity,
        e?.herbsTaken,
        e?.anyAllergies,
        e?.sideEffect,
        e?.menstruationRegular,
        e?.cacx,
        e?.cd4,
        e?.epilepsy,
        e?.asthma,
        e?.tb,
        e?.sickleCell,
        e?.cacxDateOfScreen,
        e?.bookedDate,
        e?.durationOfMenstruation,
        e?.drugsTaken,
        e?.ageOfMenarche,
        e?.parityId,
        e?.sti,
        e?.ancDates
      ]);

  @override
  bool isValidKey(Object? o) => o is FirstEncounterRecord;
}
