import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/components/clinical_workspace_components.dart';
import '/components/dawa_design_system.dart';
import '/components/navigation_design_system.dart';

class BpMonitorApp extends StatefulWidget {
  const BpMonitorApp({super.key, this.now});

  final DateTime Function()? now;

  static String routeName = 'BpMonitor';
  static String routePath = '/bp-monitor';

  @override
  State<BpMonitorApp> createState() => _BpMonitorAppState();
}

class _BpMonitorAppState extends State<BpMonitorApp> {
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final FocusNode _systolicFocus = FocusNode();
  final FocusNode _diastolicFocus = FocusNode();
  final FocusNode _ageFocus = FocusNode();
  final GlobalKey _interpretationKey = GlobalKey();
  String? _validationMessage;
  String? _validationField;
  bool _entryChanged = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _patientController,
      _ageController,
      _systolicController,
      _diastolicController,
      _notesController
    ]) {
      var previousText = controller.text;
      controller.addListener(() {
        if (controller.text == previousText) return;
        previousText = controller.text;
        _onEntryChanged();
      });
    }
  }

  void _onEntryChanged() {
    setState(() {
      _validationMessage = null;
      _entryChanged = _latestInterpretation != null;
    });
  }

  bool _hasDiabetes = false;
  bool _hasKidneyDisease = false;
  bool _hasHeartDisease = false;
  bool _isPregnant = false;

  BpInterpretation? _latestInterpretation;
  final List<_BpSavedReading> _readings = [];

  @override
  void dispose() {
    _systolicFocus.dispose();
    _diastolicFocus.dispose();
    _ageFocus.dispose();
    _patientController.dispose();
    _ageController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NavigationTokens.canvas,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
          final contentWidth = (constraints.maxWidth - padding * 2)
              .clamp(0.0, DawaTokens.workspaceMaxWidth);
          final wide = contentWidth >= 700 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21;
          final input = SizedBox(
            width: wide ? (contentWidth - 20) * .54 : contentWidth,
            child: _buildInputCard(sideBySide: wide),
          );
          final review = SizedBox(
            width: wide ? (contentWidth - 20) * .46 : contentWidth,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                      liveRegion: true, child: _buildInterpretationCard()),
                  const SizedBox(height: 16),
                  _buildHistoryCard(),
                ]),
          );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: DawaTokens.workspaceMaxWidth),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ClinicalPageHeader(
                          subtitle:
                              'Enter a measured reading, review the interpretation, then repeat as needed.',
                          status: ClinicalStatusChip(label: 'Session only'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Readings stay on this page during this visit and are not saved to the patient record.',
                            style: DawaTextStyles.secondary
                                .copyWith(color: DawaTokens.textSecondary)),
                        const SizedBox(height: 20),
                        if (wide)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                input,
                                const SizedBox(width: 20),
                                review,
                              ])
                        else ...[input, const SizedBox(height: 16), review],
                      ]),
                )),
          );
        }),
      ),
    );
  }

  Widget _buildInputCard({required bool sideBySide}) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: DawaTokens.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      Text('New BP Reading', style: DawaTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final patient = TextField(
              controller: _patientController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                  label: 'Patient name',
                  icon: Icons.person_outline_rounded,
                  hint: 'Optional'),
            );
            final age = _numberField(
                controller: _ageController,
                label: 'Age',
                hint: 'Optional, in years',
                icon: Icons.cake_outlined);
            if (constraints.maxWidth >= 320 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: patient),
                    const SizedBox(width: 12),
                    Expanded(child: age),
                  ]);
            }
            return Column(children: [patient, const SizedBox(height: 12), age]);
          }),
          const SizedBox(height: 18),
          Text('Blood pressure', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text('Enter the measured systolic and diastolic values in mmHg.',
              style: DawaTextStyles.secondary),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final useRows = constraints.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21;
              final fields = [
                _measurementField(
                  controller: _systolicController,
                  label: 'Systolic',
                  helper: 'Upper reading',
                ),
                _measurementField(
                  controller: _diastolicController,
                  label: 'Diastolic',
                  helper: 'Lower reading',
                ),
              ];

              if (!useRows) {
                return Column(
                  children: fields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: field,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text('Clinical context', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text('Select all that apply to this reading.',
              style: DawaTextStyles.secondary),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _riskChip(
                label: 'Diabetes',
                selected: _hasDiabetes,
                onSelected: (value) => setState(() {
                  _hasDiabetes = value;
                  _entryChanged = _latestInterpretation != null;
                  _validationMessage = null;
                }),
              ),
              _riskChip(
                label: 'Kidney disease',
                selected: _hasKidneyDisease,
                onSelected: (value) => setState(() {
                  _hasKidneyDisease = value;
                  _entryChanged = _latestInterpretation != null;
                  _validationMessage = null;
                }),
              ),
              _riskChip(
                label: 'Heart disease',
                selected: _hasHeartDisease,
                onSelected: (value) => setState(() {
                  _hasHeartDisease = value;
                  _entryChanged = _latestInterpretation != null;
                  _validationMessage = null;
                }),
              ),
              _riskChip(
                label: 'Pregnant',
                selected: _isPregnant,
                onSelected: (value) => setState(() {
                  _isPregnant = value;
                  _entryChanged = _latestInterpretation != null;
                  _validationMessage = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Clinical notes',
              icon: Icons.notes_outlined,
              hint: 'Symptoms, medicine, or repeat reading notes',
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _analyzeReading(scrollToResult: !sideBySide),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Interpret Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DawaTokens.brandPrimary,
                  foregroundColor: DawaTokens.textInverse,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: DawaTokens.brandPrimary,
                  side: const BorderSide(color: DawaTokens.borderStrong),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _confirmClearForm,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear form'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _measurementField({
    required TextEditingController controller,
    required String label,
    required String helper,
  }) {
    return TextField(
      controller: controller,
      focusNode: label == 'Systolic' ? _systolicFocus : _diastolicFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      style: DawaTextStyles.pageTitle.copyWith(fontSize: 24),
      decoration: _inputDecoration(label: label, icon: null).copyWith(
        suffixText: 'mmHg',
        suffixStyle:
            DawaTextStyles.secondary.copyWith(color: DawaTokens.textSecondary),
        helperText: helper,
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      focusNode: _ageFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(label: label, icon: icon, hint: hint)
          .copyWith(suffixText: hint == 'mmHg' ? 'mmHg' : null),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: _validationField == label ? _validationMessage : null,
      errorMaxLines: 4,
      errorStyle:
          DawaTextStyles.secondary.copyWith(color: DawaTokens.textSecondary),
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      filled: true,
      fillColor: DawaTokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        borderSide: const BorderSide(color: DawaTokens.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        borderSide: const BorderSide(color: DawaTokens.borderStrong),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        borderSide: const BorderSide(color: DawaTokens.brandPrimary),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        borderSide:
            const BorderSide(color: DawaTokens.brandPrimary, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        borderSide:
            const BorderSide(color: DawaTokens.brandPrimary, width: 1.4),
      ),
    );
  }

  Widget _riskChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      backgroundColor: DawaTokens.surface,
      onSelected: onSelected,
      selectedColor: DawaTokens.brandPrimaryPale,
      checkmarkColor: DawaTokens.brandPrimary,
      labelStyle: DawaTextStyles.secondary.copyWith(
        color: selected ? DawaTokens.brandPrimary : DawaTokens.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? DawaTokens.brandPrimaryLight : DawaTokens.border,
      ),
    );
  }

  Widget _buildInterpretationCard({_BpSavedReading? reading}) {
    final interpretation = reading?.interpretation ?? _latestInterpretation;
    final snapshot =
        reading ?? (interpretation == null ? null : _readings.first);
    if (interpretation == null) {
      return DawaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interpretation', style: DawaTextStyles.cardTitle),
            const SizedBox(height: 12),
            ClinicalEmptyState(
              surface: false,
              icon: Icons.monitor_heart_outlined,
              title: 'No interpretation yet',
              message:
                  'Enter blood-pressure measurements and select Interpret Reading.',
              actionLabel: 'Enter a reading',
              onAction: _focusMeasurement,
            ),
          ],
        ),
      );
    }

    return DawaCard(
      urgent: interpretation.severity == BpSeverity.urgent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Interpretation',
              key: reading == null ? _interpretationKey : null,
              style: DawaTextStyles.cardTitle),
          const SizedBox(height: 12),
          Text(snapshot!.patientName, style: DawaTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(
              'Interpreted ${DateFormat.yMMMd().add_Hm().format(snapshot.recordedAt.toLocal())}',
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary)),
          const SizedBox(height: 12),
          if (reading == null && _entryChanged) ...[
            const ClinicalInlineBanner(
                tone: ClinicalBannerTone.info,
                title: 'Entry changed',
                message:
                    'This interpretation is for the previous entry. Select Interpret Reading to update it.'),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: interpretation.background,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                ),
                child: Icon(
                  interpretation.icon,
                  color: interpretation.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interpretation.title,
                      style: DawaTextStyles.cardTitle.copyWith(
                        color: interpretation.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      interpretation.readingLabel,
                      style: DawaTextStyles.pageTitle.copyWith(
                        color: DawaTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            interpretation.summary,
            style: DawaTextStyles.body.copyWith(color: DawaTokens.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: interpretation.background,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              border: Border.all(color: interpretation.color.withOpacity(0.25)),
            ),
            child: Text(
              interpretation.recommendation,
              style: DawaTextStyles.secondary.copyWith(
                color: interpretation.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...interpretation.contextNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: interpretation.color,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(note, style: DawaTextStyles.secondary),
                  ),
                ],
              ),
            ),
          ),
          if (snapshot.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Clinical notes', style: DawaTextStyles.cardTitle),
            const SizedBox(height: 4),
            Text(snapshot.notes, style: DawaTextStyles.secondary),
          ],
          const SizedBox(height: 12),
          Text('Decision support • clinician must review.',
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary)),
          if (reading == null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: _focusMeasurement,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Repeat measurement')),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: DawaTokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Recent Readings (${_readings.length})',
                      style: DawaTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 12),
          if (_readings.isEmpty) ...[
            Text(
              'Interpreted readings appear here during this visit to BP Monitor. They are not saved to permanent patient records.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _focusMeasurement,
                child: const Text('Enter first reading')),
          ] else
            Column(
              children: _readings
                  .map(
                    (reading) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _historyRow(reading),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _historyRow(_BpSavedReading reading) {
    return Semantics(
      button: true,
      hint: 'Open full session reading',
      child: InkWell(
        onTap: () => _showReading(reading),
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DawaTokens.surfaceTertiary,
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                reading.interpretation.icon,
                color: reading.interpretation.color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reading.patientName} - ${reading.interpretation.readingLabel}',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                        'Recorded ${DateFormat.yMMMd().add_Hm().format(reading.recordedAt.toLocal())}',
                        style: DawaTextStyles.secondary),
                    const SizedBox(height: 3),
                    Text(
                      reading.interpretation.title,
                      style: DawaTextStyles.secondary.copyWith(
                        color: reading.interpretation.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reading.notes.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        reading.notes,
                        style: DawaTextStyles.secondary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: DawaTokens.brandPrimary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _focusMeasurement() {
    _systolicFocus.requestFocus();
    _systolicController.selection = TextSelection(
        baseOffset: 0, extentOffset: _systolicController.text.length);
  }

  Future<void> _showReading(_BpSavedReading reading) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Session reading'),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                  child: _buildInterpretationCard(reading: reading))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );

  void _showValidation(String message, FocusNode field) {
    setState(() {
      _validationMessage = message;
      _validationField = field == _ageFocus
          ? 'Age'
          : field == _systolicFocus
              ? 'Systolic'
              : 'Diastolic';
    });
    field.requestFocus();
  }

  void _analyzeReading({required bool scrollToResult}) {
    final systolic = int.tryParse(_systolicController.text.trim());
    final diastolic = int.tryParse(_diastolicController.text.trim());
    final age = int.tryParse(_ageController.text.trim());

    if (_ageController.text.trim().isNotEmpty && (age == null || age <= 0)) {
      _showValidation(
          'Enter a valid age in years, or leave age empty.', _ageFocus);
      return;
    }

    if (systolic == null ||
        diastolic == null ||
        systolic < 50 ||
        systolic > 260 ||
        diastolic < 30 ||
        diastolic > 160) {
      final invalidSystolic =
          systolic == null || systolic < 50 || systolic > 260;
      _showValidation(
          invalidSystolic
              ? 'Enter systolic pressure from 50 to 260 mmHg.'
              : 'Enter diastolic pressure from 30 to 160 mmHg.',
          invalidSystolic ? _systolicFocus : _diastolicFocus);
      return;
    }

    if (diastolic >= systolic) {
      _showValidation(
          'Diastolic pressure should be lower than systolic.', _diastolicFocus);
      return;
    }

    final interpretation = BpInterpretation.interpret(
      systolic: systolic,
      diastolic: diastolic,
      age: age,
      hasDiabetes: _hasDiabetes,
      hasKidneyDisease: _hasKidneyDisease,
      hasHeartDisease: _hasHeartDisease,
      isPregnant: _isPregnant,
    );

    final patientName = _patientController.text.trim().isEmpty
        ? 'Unassigned patient'
        : _patientController.text.trim();

    setState(() {
      _validationMessage = null;
      _entryChanged = false;
      _latestInterpretation = interpretation;
      _readings.insert(
        0,
        _BpSavedReading(
          patientName: patientName,
          interpretation: interpretation,
          notes: _notesController.text.trim(),
          recordedAt: widget.now?.call() ?? DateTime.now(),
        ),
      );
    });
    FocusScope.of(context).unfocus();
    if (!scrollToResult) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _interpretationKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            alignment: .04,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180));
      }
    });
  }

  Future<void> _confirmClearForm() async {
    final hasContent = [
          _patientController.text,
          _ageController.text,
          _systolicController.text,
          _diastolicController.text,
          _notesController.text,
        ].any((value) => value.trim().isNotEmpty) ||
        _hasDiabetes ||
        _hasKidneyDisease ||
        _hasHeartDisease ||
        _isPregnant;
    if (!hasContent) {
      _clearForm();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear BP reading form?'),
        content: const Text(
            'This clears the current entry and interpretation. Recent session readings will remain available.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep entry')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear form')),
        ],
      ),
    );
    if (confirmed == true && mounted) _clearForm();
  }

  void _clearForm() {
    setState(() {
      _patientController.clear();
      _ageController.clear();
      _systolicController.clear();
      _diastolicController.clear();
      _notesController.clear();
      _hasDiabetes = false;
      _hasKidneyDisease = false;
      _hasHeartDisease = false;
      _isPregnant = false;
      _latestInterpretation = null;
      _entryChanged = false;
      _validationMessage = null;
    });
  }
}

enum BpSeverity { normal, caution, review, urgent }

class BpInterpretation {
  const BpInterpretation({
    required this.severity,
    required this.title,
    required this.readingLabel,
    required this.summary,
    required this.recommendation,
    required this.contextNotes,
  });

  final BpSeverity severity;
  final String title;
  final String readingLabel;
  final String summary;
  final String recommendation;
  final List<String> contextNotes;

  Color get color {
    return switch (severity) {
      BpSeverity.normal => DawaTokens.statusSuccessText,
      BpSeverity.caution => DawaTokens.statusWarningText,
      BpSeverity.review => DawaTokens.statusWarningText,
      BpSeverity.urgent => DawaTokens.statusDangerText,
    };
  }

  Color get background {
    return switch (severity) {
      BpSeverity.normal => DawaTokens.statusSuccessBg,
      BpSeverity.caution => DawaTokens.statusWarningBg,
      BpSeverity.review => DawaTokens.statusWarningBg,
      BpSeverity.urgent => DawaTokens.statusDangerBg,
    };
  }

  IconData get icon {
    return switch (severity) {
      BpSeverity.normal => Icons.check_circle_outline,
      BpSeverity.caution => Icons.info_outline_rounded,
      BpSeverity.review => Icons.report_problem_outlined,
      BpSeverity.urgent => Icons.emergency_outlined,
    };
  }

  static BpInterpretation interpret({
    required int systolic,
    required int diastolic,
    required int? age,
    required bool hasDiabetes,
    required bool hasKidneyDisease,
    required bool hasHeartDisease,
    required bool isPregnant,
  }) {
    var severity = BpSeverity.normal;
    var title = 'Normal blood pressure';
    var summary =
        'The reading is within the usual adult target range for routine monitoring.';
    var recommendation =
        'Continue routine monitoring and document the reading in the patient record.';

    final highRisk = hasDiabetes || hasKidneyDisease || hasHeartDisease;
    final olderAdult = age != null && age >= 65;
    final readingLabel = '$systolic/$diastolic mmHg';

    if (systolic >= 180 || diastolic >= 120) {
      severity = BpSeverity.urgent;
      title = 'Hypertensive crisis range';
      summary =
          'This BP is in a crisis range and can indicate immediate cardiovascular risk.';
      recommendation =
          'Repeat after 5 minutes. If still very high or symptoms are present, arrange urgent medical review.';
    } else if (isPregnant && (systolic >= 160 || diastolic >= 110)) {
      severity = BpSeverity.urgent;
      title = 'Severe hypertension in pregnancy range';
      summary =
          'This reading is severe for pregnancy and needs urgent clinical assessment.';
      recommendation =
          'Repeat promptly, check symptoms, and escalate for urgent maternal review.';
    } else if (systolic < 90 || diastolic < 60) {
      severity = BpSeverity.review;
      title = 'Low blood pressure';
      summary =
          'This reading is low and should be interpreted with symptoms, hydration, medicines, and pregnancy status.';
      recommendation =
          'Assess dizziness, fainting, bleeding, dehydration, and medicine effects. Repeat and review if symptomatic.';
    } else if (systolic >= 140 || diastolic >= 90) {
      severity = BpSeverity.review;
      title = isPregnant
          ? 'Hypertension in pregnancy range'
          : 'Stage 2 hypertension range';
      summary =
          'This reading is above the usual threshold for hypertension and should not be ignored.';
      recommendation =
          'Repeat after rest, document the result, and plan clinician review or treatment adjustment.';
    } else if (systolic >= 130 || diastolic >= 80) {
      severity = highRisk ? BpSeverity.review : BpSeverity.caution;
      title =
          highRisk ? 'Above high-risk BP target' : 'Stage 1 hypertension range';
      summary = highRisk
          ? 'Because the patient has diabetes, kidney disease, or heart disease, this reading crosses a lower review threshold.'
          : 'This reading is mildly raised and should be followed over repeated measurements.';
      recommendation = highRisk
          ? 'Repeat the reading and review cardiovascular risk, medicines, and follow-up timing.'
          : 'Repeat on another day, review lifestyle risks, and monitor trends.';
    } else if (systolic >= 120 && diastolic < 80) {
      severity = BpSeverity.caution;
      title = 'Elevated systolic blood pressure';
      summary =
          'The systolic value is elevated while the diastolic value remains below 80.';
      recommendation =
          'Repeat during routine care and reinforce lifestyle and risk-factor review.';
    }

    final contextNotes = <String>[
      'Reading recorded as $readingLabel.',
      if (age != null)
        olderAdult
            ? 'Age $age: check for dizziness or postural symptoms before intensifying treatment.'
            : 'Age $age included in the interpretation.',
      if (hasDiabetes)
        'Diabetes: use a lower threshold for review when BP is at or above 130/80.',
      if (hasKidneyDisease)
        'Kidney disease: raised BP can worsen renal and cardiovascular risk.',
      if (hasHeartDisease)
        'Heart disease: elevated readings need closer cardiovascular follow-up.',
      if (isPregnant)
        'Pregnancy: BP at or above 140/90 needs maternal review; severe readings need urgent escalation.',
      if (!highRisk && !isPregnant && age == null)
        'No age or chronic-risk context was entered, so this uses standard adult BP bands.',
    ];

    return BpInterpretation(
      severity: severity,
      title: title,
      readingLabel: readingLabel,
      summary: summary,
      recommendation: recommendation,
      contextNotes: contextNotes,
    );
  }
}

class _BpSavedReading {
  const _BpSavedReading({
    required this.patientName,
    required this.interpretation,
    required this.notes,
    required this.recordedAt,
  });

  final DateTime recordedAt;
  final String patientName;
  final BpInterpretation interpretation;
  final String notes;
}
