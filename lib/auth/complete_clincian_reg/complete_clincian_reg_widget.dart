import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clinician_registration_repository.dart';

export 'clinician_registration_repository.dart';

class CompleteClincianRegWidget extends StatefulWidget {
  const CompleteClincianRegWidget({
    super.key,
    this.repository,
    this.onBack,
    this.onCompleted,
  });

  static String routeName = 'CompleteClincianReg';
  static String routePath = '/completeClincianReg';

  final ClinicianRegistrationRepository? repository;
  final Future<void> Function()? onBack;
  final void Function(ClinicianRegistrationProfile profile)? onCompleted;

  @override
  State<CompleteClincianRegWidget> createState() =>
      _CompleteClincianRegWidgetState();
}

class _CompleteClincianRegWidgetState extends State<CompleteClincianRegWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+260');
  final _specialityController = TextEditingController();

  late final ClinicianRegistrationRepository _repository;

  ClinicianRegistrationProfile? _profile;
  List<ClinicOption> _clinics = const [];
  String? _selectedClinicId;
  String? _selectedStartTime;
  String? _selectedEndTime;
  String? _profileError;
  String? _clinicError;
  String? _submissionError;
  bool _isInitialLoading = true;
  bool _isLoadingClinics = false;
  bool _isSubmitting = false;
  bool _hasNavigated = false;

  List<String> get _startTimes => functions
      .getTimes()
      .where((time) => _endTimesFor(time).isNotEmpty)
      .toList(growable: false);

  List<String> get _endTimes =>
      _selectedStartTime == null ? const [] : _endTimesFor(_selectedStartTime!);

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? SupabaseClinicianRegistrationRepository();
    _loadRegistration();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specialityController.dispose();
    super.dispose();
  }

  Future<void> _loadRegistration() async {
    debugPrint('[Registration] Opening Complete registration.');
    ClinicianRegistrationProfile? profile;
    String? profileError;
    List<ClinicOption> clinics = const [];
    String? clinicError;

    try {
      profile = await _repository.loadProfile();
    } catch (error) {
      profileError = _messageFor(error);
    }

    try {
      clinics = await _repository.loadClinics();
      if (clinics.isEmpty) {
        clinicError =
            'No clinics are available yet. Please retry or contact an administrator.';
      }
    } catch (error) {
      clinicError = _messageFor(error);
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileError = profileError;
      _clinics = clinics;
      _clinicError = clinicError;
      _isInitialLoading = false;
      if (profile != null) {
        _nameController.text = profile.name;
        _phoneController.text =
            profile.phoneNumber.isEmpty ? '+260' : profile.phoneNumber;
        _specialityController.text = profile.speciality;
        _selectedClinicId = clinics.any((item) => item.id == profile!.clinicId)
            ? profile.clinicId
            : null;
        _selectedStartTime =
            _startTimes.contains(profile.startTime) ? profile.startTime : null;
        _selectedEndTime =
            _endTimes.contains(profile.endTime) ? profile.endTime : null;
      }
    });

    if (profile?.isComplete ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishRegistration(profile!, showConfirmation: false);
      });
    }
  }

  Future<void> _retryProfile() async {
    setState(() {
      _isInitialLoading = true;
      _profileError = null;
    });
    await _loadRegistration();
  }

  Future<void> _retryClinics() async {
    setState(() {
      _isLoadingClinics = true;
      _clinicError = null;
    });
    try {
      final clinics = await _repository.loadClinics();
      if (!mounted) return;
      setState(() {
        _clinics = clinics;
        _clinicError = clinics.isEmpty
            ? 'No clinics are available yet. Please retry or contact an administrator.'
            : null;
        _isLoadingClinics = false;
        if (!_clinics.any((item) => item.id == _selectedClinicId)) {
          _selectedClinicId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clinicError = _messageFor(error);
        _isLoadingClinics = false;
      });
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submissionError = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('[Registration] Validation stopped registration submission.');
      return;
    }

    final clinic = _clinics.cast<ClinicOption?>().firstWhere(
          (item) => item?.id == _selectedClinicId,
          orElse: () => null,
        );
    if (clinic == null ||
        _selectedStartTime == null ||
        _selectedEndTime == null ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = await _repository.completeRegistration(
        ClinicianRegistrationInput(
          name: _nameController.text,
          phoneNumber: _phoneController.text,
          speciality: _specialityController.text,
          clinic: clinic,
          startTime: _selectedStartTime!,
          endTime: _selectedEndTime!,
        ),
      );
      if (!mounted) return;
      await _finishRegistration(profile, showConfirmation: true);
    } catch (error) {
      if (!mounted) return;
      final message = _messageFor(error);
      debugPrint('[Registration] Submission remained on page: $message');
      setState(() {
        _submissionError = message;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _finishRegistration(
    ClinicianRegistrationProfile profile, {
    required bool showConfirmation,
  }) async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    FFAppState().doctor = DoctorRecord.collection.doc(profile.id);
    debugPrint('[Registration] Clinician session profile refreshed.');

    if (showConfirmation) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Registration complete. Opening your dashboard…'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    if (widget.onCompleted != null) {
      widget.onCompleted!(profile);
      return;
    }

    debugPrint('[Registration] Navigating to the clinician dashboard.');
    context.goNamed(
      HomeWidget.routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration(milliseconds: 180),
        ),
      },
    );
  }

  Future<void> _goBack() async {
    if (_isSubmitting) return;
    debugPrint('[Registration] Leaving Complete registration.');
    if (widget.onBack != null) {
      await widget.onBack!();
      return;
    }
    await authManager.signOut();
    if (!mounted) return;
    context.goNamed(LoginWidget.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showArtwork = constraints.maxWidth >= 960;
            return Row(
              children: [
                Expanded(
                  flex: showArtwork ? 7 : 1,
                  child: _buildFormPane(context),
                ),
                if (showArtwork)
                  Expanded(
                    flex: 5,
                    child: Semantics(
                      label: 'Dawa Clinician registration artwork',
                      image: true,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/bg.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormPane(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                if (_isInitialLoading)
                  const _RegistrationLoadingCard()
                else if (_profileError != null)
                  _ErrorCard(
                    key: const Key('profile-load-error'),
                    title: 'Could not load your clinician profile',
                    message: _profileError!,
                    onRetry: _retryProfile,
                  )
                else
                  _buildForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 400;
        return Row(
          children: [
            TextButton.icon(
              key: const Key('registration-back-button'),
              onPressed: _isSubmitting ? null : _goBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(compact ? 'Back' : 'Back to sign in'),
            ),
            const Spacer(),
            Image.asset(
              'assets/images/trasnsparent assets/Logos-06-removebg-preview.png',
              width: compact ? 88 : 112,
              height: 64,
              fit: BoxFit.contain,
              semanticLabel: 'Dawa Health',
            ),
          ],
        );
      },
    );
  }

  Widget _buildForm() {
    return Material(
      color: DawaTokens.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(DawaTokens.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Complete registration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: DawaTokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your clinical details to finish setting up your account. Fields marked * are required.',
                style: TextStyle(color: DawaTokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('registration-name-field'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _fieldDecoration('Name *', 'e.g. Timothy Phiri'),
                validator: (value) => _required(value, 'Enter your full name.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('registration-phone-field'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: _fieldDecoration(
                  'Phone number *',
                  '+260971234567',
                  helperText: 'Use Zambia’s +260 format followed by 9 digits.',
                ),
                validator: (value) {
                  final requiredMessage =
                      _required(value, 'Enter your phone number.');
                  if (requiredMessage != null) return requiredMessage;
                  if (!RegExp(r'^\+260\d{9}$').hasMatch(value!.trim())) {
                    return 'Enter a valid Zambia number, for example +260971234567.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('registration-speciality-field'),
                controller: _specialityController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration:
                    _fieldDecoration('Specialty *', 'e.g. General Practice'),
                validator: (value) =>
                    _required(value, 'Enter your clinical specialty.'),
              ),
              const SizedBox(height: 16),
              _buildClinicField(),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('registration-start-time-field'),
                value: _selectedStartTime,
                isExpanded: true,
                decoration:
                    _fieldDecoration('Start time *', 'Select a start time'),
                items: _startTimes
                    .map((time) =>
                        DropdownMenuItem(value: time, child: Text(time)))
                    .toList(growable: false),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedStartTime = value;
                          if (!_endTimes.contains(_selectedEndTime)) {
                            _selectedEndTime = null;
                          }
                        });
                      },
                validator: (value) =>
                    value == null ? 'Select your clinic start time.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('registration-end-time-field'),
                value: _selectedEndTime,
                isExpanded: true,
                decoration:
                    _fieldDecoration('End time *', 'Select an end time'),
                items: _endTimes
                    .map((time) =>
                        DropdownMenuItem(value: time, child: Text(time)))
                    .toList(growable: false),
                onChanged: _isSubmitting || _selectedStartTime == null
                    ? null
                    : (value) => setState(() => _selectedEndTime = value),
                validator: (value) =>
                    value == null ? 'Select your clinic end time.' : null,
              ),
              if (_submissionError != null) ...[
                const SizedBox(height: 16),
                _InlineError(
                  key: const Key('registration-submit-error'),
                  message: _submissionError!,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: const Key('registration-continue-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: DawaTokens.brandPrimary,
                    foregroundColor: DawaTokens.textInverse,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClinicField() {
    if (_isLoadingClinics) {
      return const _ClinicLoadingField();
    }
    if (_clinicError != null) {
      return _ErrorCard(
        key: const Key('clinic-load-error'),
        title: 'Clinics could not be loaded',
        message: _clinicError!,
        onRetry: _retryClinics,
        compact: true,
      );
    }
    return DropdownButtonFormField<String>(
      key: const Key('registration-clinic-field'),
      value: _selectedClinicId,
      isExpanded: true,
      decoration: _fieldDecoration('Clinic *', 'Select a clinic'),
      items: _clinics
          .map(
            (clinic) => DropdownMenuItem(
              value: clinic.id,
              child: Text(
                clinic.address == null
                    ? clinic.name
                    : '${clinic.name} — ${clinic.address}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: _isSubmitting
          ? null
          : (value) => setState(() => _selectedClinicId = value),
      validator: (value) => value == null ? 'Select your clinic.' : null,
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    String hint, {
    String? helperText,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        helperMaxLines: 2,
        filled: true,
        fillColor: DawaTokens.surfaceSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        ),
      );

  List<String> _endTimesFor(String startTime) {
    final startMinutes = _timeInMinutes(startTime);
    return (functions.getEndTimes(startTime) ?? const <String>[])
        .where((time) => _timeInMinutes(time) > startMinutes)
        .toList(growable: false);
  }

  int _timeInMinutes(String value) {
    final parts = value.split(':');
    return int.parse(parts.first) * 60 + int.parse(parts.last);
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  String _messageFor(Object error) => error is ClinicianRegistrationException
      ? error.message
      : 'Something went wrong. Please try again.';
}

class _RegistrationLoadingCard extends StatelessWidget {
  const _RegistrationLoadingCard();

  @override
  Widget build(BuildContext context) => Material(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(DawaTokens.radiusXl),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your registration details…'),
            ],
          ),
        ),
      );
}

class _ClinicLoadingField extends StatelessWidget {
  const _ClinicLoadingField();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('clinic-loading-indicator'),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: DawaTokens.surfaceSecondary,
          border: Border.all(color: DawaTokens.border),
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading clinics…'),
          ],
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DawaTokens.statusDanger.withValues(alpha: 0.08),
          border: Border.all(
            color: DawaTokens.statusDanger.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: DawaTokens.statusDanger,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: DawaTokens.statusDanger),
              ),
            ),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: DawaTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(color: DawaTokens.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('registration-retry-button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
