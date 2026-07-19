import 'package:clinician/app_state.dart';
import 'package:clinician/auth/complete_clincian_reg/complete_clincian_reg_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FFAppState.reset();
    await FFAppState().initializePersistedState();
  });

  testWidgets('registration form works on phone and tablet widths',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _testApp(
          repository: _FakeRegistrationRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete registration'), findsOneWidget);
      expect(find.byKey(const Key('registration-back-button')), findsOneWidget);
      expect(find.byKey(const Key('registration-name-field')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
  });

  testWidgets('required fields show specific inline validation messages',
      (tester) async {
    await tester.pumpWidget(
      _testApp(repository: _FakeRegistrationRepository()),
    );
    await tester.pumpAndSettle();

    final continueButton =
        find.byKey(const Key('registration-continue-button'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();

    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(
      find.text('Enter a valid Zambia number, for example +260971234567.'),
      findsOneWidget,
    );
    expect(find.text('Enter your clinical specialty.'), findsOneWidget);
    expect(find.text('Select your clinic.'), findsOneWidget);
    expect(find.text('Select your clinic start time.'), findsOneWidget);
    expect(find.text('Select your clinic end time.'), findsOneWidget);
  });

  testWidgets('clinic loading failure presents a working retry action',
      (tester) async {
    final repository = _FakeRegistrationRepository(clinicFailures: 1);
    await tester.pumpWidget(_testApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clinic-load-error')), findsOneWidget);
    expect(find.text('Clinics could not be loaded'), findsOneWidget);

    final retryButton = find.byKey(const Key('registration-retry-button'));
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.clinicLoadCount, 2);
    expect(find.byKey(const Key('registration-clinic-field')), findsOneWidget);
  });

  testWidgets('submission saves the selected clinic ID and completes once',
      (tester) async {
    final repository = _FakeRegistrationRepository();
    var completionCount = 0;
    await tester.pumpWidget(
      _testApp(
        repository: repository,
        onCompleted: (_) => completionCount += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('registration-name-field')),
      'Test Clinician',
    );
    await tester.enterText(
      find.byKey(const Key('registration-phone-field')),
      '+260971234567',
    );
    await tester.enterText(
      find.byKey(const Key('registration-speciality-field')),
      'General Practice',
    );
    await _selectDropdown(
      tester,
      const Key('registration-clinic-field'),
      'Dawa Central — Lusaka',
    );
    await _selectDropdown(
      tester,
      const Key('registration-start-time-field'),
      '08:00',
    );
    await _selectDropdown(
      tester,
      const Key('registration-end-time-field'),
      '08:30',
    );

    final continueButton =
        find.byKey(const Key('registration-continue-button'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.tap(continueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.submissionCount, 1);
    expect(repository.lastInput?.clinic.id, 'clinic-123');
    expect(repository.lastInput?.clinic.name, 'Dawa Central');
    expect(repository.lastInput?.phoneNumber, '+260971234567');
    expect(completionCount, 1);
  });

  testWidgets('completed profile leaves registration without resubmitting',
      (tester) async {
    final repository = _FakeRegistrationRepository(
      profile: const ClinicianRegistrationProfile(
        id: 'doctor-existing',
        name: 'Existing Clinician',
        phoneNumber: '+260971234567',
        speciality: 'Midwifery',
        clinicId: 'clinic-123',
        clinicName: 'Dawa Central',
        startTime: '08:00',
        endTime: '16:00',
      ),
    );
    var completionCount = 0;

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        onCompleted: (_) => completionCount += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(completionCount, 1);
    expect(repository.submissionCount, 0);
  });

  testWidgets('back option returns control to sign-in flow', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      _testApp(
        repository: _FakeRegistrationRepository(),
        onBack: () async => backCount += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registration-back-button')));
    await tester.pump();

    expect(backCount, 1);
  });
}

Widget _testApp({
  required ClinicianRegistrationRepository repository,
  Future<void> Function()? onBack,
  void Function(ClinicianRegistrationProfile profile)? onCompleted,
}) =>
    MaterialApp(
      home: CompleteClincianRegWidget(
        repository: repository,
        onBack: onBack,
        onCompleted: onCompleted,
      ),
    );

Future<void> _selectDropdown(
  WidgetTester tester,
  Key key,
  String option,
) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

class _FakeRegistrationRepository implements ClinicianRegistrationRepository {
  _FakeRegistrationRepository({
    this.profile,
    this.clinicFailures = 0,
  });

  ClinicianRegistrationProfile? profile;
  int clinicFailures;
  int clinicLoadCount = 0;
  int submissionCount = 0;
  ClinicianRegistrationInput? lastInput;

  @override
  Future<ClinicianRegistrationProfile?> loadProfile() async => profile;

  @override
  Future<List<ClinicOption>> loadClinics() async {
    clinicLoadCount += 1;
    if (clinicLoadCount <= clinicFailures) {
      throw const ClinicianRegistrationException(
        'The clinic directory is temporarily unavailable.',
      );
    }
    return const [
      ClinicOption(
        id: 'clinic-123',
        name: 'Dawa Central',
        address: 'Lusaka',
      ),
    ];
  }

  @override
  Future<ClinicianRegistrationProfile> completeRegistration(
    ClinicianRegistrationInput input,
  ) async {
    submissionCount += 1;
    lastInput = input;
    profile = ClinicianRegistrationProfile(
      id: profile?.id ?? 'doctor-new',
      name: input.name,
      phoneNumber: input.phoneNumber,
      speciality: input.speciality,
      clinicId: input.clinic.id,
      clinicName: input.clinic.name,
      startTime: input.startTime,
      endTime: input.endTime,
    );
    return profile!;
  }
}
