import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/components/dawa_design_system.dart';
import '../data/clinician_appointment_repository.dart';
import '../domain/clinician_appointment.dart';

class AppointmentAssessmentPage extends StatefulWidget {
  const AppointmentAssessmentPage({
    super.key,
    required this.appointment,
    this.repository = const ClinicianAppointmentRepository(),
  });

  final ClinicianAppointment appointment;
  final ClinicianAppointmentRepository repository;

  @override
  State<AppointmentAssessmentPage> createState() =>
      _AppointmentAssessmentPageState();
}

class _AppointmentAssessmentPageState extends State<AppointmentAssessmentPage> {
  ClinicianAppointmentRepository get _repository => widget.repository;

  final _bloodPressure = TextEditingController();
  final _heartRate = TextEditingController();
  final _hemoglobin = TextEditingController();
  final _fetalHeartbeat = TextEditingController();
  final _heartbeatQuality = TextEditingController();
  final _fetalPosition = TextEditingController();
  final _estimatedBabySize = TextEditingController();
  final _symptoms = TextEditingController();
  final _observations = TextEditingController();
  final _clinicalAssessment = TextEditingController();
  final _recommendations = TextEditingController();
  final _treatment = TextEditingController();
  final _followUp = TextEditingController();
  final _referral = TextEditingController();
  final _keyFindings = TextEditingController();
  final _urgentCare = TextEditingController();
  final _clinicianNotes = TextEditingController();

  String? _bloodPressureState;
  String? _bloodPressureInterpretation;
  String? _heartRateState;
  String? _heartRateInterpretation;
  String? _hemoglobinState;
  String? _hemoglobinInterpretation;
  String? _fetalHeartbeatState;
  String? _fetalHeartbeatInterpretation;
  String? _heartbeatQualityState;
  String? _heartbeatQualityInterpretation;
  String? _fetalPositionState;
  String? _estimatedBabySizeState;
  String? _overallStatus;
  late String _pregnancyStatus;
  late String _pregnancyStatusSource;
  DateTime? _nextVisit;

  bool _loading = true;
  bool _saving = false;
  bool _completing = false;
  DateTime? _lastSavedAt;
  int _draftVersion = 0;
  String? _pageMessage;
  bool _messageIsError = false;

  static const _measurementStates = <String, String>{
    'measured': 'Measured',
    'recorded': 'Recorded',
    'not_measured': 'Not measured',
    'unable_to_obtain': 'Unable to obtain',
    'not_applicable': 'Not applicable',
  };

  static const _interpretations = <String, String>{
    'normal': 'Normal',
    'low': 'Low',
    'high': 'High',
    'needs_attention': 'Needs attention',
    'critical': 'Critical',
    'recorded': 'Recorded — no interpretation',
  };

  @override
  void initState() {
    super.initState();
    _pregnancyStatus = widget.appointment.pregnancyStatus;
    _pregnancyStatusSource = widget.appointment.pregnancyProvenance == 'patient'
        ? 'patient'
        : 'clinician';
    _loadDraft();
  }

  @override
  void dispose() {
    for (final controller in [
      _bloodPressure,
      _heartRate,
      _hemoglobin,
      _fetalHeartbeat,
      _heartbeatQuality,
      _fetalPosition,
      _estimatedBabySize,
      _symptoms,
      _observations,
      _clinicalAssessment,
      _recommendations,
      _treatment,
      _followUp,
      _referral,
      _keyFindings,
      _urgentCare,
      _clinicianNotes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _repository.getAssessmentDraft(widget.appointment.id);
      if (!mounted) return;
      if (draft != null) {
        _applyPayload(draft.payload);
        _lastSavedAt = draft.lastEditedAt;
        _draftVersion = draft.version;
      }
    } catch (_) {
      _pageMessage =
          'The saved draft could not be loaded. Check the connection before entering new information.';
      _messageIsError = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPayload(Map<String, dynamic> payload) {
    final maternal = _map(payload['maternal']);
    final pregnancy = _map(payload['pregnancy']);
    final patientSummary = _map(payload['patient_summary']);

    _applyMeasurement(
      _map(maternal['blood_pressure']),
      _bloodPressure,
      (state, interpretation) {
        _bloodPressureState = state;
        _bloodPressureInterpretation = interpretation;
      },
    );
    _applyMeasurement(
      _map(maternal['heart_rate']),
      _heartRate,
      (state, interpretation) {
        _heartRateState = state;
        _heartRateInterpretation = interpretation;
      },
    );
    _applyMeasurement(
      _map(maternal['hemoglobin']),
      _hemoglobin,
      (state, interpretation) {
        _hemoglobinState = state;
        _hemoglobinInterpretation = interpretation;
      },
    );
    _applyMeasurement(
      _map(pregnancy['fetal_heartbeat']),
      _fetalHeartbeat,
      (state, interpretation) {
        _fetalHeartbeatState = state;
        _fetalHeartbeatInterpretation = interpretation;
      },
    );
    _applyMeasurement(
      _map(pregnancy['heartbeat_quality']),
      _heartbeatQuality,
      (state, interpretation) {
        _heartbeatQualityState = state;
        _heartbeatQualityInterpretation = interpretation;
      },
    );
    _applyMeasurement(
      _map(pregnancy['fetal_position']),
      _fetalPosition,
      (state, _) => _fetalPositionState = state,
    );
    _applyMeasurement(
      _map(pregnancy['estimated_baby_size']),
      _estimatedBabySize,
      (state, _) => _estimatedBabySizeState = state,
    );

    final savedPregnancyStatus = _text(pregnancy['status']);
    if ({
      'pregnant',
      'not_pregnant',
      'not_provided',
      'prefer_not_to_say',
    }.contains(savedPregnancyStatus)) {
      _pregnancyStatus = savedPregnancyStatus!;
      _pregnancyStatusSource =
          _text(pregnancy['status_source']) ?? _pregnancyStatusSource;
    }

    _symptoms.text = _text(payload['symptoms']) ?? '';
    _observations.text = _text(payload['observations']) ?? '';
    _clinicalAssessment.text = _text(payload['clinical_assessment']) ?? '';
    _recommendations.text = _text(payload['recommendations']) ?? '';
    _treatment.text = _text(payload['treatment']) ?? '';
    _followUp.text = _text(payload['follow_up']) ?? '';
    _referral.text = _text(payload['referral']) ?? '';
    _clinicianNotes.text = _text(payload['clinician_only_notes']) ?? '';
    _keyFindings.text = _text(patientSummary['key_findings']) ?? '';
    _urgentCare.text = _text(patientSummary['urgent_care_instruction']) ?? '';
    _overallStatus = _text(patientSummary['overall_status']);
    _nextVisit = DateTime.tryParse(_text(payload['next_visit']) ?? '');
  }

  void _applyMeasurement(
    Map<String, dynamic> value,
    TextEditingController controller,
    void Function(String? state, String? interpretation) assign,
  ) {
    controller.text = _text(value['value']) ?? '';
    assign(_text(value['state']), _text(value['interpretation']));
  }

  Map<String, dynamic> _payload() {
    return {
      'maternal': {
        'blood_pressure': _measurement(
          state: _bloodPressureState,
          value: _bloodPressure.text,
          interpretation: _bloodPressureInterpretation,
          unit: 'mmHg',
        ),
        'heart_rate': _measurement(
          state: _heartRateState,
          value: _heartRate.text,
          interpretation: _heartRateInterpretation,
          unit: 'bpm',
        ),
        'hemoglobin': _measurement(
          state: _hemoglobinState,
          value: _hemoglobin.text,
          interpretation: _hemoglobinInterpretation,
          unit: 'g/dL',
        ),
      },
      'pregnancy': {
        'status': _pregnancyStatus,
        'status_source': _pregnancyStatusSource,
        'source_lnmp': widget.appointment.pregnancyLnmp?.toIso8601String(),
        'source_estimated_due_date':
            widget.appointment.pregnancyEstimatedDueDate?.toIso8601String(),
        'fetal_heartbeat': _measurement(
          state: _fetalHeartbeatState,
          value: _fetalHeartbeat.text,
          interpretation: _fetalHeartbeatInterpretation,
          unit: 'bpm',
        ),
        'heartbeat_quality': _measurement(
          state: _heartbeatQualityState,
          value: _heartbeatQuality.text,
          interpretation: _heartbeatQualityInterpretation,
        ),
        'fetal_position': _measurement(
          state: _fetalPositionState,
          value: _fetalPosition.text,
        ),
        'estimated_baby_size': _measurement(
          state: _estimatedBabySizeState,
          value: _estimatedBabySize.text,
          unit: 'cm',
        ),
      },
      'symptoms': _nullIfBlank(_symptoms.text),
      'observations': _nullIfBlank(_observations.text),
      'clinical_assessment': _nullIfBlank(_clinicalAssessment.text),
      'recommendations': _nullIfBlank(_recommendations.text),
      'treatment': _nullIfBlank(_treatment.text),
      'follow_up': _nullIfBlank(_followUp.text),
      'referral': _nullIfBlank(_referral.text),
      'next_visit': _nextVisit?.toUtc().toIso8601String(),
      'patient_summary': {
        'overall_status': _overallStatus,
        'key_findings': _nullIfBlank(_keyFindings.text),
        'urgent_care_instruction': _nullIfBlank(_urgentCare.text),
      },
      'clinician_only_notes': _nullIfBlank(_clinicianNotes.text),
    };
  }

  Map<String, dynamic> _measurement({
    required String? state,
    required String value,
    String? interpretation,
    String? unit,
  }) {
    return {
      'state': state,
      'value': state == 'measured' || state == 'recorded'
          ? _nullIfBlank(value)
          : null,
      'interpretation': interpretation,
      'unit': unit,
    };
  }

  List<String> _validationErrors() {
    final errors = <String>[];
    if (_bloodPressureState == null) {
      errors.add(
        'Enter the patient’s blood pressure or mark it as not measured.',
      );
    } else if (_bloodPressureState == 'measured') {
      if (_bloodPressure.text.trim().isEmpty) {
        errors.add('Enter the patient’s blood pressure.');
      }
      if (_bloodPressureInterpretation == null) {
        errors.add('Confirm the blood pressure interpretation.');
      }
    }
    if (_clinicalAssessment.text.trim().isEmpty) {
      errors.add('Record the clinical assessment before completing.');
    }
    if (_recommendations.text.trim().isEmpty && _followUp.text.trim().isEmpty) {
      errors.add('Add at least one recommendation or follow-up instruction.');
    }
    if (_overallStatus == null) {
      errors.add('Select the patient-facing overall result.');
    }
    for (final item in [
      (_heartRateState, _heartRate.text, _heartRateInterpretation),
      (_hemoglobinState, _hemoglobin.text, _hemoglobinInterpretation),
      (
        _fetalHeartbeatState,
        _fetalHeartbeat.text,
        _fetalHeartbeatInterpretation,
      ),
      (
        _heartbeatQualityState,
        _heartbeatQuality.text,
        _heartbeatQualityInterpretation,
      ),
    ]) {
      if (item.$1 == 'measured' || item.$1 == 'recorded') {
        if (item.$2.trim().isEmpty) {
          errors.add('A recorded measurement value is missing.');
        }
        if (item.$3 == null) {
          errors.add('Confirm the interpretation for each recorded finding.');
        }
      }
    }
    for (final item in [
      (_fetalPositionState, _fetalPosition.text),
      (_estimatedBabySizeState, _estimatedBabySize.text),
    ]) {
      if ((item.$1 == 'measured' || item.$1 == 'recorded') &&
          item.$2.trim().isEmpty) {
        errors.add('A recorded pregnancy or baby value is missing.');
      }
    }
    return errors.toSet().toList(growable: false);
  }

  Future<void> _saveDraft() async {
    if (_saving || _completing) return;
    setState(() {
      _saving = true;
      _pageMessage = null;
    });
    try {
      final result = await _repository.saveAssessmentDraft(
        appointmentId: widget.appointment.id,
        assessment: _payload(),
      );
      if (!mounted) return;
      setState(() {
        _draftVersion =
            int.tryParse(result['assessment_version']?.toString() ?? '') ??
                _draftVersion;
        _lastSavedAt =
            DateTime.tryParse(result['last_edited_at']?.toString() ?? '') ??
                DateTime.now();
        _pageMessage = 'Draft saved. The appointment is still active.';
        _messageIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pageMessage =
            'The draft could not be saved. Check the connection and try again.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewAndComplete() async {
    if (_saving || _completing) return;
    final errors = _validationErrors();
    if (errors.isNotEmpty) {
      setState(() {
        _pageMessage = errors.join('\n');
        _messageIsError = true;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Complete appointment?'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _reviewLine('Patient', widget.appointment.patientName),
                    _reviewLine(
                      'Appointment',
                      DateFormat('EEE, d MMM y · HH:mm')
                          .format(widget.appointment.scheduledStart),
                    ),
                    _reviewLine(
                      'Overall result',
                      _overallLabel(_overallStatus),
                    ),
                    _reviewLine(
                      'Key findings',
                      _keyFindings.text.trim().isEmpty
                          ? 'No additional patient-facing finding recorded'
                          : _keyFindings.text.trim(),
                    ),
                    _reviewLine(
                      'Recommendations',
                      _recommendations.text.trim().isEmpty
                          ? _followUp.text.trim()
                          : _recommendations.text.trim(),
                    ),
                    if (_followUp.text.trim().isNotEmpty)
                      _reviewLine('Follow-up', _followUp.text.trim()),
                    const SizedBox(height: 8),
                    Text(
                      'Clinician-only notes are not included in Dawa Mom.',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.statusSuccessText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back to edit'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Complete appointment'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() {
      _completing = true;
      _pageMessage = null;
    });
    try {
      await _repository.completeAssessment(
        appointmentId: widget.appointment.id,
        assessment: _payload(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appointment completed. The patient summary is being sent safely to Dawa Mom.',
          ),
          backgroundColor: DawaTokens.statusSuccess,
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pageMessage =
            'The appointment was not completed. Your data is still on this screen; save the draft and retry.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      appBar: AppBar(
        title: const Text('Appointment assessment'),
        leading: IconButton(
          tooltip: 'Back to appointments',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  final horizontal = constraints.maxWidth < 600 ? 16.0 : 24.0;
                  final mainContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _patientHeader(),
                      const SizedBox(height: 16),
                      _pregnancyContext(),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Maternal vitals',
                        subtitle:
                            'Record what was collected. Never leave a required measurement ambiguous.',
                        children: [
                          _measurementEditor(
                            label: 'Blood pressure',
                            requiredField: true,
                            state: _bloodPressureState,
                            onStateChanged: (value) => setState(
                              () => _bloodPressureState = value,
                            ),
                            controller: _bloodPressure,
                            unit: 'mmHg',
                            interpretation: _bloodPressureInterpretation,
                            onInterpretationChanged: (value) => setState(
                              () => _bloodPressureInterpretation = value,
                            ),
                            hint: 'e.g. 120/80',
                          ),
                          _measurementEditor(
                            label: 'Heart rate',
                            state: _heartRateState,
                            onStateChanged: (value) =>
                                setState(() => _heartRateState = value),
                            controller: _heartRate,
                            unit: 'bpm',
                            interpretation: _heartRateInterpretation,
                            onInterpretationChanged: (value) => setState(
                              () => _heartRateInterpretation = value,
                            ),
                            numeric: true,
                          ),
                          _measurementEditor(
                            label: 'Blood / haemoglobin level',
                            state: _hemoglobinState,
                            onStateChanged: (value) =>
                                setState(() => _hemoglobinState = value),
                            controller: _hemoglobin,
                            unit: 'g/dL',
                            interpretation: _hemoglobinInterpretation,
                            onInterpretationChanged: (value) => setState(
                              () => _hemoglobinInterpretation = value,
                            ),
                            numeric: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.child_friendly_rounded,
                        title: 'Pregnancy and baby assessment',
                        subtitle:
                            'These fields are optional unless they were assessed. Choose an explicit state for every recorded item.',
                        children: [
                          _measurementEditor(
                            label: 'Fetal heartbeat',
                            state: _fetalHeartbeatState,
                            onStateChanged: (value) =>
                                setState(() => _fetalHeartbeatState = value),
                            controller: _fetalHeartbeat,
                            unit: 'bpm',
                            interpretation: _fetalHeartbeatInterpretation,
                            onInterpretationChanged: (value) => setState(
                              () => _fetalHeartbeatInterpretation = value,
                            ),
                            numeric: true,
                          ),
                          _measurementEditor(
                            label: 'Heartbeat quality',
                            state: _heartbeatQualityState,
                            onStateChanged: (value) =>
                                setState(() => _heartbeatQualityState = value),
                            controller: _heartbeatQuality,
                            interpretation: _heartbeatQualityInterpretation,
                            onInterpretationChanged: (value) => setState(
                              () => _heartbeatQualityInterpretation = value,
                            ),
                            recordedState: true,
                          ),
                          _measurementEditor(
                            label: 'Fetal / womb position',
                            state: _fetalPositionState,
                            onStateChanged: (value) =>
                                setState(() => _fetalPositionState = value),
                            controller: _fetalPosition,
                            recordedState: true,
                            includeInterpretation: false,
                          ),
                          _measurementEditor(
                            label: 'Estimated baby size',
                            state: _estimatedBabySizeState,
                            onStateChanged: (value) => setState(
                              () => _estimatedBabySizeState = value,
                            ),
                            controller: _estimatedBabySize,
                            unit: 'cm',
                            recordedState: true,
                            includeInterpretation: false,
                            numeric: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.medical_information_outlined,
                        title: 'Clinical assessment',
                        subtitle:
                            'Record the consultation. Required fields are marked clearly.',
                        children: [
                          _textArea(
                            label: 'Symptoms',
                            controller: _symptoms,
                            hint: 'Patient-reported symptoms (optional)',
                          ),
                          _textArea(
                            label: 'Clinical observations',
                            controller: _observations,
                            hint: 'Relevant observations (optional)',
                          ),
                          _textArea(
                            label: 'Clinical assessment',
                            controller: _clinicalAssessment,
                            hint:
                                'Document the assessment made during this visit',
                            requiredField: true,
                          ),
                          _textArea(
                            label: 'Treatment',
                            controller: _treatment,
                            hint: 'Treatment provided or prescribed (optional)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.follow_the_signs_rounded,
                        title: 'Recommendations and follow-up',
                        subtitle:
                            'At least one recommendation or follow-up instruction is required.',
                        children: [
                          _textArea(
                            label: 'Patient-friendly recommendations',
                            controller: _recommendations,
                            hint: 'What should the patient do next?',
                          ),
                          _textArea(
                            label: 'Follow-up instructions',
                            controller: _followUp,
                            hint: 'Follow-up timing or additional tests',
                          ),
                          _textArea(
                            label: 'Referral summary',
                            controller: _referral,
                            hint: 'Referral information (optional)',
                          ),
                          _dateField(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _patientSummarySection(),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.lock_outline_rounded,
                        title: 'Clinician-only notes',
                        subtitle:
                            'Private notes stay in Dawa Clinician and are never copied into the Dawa Mom result.',
                        children: [
                          _textArea(
                            label: 'Private clinical notes',
                            controller: _clinicianNotes,
                            hint: 'Internal notes (optional)',
                          ),
                        ],
                      ),
                    ],
                  );

                  return SingleChildScrollView(
                    padding:
                        EdgeInsets.fromLTRB(horizontal, 20, horizontal, 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: mainContent),
                                  const SizedBox(width: 20),
                                  SizedBox(width: 310, child: _actionPanel()),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  mainContent,
                                  const SizedBox(height: 16),
                                  _actionPanel(),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _patientHeader() {
    return DawaCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.appointment.patientName,
                  style: DawaTextStyles.pageTitle),
              const SizedBox(height: 5),
              Text(
                '${DateFormat('EEEE, d MMMM y').format(widget.appointment.scheduledStart)} · '
                '${DateFormat('HH:mm').format(widget.appointment.scheduledStart)}–'
                '${DateFormat('HH:mm').format(widget.appointment.scheduledEnd)}',
                style: DawaTextStyles.secondary,
              ),
              Text(widget.appointment.clinicName,
                  style: DawaTextStyles.secondary),
            ],
          );
          final badge = DawaStatusBadge(
            status: widget.appointment.assessmentStatus,
            label: widget.appointment.hasAssessmentDraft
                ? 'Assessment draft'
                : 'Not started',
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DawaAvatarCircle(
                      name: widget.appointment.patientName,
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: identity),
                  ],
                ),
                const SizedBox(height: 12),
                badge,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DawaAvatarCircle(name: widget.appointment.patientName, size: 58),
              const SizedBox(width: 14),
              Expanded(child: identity),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _pregnancyContext() {
    final label = _pregnancyLabel(_pregnancyStatus);
    final dates = <String>[];
    if (widget.appointment.pregnancyLnmp != null) {
      dates.add(
        'LNMP ${DateFormat('d MMM y').format(widget.appointment.pregnancyLnmp!)}',
      );
    }
    if (widget.appointment.pregnancyEstimatedDueDate != null) {
      dates.add(
        'EDD ${DateFormat('d MMM y').format(widget.appointment.pregnancyEstimatedDueDate!)}',
      );
    }
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pregnant_woman_rounded,
                  color: DawaTokens.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text('Pregnancy context', style: DawaTextStyles.cardTitle),
              ),
              if (_pregnancyStatusSource == 'patient')
                const DawaStatusBadge(
                  status: 'active',
                  label: 'Patient-provided',
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('pregnancy-$_pregnancyStatus'),
            initialValue: _pregnancyStatus,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Current status'),
            items: const [
              DropdownMenuItem(value: 'pregnant', child: Text('Pregnant')),
              DropdownMenuItem(
                value: 'not_pregnant',
                child: Text('Not currently pregnant'),
              ),
              DropdownMenuItem(
                value: 'not_provided',
                child: Text('Pregnancy status not provided'),
              ),
              DropdownMenuItem(
                value: 'prefer_not_to_say',
                child: Text('Patient preferred not to say'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _pregnancyStatus = value;
                _pregnancyStatusSource = 'clinician';
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            dates.isEmpty
                ? label == 'Pregnant'
                    ? 'Pregnancy is reported, but source dates are not available. Confirm them during the consultation if appropriate.'
                    : label
                : '$label · ${dates.join(' · ')}',
            style: DawaTextStyles.secondary,
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DawaTokens.brandPrimaryPale,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                ),
                child: Icon(icon, color: DawaTokens.brandPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: DawaTextStyles.secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children.expand((child) => [child, const SizedBox(height: 14)]),
        ],
      ),
    );
  }

  Widget _measurementEditor({
    required String label,
    required String? state,
    required ValueChanged<String?> onStateChanged,
    required TextEditingController controller,
    String? unit,
    String? interpretation,
    ValueChanged<String?>? onInterpretationChanged,
    String? hint,
    bool requiredField = false,
    bool includeInterpretation = true,
    bool recordedState = false,
    bool numeric = false,
  }) {
    final hasValue = state == 'measured' || state == 'recorded';
    final stateItems = _measurementStates.entries
        .where((entry) => recordedState || entry.key != 'recorded')
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value),
          ),
        )
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        border: Border.all(color: DawaTokens.border),
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredField ? '$label *' : label,
            style: DawaTextStyles.label.copyWith(
              color: DawaTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final fields = <Widget>[
                DropdownButtonFormField<String>(
                  key: ValueKey('$label-state-$state'),
                  initialValue: state,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Collection state'),
                  hint: const Text('Choose state'),
                  items: stateItems,
                  onChanged: onStateChanged,
                ),
                TextFormField(
                  controller: controller,
                  enabled: hasValue,
                  keyboardType:
                      numeric ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Value${unit == null ? '' : ' ($unit)'}',
                    hintText: hint,
                  ),
                ),
                if (includeInterpretation)
                  DropdownButtonFormField<String>(
                    key: ValueKey('$label-interpretation-$interpretation'),
                    initialValue: interpretation,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Interpretation'),
                    hint: const Text('Choose result'),
                    items: _interpretations.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: hasValue ? onInterpretationChanged : null,
                  ),
              ];
              if (compact) {
                return Column(
                  children: fields
                      .expand((field) => [field, const SizedBox(height: 10)])
                      .toList(growable: false),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fields
                    .expand((field) => [
                          Expanded(child: field),
                          const SizedBox(width: 10),
                        ])
                    .toList()
                  ..removeLast(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _textArea({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      minLines: 3,
      maxLines: 7,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 730)),
          initialDate:
              _nextVisit ?? DateTime.now().add(const Duration(days: 7)),
        );
        if (picked != null && mounted) setState(() => _nextVisit = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Recommended next appointment',
          suffixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(
          _nextVisit == null
              ? 'Not set (optional)'
              : DateFormat('EEEE, d MMMM y').format(_nextVisit!),
          style: DawaTextStyles.body,
        ),
      ),
    );
  }

  Widget _patientSummarySection() {
    return _section(
      icon: Icons.visibility_outlined,
      title: 'Patient-facing summary preview',
      subtitle:
          'Only this approved high-level wording and the result cards will be sent to Dawa Mom.',
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('overall-$_overallStatus'),
          initialValue: _overallStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Overall patient-facing result *',
          ),
          hint: const Text('Choose overall result'),
          items: const [
            DropdownMenuItem(
              value: 'routine',
              child: Text('Routine care'),
            ),
            DropdownMenuItem(
              value: 'follow_up',
              child: Text('Follow-up recommended'),
            ),
            DropdownMenuItem(
              value: 'needs_attention',
              child: Text('Needs attention'),
            ),
            DropdownMenuItem(
              value: 'urgent',
              child: Text('Urgent care instruction'),
            ),
          ],
          onChanged: (value) => setState(() => _overallStatus = value),
        ),
        _textArea(
          label: 'Key findings for the patient',
          controller: _keyFindings,
          hint: 'Brief plain-language findings (optional)',
        ),
        _textArea(
          label: 'Authorised urgent-care instruction',
          controller: _urgentCare,
          hint: 'Only include when clinically authorised (optional)',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DawaTokens.brandPrimaryPale,
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _overallLabel(_overallStatus),
                style: DawaTextStyles.cardTitle.copyWith(
                  color: DawaTokens.brandPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _keyFindings.text.trim().isEmpty
                    ? 'Result cards will show only explicitly recorded values and clinician-confirmed interpretations.'
                    : _keyFindings.text.trim(),
                style: DawaTextStyles.body,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionPanel() {
    final validation = _validationErrors();
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Assessment progress', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 10),
          if (_lastSavedAt != null)
            Text(
              'Draft v$_draftVersion saved ${DateFormat('d MMM, HH:mm').format(_lastSavedAt!.toLocal())}',
              style: DawaTextStyles.secondary,
            )
          else
            Text('No saved draft yet', style: DawaTextStyles.secondary),
          if (_pageMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _messageIsError
                    ? DawaTokens.statusDangerBg
                    : DawaTokens.statusSuccessBg,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              ),
              child: Text(
                _pageMessage!,
                style: DawaTextStyles.secondary.copyWith(
                  color: _messageIsError
                      ? DawaTokens.statusDangerText
                      : DawaTokens.statusSuccessText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving || _completing ? null : _saveDraft,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving draft…' : 'Save draft'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving || _completing ? null : _reviewAndComplete,
            icon: _completing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(
              _completing ? 'Completing…' : 'Review and complete',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                validation.isEmpty
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: validation.isEmpty
                    ? DawaTokens.statusSuccessText
                    : DawaTokens.statusWarningText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  validation.isEmpty
                      ? 'Required completion information is present.'
                      : '${validation.length} required item${validation.length == 1 ? '' : 's'} remaining.',
                  style: DawaTextStyles.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DawaTextStyles.label),
          const SizedBox(height: 3),
          Text(value, style: DawaTextStyles.body),
        ],
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _pregnancyLabel(String status) => switch (status) {
        'pregnant' => 'Pregnant',
        'not_pregnant' => 'Not currently pregnant',
        'prefer_not_to_say' => 'Patient preferred not to say',
        _ => 'Pregnancy status not provided',
      };

  static String _overallLabel(String? status) => switch (status) {
        'routine' => 'Routine care',
        'follow_up' => 'Follow-up recommended',
        'needs_attention' => 'Needs attention',
        'urgent' => 'Urgent care instruction',
        _ => 'Overall result not selected',
      };
}
