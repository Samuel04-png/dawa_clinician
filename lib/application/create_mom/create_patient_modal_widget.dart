import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class CreatePatientModalResult {
  const CreatePatientModalResult._({
    this.created = false,
    this.existingPatientReference,
  });

  final bool created;
  final DocumentReference? existingPatientReference;

  const CreatePatientModalResult.created()
      : this._(created: true, existingPatientReference: null);

  const CreatePatientModalResult.openExisting(
    DocumentReference patientReference,
  ) : this._(created: false, existingPatientReference: patientReference);
}

class CreatePatientModalWidget extends StatefulWidget {
  const CreatePatientModalWidget({super.key});

  @override
  State<CreatePatientModalWidget> createState() =>
      _CreatePatientModalWidgetState();
}

class _CreatePatientModalWidgetState extends State<CreatePatientModalWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _nrcController = TextEditingController();
  final _addressController = TextEditingController();
  final _villageController = TextEditingController();
  final _clinicController = TextEditingController();
  final _occupationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _datePicked;
  bool _saving = false;
  bool _submitted = false;
  bool _success = false;
  bool _duplicateOverride = false;
  String? _errorMessage;
  List<_PatientDuplicate> _duplicateCandidates = const [];

  @override
  void dispose() {
    _nameController.dispose();
    _patientIdController.dispose();
    _nrcController.dispose();
    _addressController.dispose();
    _villageController.dispose();
    _clinicController.dispose();
    _occupationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePicked ?? DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _datePicked = DateTime(picked.year, picked.month, picked.day);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submit({bool skipDuplicateCheck = false}) async {
    if (_saving || _success) return;

    setState(() {
      _submitted = true;
      _errorMessage = null;
      if (!skipDuplicateCheck) {
        _duplicateCandidates = const [];
        _duplicateOverride = false;
      }
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _datePicked == null) {
      setState(() {
        _errorMessage = 'Some required information is missing.';
      });
      return;
    }

    setState(() => _saving = true);

    try {
      if (!skipDuplicateCheck && !_duplicateOverride) {
        final duplicates = await _findDuplicatePatients();
        if (duplicates.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _saving = false;
            _duplicateCandidates = duplicates;
            _errorMessage = null;
          });
          return;
        }
      }

      final generatedPassword = _passwordController.text.trim().isEmpty
          ? functions.generateCustomPassword()
          : _passwordController.text.trim();
      final email = _emailController.text.trim().isEmpty
          ? functions.createUniqueEmail(
              _nameController.text.trim(),
              _datePicked!,
              _phoneController.text.trim(),
            )
          : _emailController.text.trim();

      FFAppState().motherCreatedTime = getCurrentTimestamp;
      FFAppState().randomPasswordGenerated = generatedPassword;
      GoRouter.of(context).prepareAuthEvent();

      final user = await authManager.createAccountWithEmail(
        context,
        email,
        generatedPassword,
      );
      if (user == null) {
        throw const _PatientSaveException(
          'Unable to create the patient account. Please check your internet connection and try again.',
        );
      }

      await UserRecord.collection.doc(user.uid).update(
            createUserRecordData(
              role: 'Mother',
              createdTime: FFAppState().motherCreatedTime,
            ),
          );

      final patientReference = MotherRecord.collection.doc();
      final chosenPatientId = _patientIdController.text.trim().isNotEmpty
          ? _patientIdController.text.trim()
          : patientReference.id;

      await patientReference.set(
        createMotherRecordData(
          dateOfBirth: _datePicked,
          occupation: _occupationController.text.trim(),
          address: _addressController.text.trim(),
          village: _villageController.text.trim(),
          clinicName: _clinicController.text.trim(),
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          motherId: chosenPatientId,
          nrc: _nrcController.text.trim(),
        ),
      );

      final createdUser = await queryUserRecordOnce(
        queryBuilder: (userRecord) => userRecord.where(
          'created_time',
          isEqualTo: FFAppState().motherCreatedTime,
        ),
        singleRecord: true,
      ).then((s) => s.firstOrNull);

      await patientReference.update(
        createMotherRecordData(
          userId: createdUser?.reference,
        ),
      );

      await SendSMSCall.call(
        email: createdUser?.email,
        password: generatedPassword,
        number: _phoneController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _success = true;
        _saving = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop(const CreatePatientModalResult.created());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  Future<List<_PatientDuplicate>> _findDuplicatePatients() async {
    final records = <String, MotherRecord>{};

    Future<void> collect(Query Function(Query) queryBuilder) async {
      try {
        final matches = await queryMotherRecordOnce(
          queryBuilder: (query) =>
              queryBuilder(query).where('source_deleted_at', isNull: true),
          limit: 25,
        );
        for (final match in matches) {
          records[match.reference.path] = match;
        }
      } catch (_) {
        // Duplicate checks should not block registration when a target schema
        // has not yet received the newest optional identifier columns.
      }
    }

    final phone = _phoneController.text.trim();
    final patientId = _patientIdController.text.trim();
    final nrc = _nrcController.text.trim();

    if (phone.isNotEmpty) {
      await collect((query) => query.where('phone_number', isEqualTo: phone));
    }
    if (patientId.isNotEmpty) {
      await collect((query) => query.where('mother_id', isEqualTo: patientId));
      await collect(
        (query) => query.where('source_mother_id', isEqualTo: patientId),
      );
    }
    if (nrc.isNotEmpty) {
      await collect((query) => query.where('nrc', isEqualTo: nrc));
    }

    try {
      final recent = await queryMotherRecordOnce(
        queryBuilder: (query) => query.where('source_deleted_at', isNull: true),
        limit: 500,
      );
      for (final record in recent) {
        if (_looksLikeDuplicate(record)) {
          records[record.reference.path] = record;
        }
      }
    } catch (_) {
      // The exact indexed checks above are still useful if the broad fallback
      // cannot run in a constrained environment.
    }

    return records.values
        .map((record) => _PatientDuplicate(
              record: record,
              reasons: _duplicateReasons(record),
            ))
        .where((duplicate) => duplicate.reasons.isNotEmpty)
        .toList();
  }

  bool _looksLikeDuplicate(MotherRecord record) {
    return _duplicateReasons(record).isNotEmpty;
  }

  List<String> _duplicateReasons(MotherRecord record) {
    final reasons = <String>[];
    final inputPatientId = _patientIdController.text.trim().toLowerCase();
    final inputNrc = _nrcController.text.trim().toLowerCase();
    final inputPhone = _localPhoneDigits(_phoneController.text);
    final inputName = _normalizeText(_nameController.text);
    final inputDob = _datePicked;

    if (inputPatientId.isNotEmpty &&
        (record.motherId.toLowerCase() == inputPatientId ||
            record.sourceMotherId.toLowerCase() == inputPatientId ||
            record.reference.id.toLowerCase() == inputPatientId)) {
      reasons.add('same patient ID');
    }
    if (inputNrc.isNotEmpty && record.nrc.toLowerCase() == inputNrc) {
      reasons.add('same NRC');
    }
    if (inputPhone.isNotEmpty &&
        _localPhoneDigits(record.phoneNumber) == inputPhone) {
      reasons.add('same phone number');
    }
    if (inputName.isNotEmpty &&
        inputDob != null &&
        _normalizeText(record.name) == inputName &&
        record.dateOfBirth != null &&
        _sameDate(record.dateOfBirth!, inputDob)) {
      reasons.add('same name and date of birth');
    }

    return reasons;
  }

  String? _requiredTextValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Phone number is required';
    }
    if (_localPhoneDigits(text).length != 10) {
      return 'Phone number must contain 10 digits';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final emailLike = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailLike.hasMatch(text)) {
      return 'Enter a valid email address or leave it blank';
    }
    return null;
  }

  String? _patientIdValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length < 3) {
      return 'Patient ID must be at least 3 characters';
    }
    return null;
  }

  String? _nrcValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length < 4) {
      return 'NRC must be at least 4 characters';
    }
    return null;
  }

  String _friendlyErrorMessage(Object error) {
    if (error is _PatientSaveException) return error.message;
    final text = error.toString().toLowerCase();
    if (text.contains('network') ||
        text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('connection')) {
      return 'Unable to save patient. Please check your internet connection.';
    }
    if (text.contains('duplicate') || text.contains('already exists')) {
      return 'This patient may already exist. Review the matching record before continuing.';
    }
    if (text.contains('required') || text.contains('invalid')) {
      return 'Some required information is missing.';
    }
    return 'Unable to save patient. Please check the details and try again.';
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _localPhoneDigits(String value) {
    final digits = _digitsOnly(value);
    if (digits.startsWith('260') && digits.length == 12) {
      return '0${digits.substring(3)}';
    }
    if (digits.startsWith('260') && digits.length == 11) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  String _normalizeText(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  bool _fieldHasError(
      TextEditingController controller, String? Function(String?) validator) {
    if (!_submitted) return false;
    return validator(controller.text) != null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 640.0;

    return SafeArea(
      child: Dialog(
        insetPadding: EdgeInsets.all(isCompact ? 14.0 : 24.0),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isCompact ? 20.0 : 28.0),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680.0,
            maxHeight: size.height * 0.9,
          ),
          child: Material(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _success
                  ? _buildSuccessState(context)
                  : _buildFormState(context, isCompact),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState(BuildContext context, bool isCompact) {
    return Column(
      key: const ValueKey('create-patient-form-state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 18 : 24,
              20,
              isCompact ? 18 : 24,
              20,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(context, _errorMessage!),
                    const SizedBox(height: 14),
                  ],
                  if (_duplicateCandidates.isNotEmpty) ...[
                    _buildDuplicateWarning(context),
                    const SizedBox(height: 14),
                  ],
                  _sectionLabel('Required patient details'),
                  const SizedBox(height: 10),
                  _buildField(
                    controller: _nameController,
                    label: 'Patient Name',
                    hint: 'Janet Zulu',
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        _requiredTextValidator(value, 'Patient name'),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    hint: '0970000000',
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                    ],
                    validator: _phoneValidator,
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(context),
                  const SizedBox(height: 18),
                  _sectionLabel('Identifiers for duplicate checks'),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _patientIdController,
                          label: 'Patient ID',
                          hint: 'Optional',
                          textInputAction: TextInputAction.next,
                          requiredField: false,
                          validator: _patientIdValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _nrcController,
                          label: 'NRC',
                          hint: 'Optional',
                          textInputAction: TextInputAction.next,
                          requiredField: false,
                          validator: _nrcValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionLabel('Clinic context'),
                  const SizedBox(height: 10),
                  _buildField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Libala Stage 1, Lusaka',
                    textInputAction: TextInputAction.next,
                    requiredField: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _villageController,
                          label: 'Village / Area',
                          hint: 'Optional',
                          textInputAction: TextInputAction.next,
                          requiredField: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _clinicController,
                          label: 'Clinic',
                          hint: 'Optional',
                          textInputAction: TextInputAction.next,
                          requiredField: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _occupationController,
                    label: 'Occupation',
                    hint: 'Trader',
                    textInputAction: TextInputAction.next,
                    requiredField: false,
                  ),
                  const SizedBox(height: 18),
                  _sectionLabel('Account setup'),
                  const SizedBox(height: 10),
                  _buildField(
                    controller: _emailController,
                    label: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    hint: 'Optional - leave blank to auto-generate',
                    textInputAction: TextInputAction.next,
                    requiredField: false,
                    validator: _emailValidator,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: true,
                    hint: 'Optional - leave blank for auto-generated',
                    textInputAction: TextInputAction.done,
                    requiredField: false,
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildActions(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DawaTokens.brandPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: DawaTokens.brandPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Register New Patient',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.0,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add the patient once, check for duplicates, and return to your current workspace automatically.',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.dmSans(),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: DawaTextStyles.label.copyWith(color: DawaTokens.textSecondary),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool requiredField = true,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final effectiveValidator = validator ??
        (requiredField
            ? (value) => _requiredTextValidator(value, label)
            : (_) => null);
    final hasError = _fieldHasError(controller, effectiveValidator);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hint,
        helperText: requiredField && !hasError ? 'Required' : null,
        prefixIcon: hasError
            ? const Icon(Icons.error_outline_rounded,
                color: DawaTokens.statusDanger)
            : null,
        filled: true,
        fillColor: FlutterFlowTheme.of(context).primaryBackground,
        border: _fieldBorder(FlutterFlowTheme.of(context).alternate),
        enabledBorder: _fieldBorder(
          hasError
              ? DawaTokens.statusDanger
              : FlutterFlowTheme.of(context).alternate,
        ),
        focusedBorder: _fieldBorder(
          hasError
              ? DawaTokens.statusDanger
              : FlutterFlowTheme.of(context).primary,
        ),
        errorBorder: _fieldBorder(DawaTokens.statusDanger),
        focusedErrorBorder: _fieldBorder(DawaTokens.statusDanger),
      ),
      validator: effectiveValidator,
      onChanged: (_) {
        if (_duplicateCandidates.isNotEmpty || _errorMessage != null) {
          setState(() {
            _duplicateCandidates = const [];
            _duplicateOverride = false;
            _errorMessage = null;
          });
        } else if (_submitted) {
          setState(() {});
        }
      },
    );
  }

  OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: color, width: 1.4),
    );
  }

  Widget _buildDateField(BuildContext context) {
    final hasError = _submitted && _datePicked == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saving ? null : _pickDob,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? DawaTokens.statusDanger
                    : FlutterFlowTheme.of(context).alternate,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasError
                      ? Icons.error_outline_rounded
                      : Icons.calendar_month_rounded,
                  color: hasError
                      ? DawaTokens.statusDanger
                      : FlutterFlowTheme.of(context).secondaryText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _datePicked == null
                        ? 'Date of Birth *'
                        : dateTimeFormat('yMMMd', _datePicked),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.dmSans(),
                          color: _datePicked == null
                              ? FlutterFlowTheme.of(context).secondaryText
                              : FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
          child: Text(
            hasError ? 'Date of Birth cannot be empty' : 'Required',
            style: GoogleFonts.dmSans(
              color: hasError
                  ? DawaTokens.statusDanger
                  : FlutterFlowTheme.of(context).secondaryText,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateWarning(BuildContext context) {
    final first = _duplicateCandidates.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DawaTokens.statusWarningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DawaTokens.statusWarning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: DawaTokens.statusWarningText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This patient may already exist.',
                  style: DawaTextStyles.cardTitle.copyWith(
                    color: DawaTokens.statusWarningText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${first.record.name.isEmpty ? 'Existing patient' : first.record.name} matches by ${first.reasons.join(', ')}.',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.statusWarningText,
            ),
          ),
          if (_duplicateCandidates.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              '${_duplicateCandidates.length} possible matches found.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusWarningText,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(
                          CreatePatientModalResult.openExisting(
                            first.record.reference,
                          ),
                        ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open Existing Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DawaTokens.statusWarning,
                  foregroundColor: DawaTokens.textInverse,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _duplicateOverride = true;
                          _duplicateCandidates = const [];
                        });
                        _submit(skipDuplicateCheck: true);
                      },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continue Anyway'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DawaTokens.statusDangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DawaTokens.statusDanger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: DawaTokens.statusDangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusDangerText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => _submit(skipDuplicateCheck: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DawaTokens.textInverse,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(_saving ? 'Checking...' : 'Create Patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DawaTokens.brandPrimary,
                foregroundColor: DawaTokens.textInverse,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Padding(
      key: const ValueKey('create-patient-success-state'),
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: DawaTokens.statusSuccessBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: DawaTokens.statusSuccessText,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Patient Added Successfully',
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).headlineSmall.override(
                  font: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'The patient list will refresh automatically.',
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.dmSans(),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
        ],
      ),
    );
  }
}

class _PatientDuplicate {
  const _PatientDuplicate({
    required this.record,
    required this.reasons,
  });

  final MotherRecord record;
  final List<String> reasons;
}

class _PatientSaveException implements Exception {
  const _PatientSaveException(this.message);

  final String message;
}
