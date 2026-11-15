import 'package:clinician/backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic persistence contracts. These assertions intentionally preserve
// legacy field names, absent-vs-zero distinctions and foreign references.
void main() {
  final moment = DateTime.utc(2026, 1, 2);
  final foreign = MotherRecord.collection.doc('synthetic-related');
  test('UserRecord persistence preserves every supplied field and absence', () {
    final reference = UserRecord.collection.doc('synthetic-row');
    final data = createUserRecordData(
      email: 'synthetic-email',
      displayName: 'synthetic-displayName',
      photoUrl: 'synthetic-photoUrl',
      uid: 'synthetic-uid',
      createdTime: moment,
      phoneNumber: 'synthetic-phoneNumber',
      role: 'synthetic-role',
    );
    final record = UserRecord.getDocumentFromData(data, reference);
    final absent = UserRecord.getDocumentFromData({}, reference);
    expect(record.email, 'synthetic-email');
    expect(record.hasEmail(), isTrue);
    expect(absent.hasEmail(), isFalse);
    expect(record.displayName, 'synthetic-displayName');
    expect(record.hasDisplayName(), isTrue);
    expect(absent.hasDisplayName(), isFalse);
    expect(record.photoUrl, 'synthetic-photoUrl');
    expect(record.hasPhotoUrl(), isTrue);
    expect(absent.hasPhotoUrl(), isFalse);
    expect(record.uid, 'synthetic-uid');
    expect(record.hasUid(), isTrue);
    expect(absent.hasUid(), isFalse);
    expect(record.createdTime, moment);
    expect(record.hasCreatedTime(), isTrue);
    expect(absent.hasCreatedTime(), isFalse);
    expect(record.phoneNumber, 'synthetic-phoneNumber');
    expect(record.hasPhoneNumber(), isTrue);
    expect(absent.hasPhoneNumber(), isFalse);
    expect(record.role, 'synthetic-role');
    expect(record.hasRole(), isTrue);
    expect(absent.hasRole(), isFalse);
    final copy = UserRecord.getDocumentFromData(Map.of(data), reference);
    const equality = UserRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
  test('MotherRecord persistence preserves every supplied field and absence',
      () {
    final reference = MotherRecord.collection.doc('synthetic-row');
    final data = createMotherRecordData(
      dateOfBirth: moment,
      occupation: 'synthetic-occupation',
      address: 'synthetic-address',
      userId: foreign,
      name: 'synthetic-name',
      phoneNumber: 'synthetic-phoneNumber',
      motherId: 'synthetic-motherId',
      firstEncounterId: foreign,
      nrc: 'synthetic-nrc',
      village: 'synthetic-village',
      clinicName: 'synthetic-clinicName',
      sourceProject: 'synthetic-sourceProject',
      sourceMotherId: 'synthetic-sourceMotherId',
      sourceUserId: 'synthetic-sourceUserId',
      registrationSource: 'synthetic-registrationSource',
      syncedAt: moment,
      sourceDeletedAt: moment,
    );
    final record = MotherRecord.getDocumentFromData(data, reference);
    final absent = MotherRecord.getDocumentFromData({}, reference);
    expect(record.dateOfBirth, moment);
    expect(record.hasDateOfBirth(), isTrue);
    expect(absent.hasDateOfBirth(), isFalse);
    expect(record.occupation, 'synthetic-occupation');
    expect(record.hasOccupation(), isTrue);
    expect(absent.hasOccupation(), isFalse);
    expect(record.address, 'synthetic-address');
    expect(record.hasAddress(), isTrue);
    expect(absent.hasAddress(), isFalse);
    expect(record.userId, foreign);
    expect(record.hasUserId(), isTrue);
    expect(absent.hasUserId(), isFalse);
    expect(record.name, 'synthetic-name');
    expect(record.hasName(), isTrue);
    expect(absent.hasName(), isFalse);
    expect(record.phoneNumber, 'synthetic-phoneNumber');
    expect(record.hasPhoneNumber(), isTrue);
    expect(absent.hasPhoneNumber(), isFalse);
    expect(record.motherId, 'synthetic-motherId');
    expect(record.hasMotherId(), isTrue);
    expect(absent.hasMotherId(), isFalse);
    expect(record.firstEncounterId, foreign);
    expect(record.hasFirstEncounterId(), isTrue);
    expect(absent.hasFirstEncounterId(), isFalse);
    expect(record.nrc, 'synthetic-nrc');
    expect(record.hasNrc(), isTrue);
    expect(absent.hasNrc(), isFalse);
    expect(record.village, 'synthetic-village');
    expect(record.hasVillage(), isTrue);
    expect(absent.hasVillage(), isFalse);
    expect(record.clinicName, 'synthetic-clinicName');
    expect(record.hasClinicName(), isTrue);
    expect(absent.hasClinicName(), isFalse);
    expect(record.sourceProject, 'synthetic-sourceProject');
    expect(record.hasSourceProject(), isTrue);
    expect(absent.hasSourceProject(), isFalse);
    expect(record.sourceMotherId, 'synthetic-sourceMotherId');
    expect(record.hasSourceMotherId(), isTrue);
    expect(absent.hasSourceMotherId(), isFalse);
    expect(record.sourceUserId, 'synthetic-sourceUserId');
    expect(record.hasSourceUserId(), isTrue);
    expect(absent.hasSourceUserId(), isFalse);
    expect(record.registrationSource, 'synthetic-registrationSource');
    expect(record.hasRegistrationSource(), isTrue);
    expect(absent.hasRegistrationSource(), isFalse);
    expect(record.syncedAt, moment);
    expect(record.hasSyncedAt(), isTrue);
    expect(absent.hasSyncedAt(), isFalse);
    expect(record.sourceDeletedAt, moment);
    expect(record.hasSourceDeletedAt(), isTrue);
    expect(absent.hasSourceDeletedAt(), isFalse);
    final copy = MotherRecord.getDocumentFromData(Map.of(data), reference);
    const equality = MotherRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
  test('DoctorRecord persistence preserves every supplied field and absence',
      () {
    final reference = DoctorRecord.collection.doc('synthetic-row');
    final data = createDoctorRecordData(
      speciality: 'synthetic-speciality',
      userId: foreign,
      clinicName: 'synthetic-clinicName',
      startTime: 'synthetic-startTime',
      endTime: 'synthetic-endTime',
      name: 'synthetic-name',
      phoneNumber: 'synthetic-phoneNumber',
      doctorId: 'synthetic-doctorId',
    );
    final record = DoctorRecord.getDocumentFromData(data, reference);
    final absent = DoctorRecord.getDocumentFromData({}, reference);
    expect(record.speciality, 'synthetic-speciality');
    expect(record.hasSpeciality(), isTrue);
    expect(absent.hasSpeciality(), isFalse);
    expect(record.userId, foreign);
    expect(record.hasUserId(), isTrue);
    expect(absent.hasUserId(), isFalse);
    expect(record.clinicName, 'synthetic-clinicName');
    expect(record.hasClinicName(), isTrue);
    expect(absent.hasClinicName(), isFalse);
    expect(record.startTime, 'synthetic-startTime');
    expect(record.hasStartTime(), isTrue);
    expect(absent.hasStartTime(), isFalse);
    expect(record.endTime, 'synthetic-endTime');
    expect(record.hasEndTime(), isTrue);
    expect(absent.hasEndTime(), isFalse);
    expect(record.name, 'synthetic-name');
    expect(record.hasName(), isTrue);
    expect(absent.hasName(), isFalse);
    expect(record.phoneNumber, 'synthetic-phoneNumber');
    expect(record.hasPhoneNumber(), isTrue);
    expect(absent.hasPhoneNumber(), isFalse);
    expect(record.doctorId, 'synthetic-doctorId');
    expect(record.hasDoctorId(), isTrue);
    expect(absent.hasDoctorId(), isFalse);
    final copy = DoctorRecord.getDocumentFromData(Map.of(data), reference);
    const equality = DoctorRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
  test('ClinicRecord persistence preserves every supplied field and absence',
      () {
    final reference = ClinicRecord.collection.doc('synthetic-row');
    final data = createClinicRecordData(
      name: 'synthetic-name',
      address: 'synthetic-address',
    );
    final record = ClinicRecord.getDocumentFromData(data, reference);
    final absent = ClinicRecord.getDocumentFromData({}, reference);
    expect(record.name, 'synthetic-name');
    expect(record.hasName(), isTrue);
    expect(absent.hasName(), isFalse);
    expect(record.address, 'synthetic-address');
    expect(record.hasAddress(), isTrue);
    expect(absent.hasAddress(), isFalse);
    final copy = ClinicRecord.getDocumentFromData(Map.of(data), reference);
    const equality = ClinicRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
  test(
      'FirstEncounterRecord persistence preserves every supplied field and absence',
      () {
    final reference = FirstEncounterRecord.collection.doc('synthetic-row');
    final data = createFirstEncounterRecordData(
      gravidity: 'synthetic-gravidity',
      diabetesMellitus: 'synthetic-diabetesMellitus',
      hypertension: 'synthetic-hypertension',
      perceivingFoetalMovement: 'synthetic-perceivingFoetalMovement',
      drainingAnyLiquor: 'synthetic-drainingAnyLiquor',
      motherId: foreign,
      estimatedDueDate: moment,
      lastVl: 'synthetic-lastVl',
      lnmp: moment,
      hivStatus: 'synthetic-hivStatus',
      cardiacDisease: 'synthetic-cardiacDisease',
      parity: 0,
      herbsTaken: 'synthetic-herbsTaken',
      anyAllergies: 'synthetic-anyAllergies',
      sideEffect: 'synthetic-sideEffect',
      menstruationRegular: 'synthetic-menstruationRegular',
      cacx: 'synthetic-cacx',
      cd4: 'synthetic-cd4',
      epilepsy: 'synthetic-epilepsy',
      asthma: 'synthetic-asthma',
      tb: 'synthetic-tb',
      sickleCell: 'synthetic-sickleCell',
      cacxDateOfScreen: moment,
      bookedDate: moment,
      durationOfMenstruation: 'synthetic-durationOfMenstruation',
      ageOfMenarche: 'synthetic-ageOfMenarche',
    );
    final record = FirstEncounterRecord.getDocumentFromData(data, reference);
    final absent = FirstEncounterRecord.getDocumentFromData({}, reference);
    expect(record.gravidity, 'synthetic-gravidity');
    expect(record.hasGravidity(), isTrue);
    expect(absent.hasGravidity(), isFalse);
    expect(record.diabetesMellitus, 'synthetic-diabetesMellitus');
    expect(record.hasDiabetesMellitus(), isTrue);
    expect(absent.hasDiabetesMellitus(), isFalse);
    expect(record.hypertension, 'synthetic-hypertension');
    expect(record.hasHypertension(), isTrue);
    expect(absent.hasHypertension(), isFalse);
    expect(
        record.perceivingFoetalMovement, 'synthetic-perceivingFoetalMovement');
    expect(record.hasPerceivingFoetalMovement(), isTrue);
    expect(absent.hasPerceivingFoetalMovement(), isFalse);
    expect(record.drainingAnyLiquor, 'synthetic-drainingAnyLiquor');
    expect(record.hasDrainingAnyLiquor(), isTrue);
    expect(absent.hasDrainingAnyLiquor(), isFalse);
    expect(record.motherId, foreign);
    expect(record.hasMotherId(), isTrue);
    expect(absent.hasMotherId(), isFalse);
    expect(record.estimatedDueDate, moment);
    expect(record.hasEstimatedDueDate(), isTrue);
    expect(absent.hasEstimatedDueDate(), isFalse);
    expect(record.lastVl, 'synthetic-lastVl');
    expect(record.hasLastVl(), isTrue);
    expect(absent.hasLastVl(), isFalse);
    expect(record.lnmp, moment);
    expect(record.hasLnmp(), isTrue);
    expect(absent.hasLnmp(), isFalse);
    expect(record.hivStatus, 'synthetic-hivStatus');
    expect(record.hasHivStatus(), isTrue);
    expect(absent.hasHivStatus(), isFalse);
    expect(record.cardiacDisease, 'synthetic-cardiacDisease');
    expect(record.hasCardiacDisease(), isTrue);
    expect(absent.hasCardiacDisease(), isFalse);
    expect(record.parity, 0);
    expect(record.hasParity(), isTrue);
    expect(absent.hasParity(), isFalse);
    expect(record.herbsTaken, 'synthetic-herbsTaken');
    expect(record.hasHerbsTaken(), isTrue);
    expect(absent.hasHerbsTaken(), isFalse);
    expect(record.anyAllergies, 'synthetic-anyAllergies');
    expect(record.hasAnyAllergies(), isTrue);
    expect(absent.hasAnyAllergies(), isFalse);
    expect(record.sideEffect, 'synthetic-sideEffect');
    expect(record.hasSideEffect(), isTrue);
    expect(absent.hasSideEffect(), isFalse);
    expect(record.menstruationRegular, 'synthetic-menstruationRegular');
    expect(record.hasMenstruationRegular(), isTrue);
    expect(absent.hasMenstruationRegular(), isFalse);
    expect(record.cacx, 'synthetic-cacx');
    expect(record.hasCacx(), isTrue);
    expect(absent.hasCacx(), isFalse);
    expect(record.cd4, 'synthetic-cd4');
    expect(record.hasCd4(), isTrue);
    expect(absent.hasCd4(), isFalse);
    expect(record.epilepsy, 'synthetic-epilepsy');
    expect(record.hasEpilepsy(), isTrue);
    expect(absent.hasEpilepsy(), isFalse);
    expect(record.asthma, 'synthetic-asthma');
    expect(record.hasAsthma(), isTrue);
    expect(absent.hasAsthma(), isFalse);
    expect(record.tb, 'synthetic-tb');
    expect(record.hasTb(), isTrue);
    expect(absent.hasTb(), isFalse);
    expect(record.sickleCell, 'synthetic-sickleCell');
    expect(record.hasSickleCell(), isTrue);
    expect(absent.hasSickleCell(), isFalse);
    expect(record.cacxDateOfScreen, moment);
    expect(record.hasCacxDateOfScreen(), isTrue);
    expect(absent.hasCacxDateOfScreen(), isFalse);
    expect(record.bookedDate, moment);
    expect(record.hasBookedDate(), isTrue);
    expect(absent.hasBookedDate(), isFalse);
    expect(record.durationOfMenstruation, 'synthetic-durationOfMenstruation');
    expect(record.hasDurationOfMenstruation(), isTrue);
    expect(absent.hasDurationOfMenstruation(), isFalse);
    expect(record.ageOfMenarche, 'synthetic-ageOfMenarche');
    expect(record.hasAgeOfMenarche(), isTrue);
    expect(absent.hasAgeOfMenarche(), isFalse);
    final copy =
        FirstEncounterRecord.getDocumentFromData(Map.of(data), reference);
    const equality = FirstEncounterRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
  test('EncounterRecord persistence preserves every supplied field and absence',
      () {
    final reference = EncounterRecord.collection.doc('synthetic-row');
    final data = createEncounterRecordData(
      bp: 'synthetic-bp',
      pulse: 0,
      nextVisit: moment,
      comment: 'synthetic-comment',
      usObstetrics: 'synthetic-usObstetrics',
      leucocytesEsterase: 'synthetic-leucocytesEsterase',
      nitrates: 'synthetic-nitrates',
      urologobulin: 'synthetic-urologobulin',
      protein: 'synthetic-protein',
      ph: 'synthetic-ph',
      blood: 'synthetic-blood',
      ketones: 'synthetic-ketones',
      bilirubin: 'synthetic-bilirubin',
      glucose: 'synthetic-glucose',
      color: 'synthetic-color',
      clarity: 'synthetic-clarity',
      odor: 'synthetic-odor',
      casts: 'synthetic-casts',
      date: moment,
      motherId: foreign,
      referForAnemia: 'synthetic-referForAnemia',
      heartBeat: 0,
      heartBeatQuality: 'synthetic-heartBeatQuality',
      wombPosition: 'synthetic-wombPosition',
      estimatedBabySize: 0,
      hemocheck: 0,
      specificGravity: 'synthetic-specificGravity',
      foetalHemocheck: 0,
      clinicId: foreign,
      doctorId: foreign,
      status: 'synthetic-status',
      isInstant: false,
      time: 'synthetic-time',
      performedBy: foreign,
      datePerformed: moment,
    );
    final record = EncounterRecord.getDocumentFromData(data, reference);
    final absent = EncounterRecord.getDocumentFromData({}, reference);
    expect(record.bp, 'synthetic-bp');
    expect(record.hasBp(), isTrue);
    expect(absent.hasBp(), isFalse);
    expect(record.pulse, 0);
    expect(record.hasPulse(), isTrue);
    expect(absent.hasPulse(), isFalse);
    expect(record.nextVisit, moment);
    expect(record.hasNextVisit(), isTrue);
    expect(absent.hasNextVisit(), isFalse);
    expect(record.comment, 'synthetic-comment');
    expect(record.hasComment(), isTrue);
    expect(absent.hasComment(), isFalse);
    expect(record.usObstetrics, 'synthetic-usObstetrics');
    expect(record.hasUsObstetrics(), isTrue);
    expect(absent.hasUsObstetrics(), isFalse);
    expect(record.leucocytesEsterase, 'synthetic-leucocytesEsterase');
    expect(record.hasLeucocytesEsterase(), isTrue);
    expect(absent.hasLeucocytesEsterase(), isFalse);
    expect(record.nitrates, 'synthetic-nitrates');
    expect(record.hasNitrates(), isTrue);
    expect(absent.hasNitrates(), isFalse);
    expect(record.urologobulin, 'synthetic-urologobulin');
    expect(record.hasUrologobulin(), isTrue);
    expect(absent.hasUrologobulin(), isFalse);
    expect(record.protein, 'synthetic-protein');
    expect(record.hasProtein(), isTrue);
    expect(absent.hasProtein(), isFalse);
    expect(record.ph, 'synthetic-ph');
    expect(record.hasPh(), isTrue);
    expect(absent.hasPh(), isFalse);
    expect(record.blood, 'synthetic-blood');
    expect(record.hasBlood(), isTrue);
    expect(absent.hasBlood(), isFalse);
    expect(record.ketones, 'synthetic-ketones');
    expect(record.hasKetones(), isTrue);
    expect(absent.hasKetones(), isFalse);
    expect(record.bilirubin, 'synthetic-bilirubin');
    expect(record.hasBilirubin(), isTrue);
    expect(absent.hasBilirubin(), isFalse);
    expect(record.glucose, 'synthetic-glucose');
    expect(record.hasGlucose(), isTrue);
    expect(absent.hasGlucose(), isFalse);
    expect(record.color, 'synthetic-color');
    expect(record.hasColor(), isTrue);
    expect(absent.hasColor(), isFalse);
    expect(record.clarity, 'synthetic-clarity');
    expect(record.hasClarity(), isTrue);
    expect(absent.hasClarity(), isFalse);
    expect(record.odor, 'synthetic-odor');
    expect(record.hasOdor(), isTrue);
    expect(absent.hasOdor(), isFalse);
    expect(record.casts, 'synthetic-casts');
    expect(record.hasCasts(), isTrue);
    expect(absent.hasCasts(), isFalse);
    expect(record.date, moment);
    expect(record.hasDate(), isTrue);
    expect(absent.hasDate(), isFalse);
    expect(record.motherId, foreign);
    expect(record.hasMotherId(), isTrue);
    expect(absent.hasMotherId(), isFalse);
    expect(record.referForAnemia, 'synthetic-referForAnemia');
    expect(record.hasReferForAnemia(), isTrue);
    expect(absent.hasReferForAnemia(), isFalse);
    expect(record.heartBeat, 0);
    expect(record.hasHeartBeat(), isTrue);
    expect(absent.hasHeartBeat(), isFalse);
    expect(record.heartBeatQuality, 'synthetic-heartBeatQuality');
    expect(record.hasHeartBeatQuality(), isTrue);
    expect(absent.hasHeartBeatQuality(), isFalse);
    expect(record.wombPosition, 'synthetic-wombPosition');
    expect(record.hasWombPosition(), isTrue);
    expect(absent.hasWombPosition(), isFalse);
    expect(record.estimatedBabySize, 0);
    expect(record.hasEstimatedBabySize(), isTrue);
    expect(absent.hasEstimatedBabySize(), isFalse);
    expect(record.hemocheck, 0);
    expect(record.hasHemocheck(), isTrue);
    expect(absent.hasHemocheck(), isFalse);
    expect(record.specificGravity, 'synthetic-specificGravity');
    expect(record.hasSpecificGravity(), isTrue);
    expect(absent.hasSpecificGravity(), isFalse);
    expect(record.foetalHemocheck, 0);
    expect(record.hasFoetalHemocheck(), isTrue);
    expect(absent.hasFoetalHemocheck(), isFalse);
    expect(record.clinicId, foreign);
    expect(record.hasClinicId(), isTrue);
    expect(absent.hasClinicId(), isFalse);
    expect(record.doctorId, foreign);
    expect(record.hasDoctorId(), isTrue);
    expect(absent.hasDoctorId(), isFalse);
    expect(record.status, 'synthetic-status');
    expect(record.hasStatus(), isTrue);
    expect(absent.hasStatus(), isFalse);
    expect(record.isInstant, false);
    expect(record.hasIsInstant(), isTrue);
    expect(absent.hasIsInstant(), isFalse);
    expect(record.time, 'synthetic-time');
    expect(record.hasTime(), isTrue);
    expect(absent.hasTime(), isFalse);
    expect(record.performedBy, foreign);
    expect(record.hasPerformedBy(), isTrue);
    expect(absent.hasPerformedBy(), isFalse);
    expect(record.datePerformed, moment);
    expect(record.hasDatePerformed(), isTrue);
    expect(absent.hasDatePerformed(), isFalse);
    final copy = EncounterRecord.getDocumentFromData(Map.of(data), reference);
    const equality = EncounterRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
  test('ParityRecord persistence preserves every supplied field and absence',
      () {
    final reference = ParityRecord.collection.doc('synthetic-row');
    final data = createParityRecordData(
      weight: 'synthetic-weight',
      state: 'synthetic-state',
      modeOfDelivery: 'synthetic-modeOfDelivery',
      firstEncounterId: foreign,
      yearOfBirth: 'synthetic-yearOfBirth',
      maritalStatus: 'synthetic-maritalStatus',
      mothersHeight: 'synthetic-mothersHeight',
      prepregnancyWeight: 'synthetic-prepregnancyWeight',
      mothersEducation: 'synthetic-mothersEducation',
      fathersAge: 'synthetic-fathersAge',
      fathersEducation: 'synthetic-fathersEducation',
      kidsAlive: 0,
      kidsDead: 0,
      miscarriages: 0,
      birthNumber: 0,
      prenatalCareStart: 0,
      expectedPrenatalVisits: 0,
      cigarettesBeforePregnancy: 0,
      cigarettesDuring1stTrim: 0,
      cigarettesDuring2ndTrim: 0,
      cigarettesDuring3rdTrim: 0,
      riskFactors: 'synthetic-riskFactors',
      deliveryInformation: 'synthetic-deliveryInformation',
      inducedLabor: 'synthetic-inducedLabor',
      augmentedLabor: 'synthetic-augmentedLabor',
      antibiotics: 'synthetic-antibiotics',
      methodOfDelivery: 'synthetic-methodOfDelivery',
    );
    final record = ParityRecord.getDocumentFromData(data, reference);
    final absent = ParityRecord.getDocumentFromData({}, reference);
    expect(record.weight, 'synthetic-weight');
    expect(record.hasWeight(), isTrue);
    expect(absent.hasWeight(), isFalse);
    expect(record.state, 'synthetic-state');
    expect(record.hasState(), isTrue);
    expect(absent.hasState(), isFalse);
    expect(record.modeOfDelivery, 'synthetic-modeOfDelivery');
    expect(record.hasModeOfDelivery(), isTrue);
    expect(absent.hasModeOfDelivery(), isFalse);
    expect(record.firstEncounterId, foreign);
    expect(record.hasFirstEncounterId(), isTrue);
    expect(absent.hasFirstEncounterId(), isFalse);
    expect(record.yearOfBirth, 'synthetic-yearOfBirth');
    expect(record.hasYearOfBirth(), isTrue);
    expect(absent.hasYearOfBirth(), isFalse);
    expect(record.maritalStatus, 'synthetic-maritalStatus');
    expect(record.hasMaritalStatus(), isTrue);
    expect(absent.hasMaritalStatus(), isFalse);
    expect(record.mothersHeight, 'synthetic-mothersHeight');
    expect(record.hasMothersHeight(), isTrue);
    expect(absent.hasMothersHeight(), isFalse);
    expect(record.prepregnancyWeight, 'synthetic-prepregnancyWeight');
    expect(record.hasPrepregnancyWeight(), isTrue);
    expect(absent.hasPrepregnancyWeight(), isFalse);
    expect(record.mothersEducation, 'synthetic-mothersEducation');
    expect(record.hasMothersEducation(), isTrue);
    expect(absent.hasMothersEducation(), isFalse);
    expect(record.fathersAge, 'synthetic-fathersAge');
    expect(record.hasFathersAge(), isTrue);
    expect(absent.hasFathersAge(), isFalse);
    expect(record.fathersEducation, 'synthetic-fathersEducation');
    expect(record.hasFathersEducation(), isTrue);
    expect(absent.hasFathersEducation(), isFalse);
    expect(record.kidsAlive, 0);
    expect(record.hasKidsAlive(), isTrue);
    expect(absent.hasKidsAlive(), isFalse);
    expect(record.kidsDead, 0);
    expect(record.hasKidsDead(), isTrue);
    expect(absent.hasKidsDead(), isFalse);
    expect(record.miscarriages, 0);
    expect(record.hasMiscarriages(), isTrue);
    expect(absent.hasMiscarriages(), isFalse);
    expect(record.birthNumber, 0);
    expect(record.hasBirthNumber(), isTrue);
    expect(absent.hasBirthNumber(), isFalse);
    expect(record.prenatalCareStart, 0);
    expect(record.hasPrenatalCareStart(), isTrue);
    expect(absent.hasPrenatalCareStart(), isFalse);
    expect(record.expectedPrenatalVisits, 0);
    expect(record.hasExpectedPrenatalVisits(), isTrue);
    expect(absent.hasExpectedPrenatalVisits(), isFalse);
    expect(record.cigarettesBeforePregnancy, 0);
    expect(record.hasCigarettesBeforePregnancy(), isTrue);
    expect(absent.hasCigarettesBeforePregnancy(), isFalse);
    expect(record.cigarettesDuring1stTrim, 0);
    expect(record.hasCigarettesDuring1stTrim(), isTrue);
    expect(absent.hasCigarettesDuring1stTrim(), isFalse);
    expect(record.cigarettesDuring2ndTrim, 0);
    expect(record.hasCigarettesDuring2ndTrim(), isTrue);
    expect(absent.hasCigarettesDuring2ndTrim(), isFalse);
    expect(record.cigarettesDuring3rdTrim, 0);
    expect(record.hasCigarettesDuring3rdTrim(), isTrue);
    expect(absent.hasCigarettesDuring3rdTrim(), isFalse);
    expect(record.riskFactors, 'synthetic-riskFactors');
    expect(record.hasRiskFactors(), isTrue);
    expect(absent.hasRiskFactors(), isFalse);
    expect(record.deliveryInformation, 'synthetic-deliveryInformation');
    expect(record.hasDeliveryInformation(), isTrue);
    expect(absent.hasDeliveryInformation(), isFalse);
    expect(record.inducedLabor, 'synthetic-inducedLabor');
    expect(record.hasInducedLabor(), isTrue);
    expect(absent.hasInducedLabor(), isFalse);
    expect(record.augmentedLabor, 'synthetic-augmentedLabor');
    expect(record.hasAugmentedLabor(), isTrue);
    expect(absent.hasAugmentedLabor(), isFalse);
    expect(record.antibiotics, 'synthetic-antibiotics');
    expect(record.hasAntibiotics(), isTrue);
    expect(absent.hasAntibiotics(), isFalse);
    expect(record.methodOfDelivery, 'synthetic-methodOfDelivery');
    expect(record.hasMethodOfDelivery(), isTrue);
    expect(absent.hasMethodOfDelivery(), isFalse);
    final copy = ParityRecord.getDocumentFromData(Map.of(data), reference);
    const equality = ParityRecordDocumentEquality();
    expect(equality.equals(record, copy), isTrue);
    expect(equality.hash(record), equality.hash(copy));
    expect(equality.equals(record, absent), isFalse);
    expect(equality.isValidKey(record), isTrue);
    expect(equality.isValidKey("wrong type"), isFalse);
    expect(record, copy);
    expect(record.hashCode, copy.hashCode);
  });
}
