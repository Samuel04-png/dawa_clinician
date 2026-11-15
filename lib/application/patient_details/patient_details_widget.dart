import '/components/clinical_navigation_shell.dart';
import '/components/clinical_workspace_components.dart';
import '/application/cacx/cacx_model.dart';
import '/application/cacx/cacx_widget.dart';
import '/application/mom_details/mom_details_widget.dart';
import '/backend/backend.dart';
import '/components/missing_patient_context.dart';
import '/backend/supabase/supabase_config.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientDetailsWidget extends StatefulWidget {
  const PatientDetailsWidget({
    super.key,
    required this.momDetails,
    this.firstEncounter,
  });

  final DocumentReference? momDetails;
  final DocumentReference? firstEncounter;

  static String routeName = 'PatientDetails';
  static String routePath = '/patientDetails';

  @override
  State<PatientDetailsWidget> createState() => _PatientDetailsWidgetState();
}

class _PatientDetailsWidgetState extends State<PatientDetailsWidget> {
  int _historyRefreshKey = 0;

  Future<List<_ScreeningRecord>> _loadScreenings(String patientId) async {
    if (patientId.trim().isEmpty) {
      return const [];
    }

    try {
      final response = await runSupabaseRequest(
        () => supabaseClient
            .from('cacx_screening_results')
            .select()
            .eq('patient_id', patientId)
            .order('created_at', ascending: false),
      );

      return (response as List<dynamic>)
          .whereType<Map>()
          .map(
              (row) => _ScreeningRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      debugPrint('[PatientDetails] Failed to load screenings: $error');
      rethrow;
    }
  }

  Future<void> _openAddScreening(MotherRecord patient) async {
    final patientId = _patientIdentifier(patient);
    final screeningPatient = Patient(
      id: patientId,
      name: patient.name.trim().isEmpty ? 'Unnamed patient' : patient.name,
      age: patient.dateOfBirth == null
          ? 0
          : functions.calculateAge(patient.dateOfBirth!),
      contact: patient.phoneNumber,
      lastTestDate: null,
      status: PatientStatus.untested,
      riskLevel: RiskLevel.low,
    );

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaCxApp(
          initialPatient: screeningPatient,
          autoStartScreening: true,
          returnToPreviousOnSave: true,
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _historyRefreshKey++;
      });
    }
  }

  void _openLegacyRecord() {
    context.pushNamed(
      MomDetailsWidget.routeName,
      queryParameters: {
        'momDetails': serializeParam(
          widget.momDetails,
          ParamType.DocumentReference,
        ),
        'firstEncounter': serializeParam(
          widget.firstEncounter,
          ParamType.DocumentReference,
        ),
      }.withoutNulls,
    );
  }

  String _patientIdentifier(MotherRecord patient) {
    final externalId = patient.motherId.trim();
    if (externalId.isNotEmpty) {
      return externalId;
    }
    return patient.reference.id;
  }

  Future<List<_ScreeningRecord>>? _screeningsFuture;
  String? _screeningsKey;

  @override
  Widget build(BuildContext context) {
    if (widget.momDetails == null) {
      return const MissingPatientContext();
    }
    return StreamBuilder<MotherRecord>(
      key: ValueKey(widget.momDetails!.path),
      stream: MotherRecord.getDocument(widget.momDetails!),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            !snapshot.hasError &&
            snapshot.connectionState == ConnectionState.waiting) {
          return ClinicalNavigationShell(
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading patient details…', style: DawaTextStyles.secondary),
            ])),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint(
              '[PatientDetails] Failed to load patient: ${snapshot.error}');
          return ClinicalNavigationShell(
              child: ClinicalEmptyState(
            icon: Icons.person_search_outlined,
            title: 'Patient details unavailable',
            message: 'Return to Patients and open the record again.',
            actionLabel: 'Open Patients',
            onAction: () => context.goNamed(MomsWidget.routeName),
          ));
        }
        final patient = snapshot.data!;
        final patientId = _patientIdentifier(patient);
        final historyKey = '$patientId-$_historyRefreshKey';
        if (_screeningsKey != historyKey) {
          _screeningsKey = historyKey;
          _screeningsFuture = _loadScreenings(patientId);
        }
        return ClinicalNavigationShell(
            child: FutureBuilder<List<_ScreeningRecord>>(
          key: ValueKey(historyKey),
          future: _screeningsFuture,
          builder: (context, history) =>
              LayoutBuilder(builder: (context, size) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final padding = size.maxWidth < 600 ? 16.0 : 24.0;
            final columns = size.maxWidth - padding * 2 >= 720 && !largeText;
            final profile = _buildPatientProfileCard(patient);
            final screenings = _buildScreeningWorkspace(patient, history);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: DawaTokens.workspaceMaxWidth),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPageHeader(patient),
                          const SizedBox(height: 20),
                          if (columns)
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      width: size.maxWidth >= 1100 ? 288 : 250,
                                      child: profile),
                                  const SizedBox(width: 20),
                                  Expanded(child: screenings),
                                ])
                          else ...[
                            profile,
                            const SizedBox(height: 20),
                            screenings
                          ],
                        ]),
                  )),
            );
          }),
        ));
      },
    );
  }

  Widget _buildPageHeader(MotherRecord patient) {
    return LayoutBuilder(builder: (context, size) {
      final heading =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
          onPressed: () => context.goNamed(MomsWidget.routeName),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Patients'),
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(48, 36)),
        ),
        Semantics(
            header: true,
            child: Text('Patient record', style: DawaTextStyles.pageTitle)),
      ]);
      final actions = Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
          onPressed: _openLegacyRecord,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('Full Maternal Record'),
        ),
        FilledButton.icon(
          onPressed: () => _openAddScreening(patient),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Screening'),
        ),
      ]);
      if (size.maxWidth < 860 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 12), actions]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: heading),
        const SizedBox(width: 16),
        actions,
      ]);
    });
  }

  Widget _buildPatientProfileCard(MotherRecord patient) {
    final identifier = _patientIdentifier(patient);
    final shortRef = identifier.length > 18
        ? '${identifier.substring(0, 8)}…${identifier.substring(identifier.length - 4)}'
        : identifier;
    final birthDate = patient.dateOfBirth;
    return DawaCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DawaAvatarCircle(name: patient.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text(
                        patient.name.trim().isEmpty
                            ? 'Unnamed patient'
                            : patient.name,
                        style: DawaTextStyles.cardTitle.copyWith(fontSize: 20),
                      ))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: Text('Ref $shortRef',
                      style: DawaTextStyles.secondary.copyWith(fontSize: 12))),
              IconButton(
                tooltip: 'Copy full patient reference',
                icon: const Icon(Icons.copy_outlined, size: 16),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: identifier));
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Patient reference copied')));
                },
              ),
            ]),
            const Divider(height: 24, color: DawaTokens.border),
            _profileField(
                'Date of birth',
                birthDate == null
                    ? 'Not recorded'
                    : '${dateTimeFormat('d MMM y', birthDate)} · ${functions.calculateAge(birthDate)} years',
                Icons.cake_outlined),
            _profileField(
                'Phone',
                patient.phoneNumber.trim().isEmpty
                    ? 'Not recorded'
                    : patient.phoneNumber,
                Icons.phone_outlined),
            _profileField(
                'Location',
                patient.address.trim().isEmpty
                    ? 'Not recorded'
                    : patient.address,
                Icons.location_on_outlined),
            _profileField(
                'Occupation',
                patient.occupation.trim().isEmpty
                    ? 'Not recorded'
                    : patient.occupation,
                Icons.work_outline_rounded),
          ],
        ));
  }

  Widget _buildScreeningWorkspace(
      MotherRecord patient, AsyncSnapshot<List<_ScreeningRecord>> history) {
    final records = history.data ?? const <_ScreeningRecord>[];
    final loading =
        history.connectionState == ConnectionState.waiting && !history.hasData;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!loading && !history.hasError && records.isNotEmpty) ...[
        _buildLatestScreeningCard(records.first),
        const SizedBox(height: 20),
      ],
      DawaCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Screening History', style: DawaTextStyles.cardTitle),
              if (!loading && !history.hasError && records.isNotEmpty)
                Text(
                    '${records.length} saved ${records.length == 1 ? 'screening' : 'screenings'}',
                    style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
            ]),
        const SizedBox(height: 4),
        Text('Cervical cancer · Newest first',
            style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
        const SizedBox(height: 16),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()))
        else if (history.hasError)
          ClinicalEmptyState(
            surface: false,
            icon: Icons.cloud_off_outlined,
            title: 'Screening history unavailable',
            message:
                'Check your connection and try loading the saved results again.',
            actionLabel: 'Retry',
            onAction: () => setState(() => _historyRefreshKey++),
          )
        else if (records.isEmpty)
          ClinicalEmptyState(
            surface: false,
            icon: Icons.assignment_outlined,
            title: 'No screenings yet',
            message: 'No cervical cancer results are saved for this patient.',
            actionLabel: 'Add Screening',
            onAction: () => _openAddScreening(patient),
          )
        else
          Column(children: [
            for (var index = 0; index < records.length; index++) ...[
              if (index > 0) const Divider(height: 1, color: DawaTokens.border),
              _buildHistoryRecordCard(records[index]),
            ],
          ]),
      ])),
    ]);
  }

  Widget _buildLatestScreeningCard(_ScreeningRecord record) {
    return DawaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Latest screening', style: DawaTextStyles.cardTitle),
            _buildRiskBadge(record.riskLevel),
          ]),
      const SizedBox(height: 12),
      Text(record.primaryResultOrFallback,
          style: DawaTextStyles.pageTitle.copyWith(fontSize: 24)),
      const SizedBox(height: 8),
      Text('${record.completedLabel} · ${record.sourceLabel}',
          style: DawaTextStyles.secondary),
      if (record.primaryConfidence != null) ...[
        const SizedBox(height: 6),
        Text('${record.confidenceLabel} confidence',
            style: DawaTextStyles.secondary),
      ],
      const SizedBox(height: 12),
      Text(record.recommendationSummary, style: DawaTextStyles.body),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _smallBadge(record.statusLabel, record.statusBadgeBackground,
            record.statusBadgeForeground),
        if (record.secondOpinionStatus != 'not_required')
          _smallBadge(record.secondOpinionBadgeLabel,
              DawaTokens.surfaceTertiary, DawaTokens.textSecondary),
      ]),
      const SizedBox(height: 12),
      Text('AI estimate — clinician must review',
          style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
      const SizedBox(height: 4),
      TextButton.icon(
          onPressed: () => _showScreeningDetails(record),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Review latest result')),
    ]));
  }

  Widget _buildHistoryRecordCard(_ScreeningRecord record) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(record.completedLabel,
                      style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
                  _buildRiskBadge(record.riskLevel),
                ]),
            const SizedBox(height: 8),
            Text(record.primaryResultOrFallback,
                style: DawaTextStyles.cardTitle),
            const SizedBox(height: 6),
            Text(record.sourceLabel, style: DawaTextStyles.secondary),
            const SizedBox(height: 4),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: () => _showScreeningDetails(record),
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('View Details'))),
          ],
        ));
  }

  Future<void> _showScreeningDetails(_ScreeningRecord record) async {
    Widget content() => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text('Screening Details',
                          style: DawaTextStyles.pageTitle))),
              IconButton(
                  tooltip: 'Close screening details',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 8),
            Text('AI estimate — clinician must review',
                style: DawaTextStyles.secondary),
            const SizedBox(height: 20),
            _detailSection('Result summary', [
              _detailRow('Module', 'Cervical cancer'),
              _detailRow('Primary result', record.primaryResultOrFallback),
              _detailRow('Primary confidence', record.confidenceLabel),
              _detailRow('Risk level', record.riskLabel),
              _detailRow('Source', record.sourceLabel),
              _detailRow('Completed', record.completedLabel),
            ]),
            const SizedBox(height: 16),
            _detailSection('Review status', [
              _detailRow('Device status', record.deviceStatusLabel),
              _detailRow('Second opinion', record.secondOpinionSummary),
              _detailRow('Second opinion result',
                  record.secondOpinionResultOrFallback),
              _detailRow('Second opinion confidence',
                  record.secondOpinionConfidenceLabel),
            ]),
            const SizedBox(height: 16),
            _detailSection('Clinical recommendation', [
              Text(record.recommendationSummary, style: DawaTextStyles.body),
            ]),
            const SizedBox(height: 16),
            _detailSection('Screening image', [_buildImagePreview(record)]),
            const SizedBox(height: 16),
            ExpansionTile(title: const Text('Diagnostics'), children: [
              _detailRow('Primary source', record.primarySource),
              _detailRow(
                  'Device endpoint', record.deviceEndpoint ?? 'Not recorded'),
              _detailRow('Device error', record.deviceError ?? 'None'),
              _detailRow('Image path', record.imagePath ?? 'Not recorded'),
            ]),
          ]),
        );
    if (MediaQuery.sizeOf(context).width >= 720) {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
                backgroundColor: DawaTokens.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DawaTokens.radiusLg)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 720,
                      maxHeight: MediaQuery.sizeOf(dialogContext).height * .85),
                  child: content(),
                ),
              ));
    } else {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: DawaTokens.surface,
          useSafeArea: true,
          builder: (_) =>
              FractionallySizedBox(heightFactor: .9, child: content()));
    }
  }

  Widget _buildImagePreview(_ScreeningRecord record) {
    final imageUrl = record.imageUrl;
    final isNetworkImage =
        imageUrl != null && Uri.tryParse(imageUrl)?.hasAbsolutePath == true;

    return Container(
      width: double.infinity,
      height: 220.0,
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
      ),
      child: isNetworkImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              ),
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_not_supported_outlined,
          size: 40.0,
          color: DawaTokens.textMuted,
        ),
        const SizedBox(height: 10.0),
        Text(
          'Uploaded image preview unavailable',
          style: DawaTextStyles.secondary,
        ),
      ],
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DawaTextStyles.cardTitle),
          const SizedBox(height: 12.0),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(builder: (context, size) {
          final caption = Text(label, style: DawaTextStyles.secondary);
          final detail = Text(value, style: DawaTextStyles.body);
          if (size.maxWidth < 480 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [caption, const SizedBox(height: 4), detail]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 170, child: caption),
            Expanded(child: detail),
          ]);
        }));
  }

  Widget _profileField(String label, String value, IconData icon) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: DawaTokens.textMuted),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: DawaTextStyles.body),
              ])),
        ]));
  }

  Widget _buildRiskBadge(String riskLevel) {
    final tone = _riskTone(riskLevel);
    return _smallBadge(
      _riskLabel(riskLevel),
      tone.background,
      tone.foreground,
    );
  }

  Widget _smallBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99.0),
        border: Border.all(color: foreground.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: foreground,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _Tone _riskTone(String rawRisk) {
    switch (rawRisk.trim().toLowerCase()) {
      case 'normal':
      case 'low':
        return const _Tone(
          background: DawaTokens.statusSuccessBg,
          foreground: DawaTokens.statusSuccessText,
        );
      case 'borderline':
        return const _Tone(
          background: DawaTokens.statusWarningBg,
          foreground: DawaTokens.statusWarningText,
        );
      case 'high':
        return const _Tone(
          background: DawaTokens.statusDangerBg,
          foreground: DawaTokens.statusDangerText,
        );
      case 'unknown':
      default:
        return const _Tone(
          background: DawaTokens.surfaceTertiary,
          foreground: DawaTokens.textSecondary,
        );
    }
  }

  String _riskLabel(String rawRisk) {
    switch (rawRisk.trim().toLowerCase()) {
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low Risk';
      case 'borderline':
        return 'Borderline';
      case 'high':
        return 'High Risk';
      case 'unknown':
      default:
        return 'Unknown';
    }
  }
}

class _ScreeningRecord {
  const _ScreeningRecord({
    required this.id,
    required this.createdAt,
    required this.primarySource,
    required this.primaryResult,
    required this.primaryConfidence,
    required this.secondOpinionRequired,
    required this.secondOpinionStatus,
    required this.secondOpinionSource,
    required this.secondOpinionResult,
    required this.secondOpinionConfidence,
    required this.riskLevel,
    required this.deviceStatus,
    required this.deviceEndpoint,
    required this.deviceError,
    required this.imageUrl,
    required this.imagePath,
  });

  final String id;
  final DateTime? createdAt;
  final String primarySource;
  final String? primaryResult;
  final double? primaryConfidence;
  final bool secondOpinionRequired;
  final String secondOpinionStatus;
  final String? secondOpinionSource;
  final String? secondOpinionResult;
  final double? secondOpinionConfidence;
  final String riskLevel;
  final String deviceStatus;
  final String? deviceEndpoint;
  final String? deviceError;
  final String? imageUrl;
  final String? imagePath;

  factory _ScreeningRecord.fromMap(Map<String, dynamic> map) {
    return _ScreeningRecord(
      id: map['id']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at']),
      primarySource: map['primary_source']?.toString() ?? 'arduino_device',
      primaryResult: map['primary_result']?.toString(),
      primaryConfidence: _parseDouble(map['primary_confidence']),
      secondOpinionRequired: map['second_opinion_required'] == true,
      secondOpinionStatus:
          map['second_opinion_status']?.toString() ?? 'not_required',
      secondOpinionSource: map['second_opinion_source']?.toString(),
      secondOpinionResult: map['second_opinion_result']?.toString(),
      secondOpinionConfidence: _parseDouble(map['second_opinion_confidence']),
      riskLevel: map['risk_level']?.toString() ?? 'unknown',
      deviceStatus: map['device_status']?.toString() ?? 'pending',
      deviceEndpoint: map['device_endpoint']?.toString(),
      deviceError: map['device_error']?.toString(),
      imageUrl: map['image_url']?.toString(),
      imagePath: map['image_path']?.toString(),
    );
  }

  String get primaryResultOrFallback =>
      primaryResult?.trim().isNotEmpty == true ? primaryResult! : 'Unknown';

  String get confidenceLabel => primaryConfidence == null
      ? 'Confidence unavailable'
      : '${primaryConfidence!.toStringAsFixed(1)}%';

  String get completedLabel => createdAt == null
      ? 'Unknown date'
      : dateTimeFormat('d MMM y, h:mm a', createdAt!);

  String get statusLabel {
    switch (riskLevel.toLowerCase()) {
      case 'normal':
      case 'low':
        return 'Completed';
      case 'borderline':
      case 'high':
        return 'Needs Review';
      case 'unknown':
      default:
        return 'Completed';
    }
  }

  Color get statusBadgeBackground {
    if (riskLevel == 'high' || riskLevel == 'borderline') {
      return DawaTokens.statusWarningBg;
    }
    return DawaTokens.statusSuccessBg;
  }

  Color get statusBadgeForeground {
    if (riskLevel == 'high' || riskLevel == 'borderline') {
      return DawaTokens.statusWarningText;
    }
    return DawaTokens.statusSuccessText;
  }

  String get riskLabel {
    switch (riskLevel.toLowerCase()) {
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low Risk';
      case 'borderline':
        return 'Borderline';
      case 'high':
        return 'High Risk';
      default:
        return 'Unknown';
    }
  }

  String get sourceLabel {
    final normalized = (secondOpinionStatus == 'completed'
            ? secondOpinionSource
            : primarySource)
        ?.toLowerCase()
        .trim();

    switch (normalized) {
      case 'gradio_server':
        return 'Cloud AI / Gradio';
      case 'manual':
      case 'clinician_review':
        return 'Manual Review';
      case 'arduino_device':
      default:
        return 'Device AI';
    }
  }

  String get secondOpinionSummary {
    switch (secondOpinionStatus) {
      case 'completed':
        return secondOpinionResult?.trim().isNotEmpty == true
            ? 'Second opinion: ${secondOpinionResult!}'
            : 'Second opinion completed';
      case 'pending':
        return 'Second opinion pending';
      case 'failed':
        return 'Second opinion failed';
      case 'not_required':
      default:
        return 'Second opinion not required';
    }
  }

  String get secondOpinionResultOrFallback =>
      secondOpinionResult?.trim().isNotEmpty == true
          ? secondOpinionResult!
          : 'Not available';

  String get secondOpinionConfidenceLabel => secondOpinionConfidence == null
      ? 'Not available'
      : '${secondOpinionConfidence!.toStringAsFixed(1)}%';

  String get deviceStatusLabel {
    switch (deviceStatus) {
      case 'success':
        return 'Device completed';
      case 'failed':
        return 'Device failed';
      case 'timeout':
        return 'Device timed out';
      case 'pending':
      default:
        return 'Device pending';
    }
  }

  String get secondOpinionBadgeLabel {
    switch (secondOpinionStatus) {
      case 'completed':
        return 'Second opinion completed';
      case 'pending':
        return 'Second opinion pending';
      case 'failed':
        return 'Second opinion failed';
      case 'not_required':
      default:
        return 'Second opinion not required';
    }
  }

  Color get secondOpinionBadgeBackground {
    switch (secondOpinionStatus) {
      case 'completed':
        return DawaTokens.statusSuccessBg;
      case 'pending':
        return DawaTokens.surfaceTertiary;
      case 'failed':
        return DawaTokens.statusDangerBg;
      case 'not_required':
      default:
        return DawaTokens.brandPrimaryPale;
    }
  }

  Color get secondOpinionBadgeForeground {
    switch (secondOpinionStatus) {
      case 'completed':
        return DawaTokens.statusSuccessText;
      case 'pending':
        return DawaTokens.textSecondary;
      case 'failed':
        return DawaTokens.statusDangerText;
      case 'not_required':
      default:
        return DawaTokens.brandPrimary;
    }
  }

  String get recommendationSummary {
    if (secondOpinionStatus == 'completed' &&
        secondOpinionResult?.trim().isNotEmpty == true) {
      return 'Secondary review result: ${secondOpinionResult!}. Continue management according to clinical protocol and local escalation pathways.';
    }

    switch (riskLevel.toLowerCase()) {
      case 'normal':
      case 'low':
        return 'Normal / low-risk screen. Continue routine follow-up according to screening guidelines.';
      case 'borderline':
        return 'Borderline result. Review findings and consider second opinion or repeat screening.';
      case 'high':
        return 'High-risk result. Prioritize clinical review, follow-up planning, and escalation where appropriate.';
      case 'unknown':
      default:
        return 'Result needs clinician interpretation. Review the device and second opinion status before closing the case.';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class _Tone {
  const _Tone({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
