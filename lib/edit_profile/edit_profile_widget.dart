import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/components/dawa_design_system.dart';
import '/components/navigation_design_system.dart';
import '/components/clinical_navigation_shell.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'edit_profile_model.dart';
export 'edit_profile_model.dart';

class EditProfileWidget extends StatefulWidget {
  const EditProfileWidget({super.key});
  static String routeName = 'EditProfile';
  static String routePath = '/editProfile';
  @override
  State<EditProfileWidget> createState() => _EditProfileWidgetState();
}

class _EditProfileWidgetState extends State<EditProfileWidget> {
  late EditProfileModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialityController = TextEditingController();
  String? _startTime;
  String? _endTime;
  String? _initialFingerprint;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditProfileModel());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specialityController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final doctorRef = FFAppState().doctor;
    if (doctorRef == null) return _missingProfile(context);
    return StreamBuilder<DoctorRecord>(
      stream: DoctorRecord.getDocument(doctorRef),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final doctor = snapshot.data!;
        _seed(doctor);
        return _shell(context, doctor);
      },
    );
  }

  void _seed(DoctorRecord doctor) {
    if (_initialFingerprint != null) return;
    _nameController.text = doctor.name;
    _phoneController.text = doctor.phoneNumber;
    _specialityController.text = doctor.speciality;
    _startTime = doctor.startTime.isEmpty ? null : doctor.startTime;
    _endTime = doctor.endTime.isEmpty ? null : doctor.endTime;
    _initialFingerprint = _fingerprint();
  }

  Widget _shell(BuildContext context, DoctorRecord doctor) =>
      ClinicalNavigationShell(
          child: _content(
              context,
              doctor,
              MediaQuery.sizeOf(context).width >=
                  NavigationTokens.desktopBreakpoint));

  Widget _content(BuildContext context, DoctorRecord doctor, bool desktop) =>
      SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(24, desktop ? 28 : 20, 24, desktop ? 36 : 100),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconButton(
                          tooltip: 'Back to settings',
                          onPressed: _cancel,
                          icon: const Icon(Icons.arrow_back_rounded)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Edit profile',
                                style: DawaTextStyles.pageTitle),
                            const SizedBox(height: 4),
                            Text(
                                'Update the details used in your clinician workspace.',
                                style: DawaTextStyles.secondary
                                    .copyWith(color: DawaTokens.textSecondary)),
                          ])),
                    ]),
                    const SizedBox(height: 24),
                    _card(
                        'Personal information',
                        'These details identify you to the clinical workspace.',
                        [
                          _field(
                              controller: _nameController,
                              label: 'Full name',
                              hint: 'Enter your full name',
                              capitalization: TextCapitalization.words,
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty)
                                  return 'Enter your full name.';
                                if (name.length < 2)
                                  return 'Your name must contain at least 2 characters.';
                                return null;
                              }),
                          const SizedBox(height: 16),
                          _field(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: 'Enter a contact number',
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final phone = value?.trim() ?? '';
                                if (phone.isEmpty)
                                  return 'Enter a phone number.';
                                if (phone.length < 10)
                                  return 'Enter a phone number with at least 10 digits.';
                                return null;
                              }),
                        ]),
                    const SizedBox(height: 16),
                    _card(
                        'Professional information',
                        'Only fields supported by your existing clinician profile can be updated here.',
                        [
                          _field(
                              controller: _specialityController,
                              label: 'Clinical speciality',
                              hint: 'Enter your speciality',
                              capitalization: TextCapitalization.words,
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? 'Enter your clinical speciality.'
                                      : null),
                          const SizedBox(height: 16),
                          LayoutBuilder(builder: (context, constraints) {
                            final start = _timeField(
                                label: 'Start time',
                                value: _startTime,
                                options: functions.getTimes(),
                                onChanged: (value) => setState(() {
                                      _startTime = value;
                                      if (_endTime != null &&
                                          !_endOptions.contains(_endTime))
                                        _endTime = null;
                                    }));
                            final end = _timeField(
                                label: 'End time',
                                value: _endTime,
                                options: _endOptions,
                                onChanged: (value) =>
                                    setState(() => _endTime = value));
                            if (constraints.maxWidth < 560)
                              return Column(children: [
                                start,
                                const SizedBox(height: 16),
                                end
                              ]);
                            return Row(children: [
                              Expanded(child: start),
                              const SizedBox(width: 16),
                              Expanded(child: end)
                            ]);
                          }),
                        ]),
                    const SizedBox(height: 16),
                    _card(
                        'Account information',
                        'These values are managed by your authenticated account and cannot be edited here.',
                        [
                          _readOnlyRow(
                              'Email',
                              currentUserEmail.isEmpty
                                  ? 'Not available'
                                  : currentUserEmail),
                          if (doctor.clinicName.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _readOnlyRow('Organization', doctor.clinicName)
                          ],
                        ]),
                    const SizedBox(height: 24),
                    Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          TextButton(
                              onPressed: _saving ? null : _cancel,
                              child: const Text('Cancel')),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _saving ? null : () => _save(doctor),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(_saving ? 'Saving…' : 'Save changes'),
                          ),
                        ]),
                  ]),
            ),
          ),
        ),
      );

  List<String> get _endOptions {
    if (_startTime == null) return const [];
    return functions.getEndTimes(_startTime!) ?? const [];
  }

  Widget _card(String title, String description, List<Widget> children) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: DawaTokens.surface,
            border: Border.all(color: DawaTokens.border),
            borderRadius: BorderRadius.circular(DawaTokens.radiusLg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: DawaTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(description,
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary)),
          const SizedBox(height: 18),
          ...children,
        ]),
      );

  Widget _field(
          {required TextEditingController controller,
          required String label,
          required String hint,
          required String? Function(String?) validator,
          TextInputType? keyboardType,
          TextCapitalization capitalization = TextCapitalization.none}) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder()),
      );

  Widget _timeField(
          {required String label,
          required String? value,
          required List<String> options,
          required ValueChanged<String?> onChanged}) =>
      DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        hint: Text(
            options.isEmpty ? 'Choose a start time first' : 'Select $label'),
        items: options
            .map((option) =>
                DropdownMenuItem(value: option, child: Text(option)))
            .toList(),
        onChanged: options.isEmpty ? null : onChanged,
      );

  Widget _readOnlyRow(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: DawaTextStyles.label.copyWith(color: DawaTokens.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: DawaTextStyles.body.copyWith(color: DawaTokens.textPrimary)),
      ]);

  Future<void> _save(DoctorRecord doctor) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select both start and end times.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await doctor.reference.update(createDoctorRecordData(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        speciality: _specialityController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
      ));
      if (!mounted) return;
      _initialFingerprint = _fingerprint();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
      context.goNamed(ProfileWidget.routeName);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Unable to update your profile. Your changes are still here; please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (_changed) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Discard profile changes?'),
                content:
                    const Text('Your unsaved profile changes will be lost.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Keep editing')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Discard'))
                ],
              ));
      if (discard != true || !mounted) return;
    }
    context.goNamed(ProfileWidget.routeName);
  }

  bool get _changed =>
      _initialFingerprint != null && _fingerprint() != _initialFingerprint;
  String _fingerprint() =>
      '${_nameController.text}\u0000${_phoneController.text}\u0000${_specialityController.text}\u0000${_startTime ?? ''}\u0000${_endTime ?? ''}';

  Widget _missingProfile(BuildContext context) => Scaffold(
        backgroundColor: NavigationTokens.canvas,
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: DawaTokens.statusWarning, size: 44),
                  const SizedBox(height: 14),
                  Text('Profile unavailable offline',
                      style: DawaTextStyles.cardTitle.copyWith(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                      'Log in online once so Dawa can load your clinician profile.',
                      textAlign: TextAlign.center,
                      style: DawaTextStyles.secondary),
                  const SizedBox(height: 16),
                  TextButton.icon(
                      onPressed: () => context.goNamed(ProfileWidget.routeName),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to Settings')),
                ]))),
      );
}
