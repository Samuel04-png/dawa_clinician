import 'package:flutter/material.dart';

import '/components/dawa_design_system.dart';

class BpMonitorApp extends StatefulWidget {
  const BpMonitorApp({super.key});

  @override
  State<BpMonitorApp> createState() => _BpMonitorAppState();
}

class _BpMonitorAppState extends State<BpMonitorApp> {
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _hasDiabetes = false;
  bool _hasKidneyDisease = false;
  bool _hasHeartDisease = false;
  bool _isPregnant = false;

  BpInterpretation? _latestInterpretation;
  final List<_BpSavedReading> _readings = [];

  @override
  void dispose() {
    _patientController.dispose();
    _ageController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final contentWidth = constraints.maxWidth > 1180
                      ? 1180.0
                      : constraints.maxWidth;
                  final panelWidth =
                      wide ? (contentWidth - 16) / 2 : contentWidth;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            SizedBox(
                                width: panelWidth, child: _buildInputCard()),
                            SizedBox(
                              width: panelWidth,
                              child: Column(
                                children: [
                                  _buildInterpretationCard(),
                                  const SizedBox(height: 16),
                                  _buildHistoryCard(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: DawaTokens.surface,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: DawaTokens.brandPrimary,
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DawaTokens.statusDangerBg,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: DawaTokens.statusDanger,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BP Monitor', style: DawaTextStyles.cardTitle),
                Text(
                  'Blood pressure reading and clinical interpretation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
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
              Text('New BP Reading', style: DawaTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _patientController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Patient name',
              icon: Icons.person_outline_rounded,
              hint: 'Optional',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final useRows = constraints.maxWidth >= 540;
              final fields = [
                _numberField(
                  controller: _ageController,
                  label: 'Age',
                  hint: 'Years',
                  icon: Icons.cake_outlined,
                ),
                _numberField(
                  controller: _systolicController,
                  label: 'Systolic',
                  hint: 'mmHg',
                  icon: Icons.arrow_upward_rounded,
                ),
                _numberField(
                  controller: _diastolicController,
                  label: 'Diastolic',
                  hint: 'mmHg',
                  icon: Icons.arrow_downward_rounded,
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
                children: [
                  for (var index = 0; index < fields.length; index++) ...[
                    Expanded(child: fields[index]),
                    if (index != fields.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text('Clinical context', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _riskChip(
                label: 'Diabetes',
                selected: _hasDiabetes,
                onSelected: (value) => setState(() => _hasDiabetes = value),
              ),
              _riskChip(
                label: 'Kidney disease',
                selected: _hasKidneyDisease,
                onSelected: (value) =>
                    setState(() => _hasKidneyDisease = value),
              ),
              _riskChip(
                label: 'Heart disease',
                selected: _hasHeartDisease,
                onSelected: (value) => setState(() => _hasHeartDisease = value),
              ),
              _riskChip(
                label: 'Pregnant',
                selected: _isPregnant,
                onSelected: (value) => setState(() => _isPregnant = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Notes',
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
                onPressed: _analyzeReading,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Interpret Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DawaTokens.brandPrimary,
                  foregroundColor: DawaTokens.textInverse,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
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
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(label: label, icon: icon, hint: hint),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: DawaTokens.surfaceTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        borderSide: BorderSide.none,
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

  Widget _buildInterpretationCard() {
    final interpretation = _latestInterpretation;
    if (interpretation == null) {
      return DawaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.monitor_heart_outlined,
                  color: DawaTokens.textMuted,
                ),
                const SizedBox(width: 8),
                Text('Interpretation', style: DawaTextStyles.cardTitle),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter a reading to see risk level, context-aware interpretation, and follow-up guidance.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.textSecondary,
              ),
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
                      style: DawaTextStyles.secondary.copyWith(
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
              Text('Recent Readings', style: DawaTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 12),
          if (_readings.isEmpty)
            Text(
              'Saved BP interpretations from this session will appear here.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.textSecondary,
              ),
            )
          else
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
    return Container(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DawaTextStyles.secondary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _analyzeReading() {
    final systolic = int.tryParse(_systolicController.text.trim());
    final diastolic = int.tryParse(_diastolicController.text.trim());
    final age = int.tryParse(_ageController.text.trim());

    if (systolic == null ||
        diastolic == null ||
        systolic < 50 ||
        systolic > 260 ||
        diastolic < 30 ||
        diastolic > 160) {
      _showToast('Enter a valid systolic and diastolic BP reading.', true);
      return;
    }

    if (diastolic >= systolic) {
      _showToast('Diastolic pressure should be lower than systolic.', true);
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
      _latestInterpretation = interpretation;
      _readings.insert(
        0,
        _BpSavedReading(
          patientName: patientName,
          interpretation: interpretation,
          notes: _notesController.text.trim(),
        ),
      );
    });
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
    });
  }

  void _showToast(String message, bool isError) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? DawaTokens.statusDanger : DawaTokens.textPrimary,
      ),
    );
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
      BpSeverity.review => DawaTokens.statusWarning,
      BpSeverity.urgent => DawaTokens.statusDanger,
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
  });

  final String patientName;
  final BpInterpretation interpretation;
  final String notes;
}
