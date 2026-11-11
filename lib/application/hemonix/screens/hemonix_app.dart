import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '/components/dawa_design_system.dart';
import '/components/edge_workflow_status.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_image_input.dart';
import '/services/screening_patient_repository.dart';
import '../models/anemia_result.dart';
import '../repository/anemia_repository.dart';
import '../services/anemia_edge_service.dart';

class HemonixApp extends StatefulWidget {
  const HemonixApp(
      {super.key, this.deviceManager, this.repository, this.pickImage});
  static String routeName = 'HemoNix';
  static String routePath = '/hemonix';
  final EdgeDeviceManager? deviceManager;
  final AnemiaRepository? repository;
  final Future<EdgeImageInput?> Function(ImageSource source)? pickImage;

  @override
  State<HemonixApp> createState() => _HemonixAppState();
}

class _HemonixAppState extends State<HemonixApp> {
  late final EdgeDeviceManager _manager;
  late final AnemiaRepository _repository;
  final _notes = TextEditingController();
  List<ScreeningPatient> _patients = [];
  List<AnemiaScreeningRecord> _records = [];
  ScreeningPatient? _patient;
  EdgeImageInput? _image;
  AnemiaResult? _result;
  String? _patientError,
      _historyError,
      _error,
      _examinationId,
      _savedExaminationId;
  bool _loadingPatients = true,
      _loadingHistory = true,
      _busy = false,
      _saving = false,
      _reviewed = false;
  bool _history = false;
  String _search = '';
  Future<void>? _inference;

  @override
  void initState() {
    super.initState();
    _manager = widget.deviceManager ?? EdgeDeviceManager.shared;
    _repository = widget.repository ?? const SupabaseAnemiaRepository();
    _manager.addListener(_deviceChanged);
    unawaited(_manager.prepareWorkflow(EdgeAIModel.anemia));
    unawaited(_loadPatients());
    unawaited(_loadHistory());
  }

  void _deviceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _manager.removeListener(_deviceChanged);
    _manager.cancelWorkflowPreparation(EdgeAIModel.anemia);
    unawaited(_releaseOnExit());
    _notes.dispose();
    super.dispose();
  }

  Future<void> _releaseOnExit() async {
    try {
      await _inference;
      final id = _examinationId;
      if (id != null && _manager.activeExaminationId == id)
        await _manager.completeExamination(id);
    } on EdgeDeviceException {
      // Keep an uncertain session protected until reconciliation or device TTL.
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loadingPatients = true;
      _patientError = null;
    });
    try {
      final patients = await _repository.loadPatients();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        final selected = patients.where((p) => p.id == _patient?.id);
        if (_patient != null && selected.isEmpty) {
          _patient = null;
          _clearResult();
        } else if (selected.isNotEmpty) {
          _patient = selected.first;
        }
        _loadingPatients = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingPatients = false;
          _patientError =
              'Patient records could not be loaded. Check your connection and sign-in, then retry.';
        });
    }
  }

  Future<void> _loadHistory() async {
    if (mounted)
      setState(() {
        _loadingHistory = true;
        _historyError = null;
      });
    try {
      final records = await _repository.loadRecords();
      if (mounted)
        setState(() {
          _records = records;
          _loadingHistory = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingHistory = false;
          _historyError =
              'Saved screening history is unavailable. Check your connection and screening access.';
        });
    }
  }

  void _clearResult() {
    _result = null;
    _savedExaminationId = null;
    _reviewed = false;
    _notes.clear();
    _error = null;
  }

  Future<void> _chooseImage(ImageSource source) async {
    if (_busy || _saving) return;
    try {
      final EdgeImageInput? image;
      if (widget.pickImage != null) {
        image = await widget.pickImage!(source);
      } else {
        final file = await ImagePicker().pickImage(
            source: source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
        image = file == null
            ? null
            : EdgeImageInput.fromBytes(await file.readAsBytes());
      }
      if (mounted && image != null)
        setState(() {
          _image = image;
          _clearResult();
        });
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'The image could not be opened. Choose another JPEG or PNG image.');
    }
  }

  bool get _canAnalyze =>
      !_busy &&
      !_saving &&
      _patient != null &&
      _image != null &&
      _manager.state == EdgeDeviceState.ready &&
      _manager.observedReadyModel == EdgeAIModel.anemia &&
      _manager.activeExaminationId == null;

  Future<void> _analyze() async {
    if (!_canAnalyze) return;
    final image = _image!;
    final id = const Uuid().v4();
    _examinationId = id;
    setState(() {
      _clearResult();
      _busy = true;
    });
    final work = () async {
      try {
        final result = await AnemiaEdgeService(_manager)
            .analyze(image: image, examinationId: id);
        if (mounted) setState(() => _result = result);
      } on EdgeDeviceException catch (e) {
        if (mounted) setState(() => _error = e.message);
      } catch (_) {
        if (mounted)
          setState(() => _error =
              'Screening could not be completed. No valid result is available. Check the device before retrying.');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }();
    _inference = work;
    await work;
    _inference = null;
  }

  Future<void> _checkSession() async {
    try {
      await _manager.reconcileActiveExamination();
      final id = _examinationId;
      if (id != null && _manager.activeExaminationId == id)
        await _manager.completeExamination(id);
      await _manager.prepareWorkflow(EdgeAIModel.anemia);
      if (mounted)
        setState(() => _error =
            'Device session checked. Review the prepared image and start screening when ready.');
    } on EdgeDeviceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    final result = _result;
    final patient = _patient;
    if (_saving ||
        !_reviewed ||
        result == null ||
        patient == null ||
        _notes.text.trim().isEmpty ||
        _savedExaminationId == result.examinationId) return;
    setState(() => _saving = true);
    try {
      await _repository.saveReviewed(
          patient: patient,
          result: result,
          notes: _notes.text,
          reviewConfirmed: _reviewed);
      if (!mounted) return;
      setState(() {
        _savedExaminationId = result.examinationId;
        _saving = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await _loadHistory();
    } on PostgrestException catch (error) {
      if (mounted)
        _showSaveError(error.code == '42501'
            ? 'You do not have permission to save this screening for the selected patient. Ask your clinic administrator to confirm your access. Your result and notes are kept here.'
            : 'The reviewed result could not be saved. Your image, result and notes remain here; retry saving.');
    } catch (_) {
      if (mounted)
        _showSaveError(
            'The reviewed result could not be saved. Your image, result and notes remain here; retry saving.');
    }
  }

  void _showSaveError(String message) {
    setState(() {
      _saving = false;
      _error = message;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DawaTokens.surfaceSecondary,
        appBar:
            AppBar(title: const Text('HemoNix · Anemia screening'), actions: [
          IconButton(
              onPressed:
                  _busy ? null : () => setState(() => _history = !_history),
              tooltip: _history ? 'New screening' : 'Screening history',
              icon: Icon(_history ? Icons.add : Icons.history))
        ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      Text(
                          _history
                              ? 'Anemia screening history'
                              : 'HemoNix Dashboard',
                          style: DawaTextStyles.pageTitle),
                      const SizedBox(height: 6),
                      const Text(
                          'Prepare a lower-eyelid image for local AI screening, then review and save the result to the selected patient.'),
                      const SizedBox(height: 16),
                      EdgeWorkflowStatus(
                          manager: _manager,
                          model: EdgeAIModel.anemia,
                          examinationId: _examinationId),
                      if (_manager.activeExaminationId == _examinationId &&
                          _examinationId != null &&
                          !_busy &&
                          {EdgeDeviceState.error, EdgeDeviceState.busy}
                              .contains(_manager.state))
                        TextButton.icon(
                            onPressed: _checkSession,
                            icon: const Icon(Icons.sync),
                            label:
                                const Text('Check interrupted device session')),
                      const SizedBox(height: 16),
                      _panel('Prototype model',
                          const Text(AnemiaResult.prototypeNotice)),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: DawaTokens.statusDanger))),
                      const SizedBox(height: 16),
                      if (_history)
                        _historyPanel()
                      else ...[
                        LayoutBuilder(builder: (context, constraints) {
                          final patient = _patientPanel();
                          final image = _imagePanel();
                          if (constraints.maxWidth < 760)
                            return Column(children: [
                              patient,
                              const SizedBox(height: 16),
                              image
                            ]);
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: patient),
                                const SizedBox(width: 16),
                                Expanded(child: image)
                              ]);
                        }),
                        const SizedBox(height: 16),
                        _panel(
                            '3. Local AI screening',
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                      'The image is sent to the local Dawa device only when you start screening. No online fallback is used.'),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                      onPressed: _canAnalyze ? _analyze : null,
                                      icon: const Icon(Icons.biotech),
                                      label: Text(_busy
                                          ? 'Screening image…'
                                          : 'Start anemia screening')),
                                  if (_busy)
                                    const Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: LinearProgressIndicator()),
                                  if (_patient == null || _image == null)
                                    const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                            'Select a patient and prepare an image to continue.')),
                                ])),
                        if (_result != null) ...[
                          const SizedBox(height: 16),
                          _resultPanel(_result!)
                        ],
                      ],
                    ])))),
      );

  Widget _panel(String title, Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: DawaTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DawaTokens.border)),
      child: Material(
          type: MaterialType.transparency,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: DawaTextStyles.cardTitle),
            const SizedBox(height: 12),
            child,
          ])));

  Widget _patientPanel() => _panel(
      '1. Select patient',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loadingPatients)
          const LinearProgressIndicator()
        else if (_patientError != null) ...[
          Text(_patientError!),
          TextButton(
              onPressed: _loadPatients,
              child: const Text('Retry patient records'))
        ] else if (_patients.isEmpty)
          const Text(
              'No patients are assigned for anemia screening. Ask your clinic administrator to confirm your screening access, then refresh.')
        else ...[
          TextField(
              enabled: !_busy && !_saving,
              decoration: const InputDecoration(
                  labelText: 'Search patient name or ID',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (value) =>
                  setState(() => _search = value.toLowerCase())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              key: ValueKey(_patient?.id),
              initialValue: _patient?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Patient'),
              items: _patients
                  .where((p) =>
                      p.id == _patient?.id ||
                      '${p.name} ${p.id}'.toLowerCase().contains(_search))
                  .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} · ${p.id}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: _busy || _saving
                  ? null
                  : (id) => setState(() {
                        _patient = _patients.firstWhere((p) => p.id == id);
                        _clearResult();
                      })),
          if (_patient != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Screening will be linked to ${_patient!.name} (${_patient!.id}).')),
        ],
        if (!_busy && !_saving)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _loadPatients,
                  child: const Text('Refresh patients'))),
      ]));

  Widget _imagePanel() => _panel(
      '2. Prepare lower-eyelid image',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Use a clear close-up of the lower eyelid as specified by the device model. Review focus and lighting before screening. This workflow does not use a blood sample or measure Hb.'),
        const SizedBox(height: 12),
        if (_image != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Image.memory(_image!.bytes,
                  height: 210,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                      'Image preview unavailable. Choose a readable image.'))),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _busy || _saving
                  ? null
                  : () => _chooseImage(ImageSource.gallery),
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose image')),
          OutlinedButton.icon(
              onPressed: _busy || _saving
                  ? null
                  : () => _chooseImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take photo')),
        ]),
      ]));

  Widget _resultPanel(AnemiaResult result) => _panel(
      '4. Clinician review',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _classificationCard(result),
        if (result.lowConfidence)
          const Text(
              'Low-confidence estimate. Do not treat this classification as a confirmed finding.',
              style: TextStyle(color: DawaTokens.statusWarning)),
        const SizedBox(height: 8),
        for (final p in result.probabilities.entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${p.key}: ${(p.value * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                        value: p.value,
                        color: _classificationColor(p.key),
                        minHeight: 5),
                  ])),
        const SizedBox(height: 12),
        Text(result.disclaimer),
        const SizedBox(height: 12),
        TextField(
            controller: _notes,
            enabled: !_saving && _savedExaminationId == null,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Clinician findings and follow-up notes'),
            onChanged: (_) => setState(() {})),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _reviewed,
            onChanged: _saving || _savedExaminationId != null
                ? null
                : (v) => setState(() => _reviewed = v ?? false),
            title: const Text(
                'I reviewed the image, prototype limitations and AI estimate.')),
        FilledButton.icon(
            onPressed: _saving ||
                    !_reviewed ||
                    _notes.text.trim().isEmpty ||
                    _savedExaminationId != null
                ? null
                : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving
                ? 'Saving…'
                : _savedExaminationId != null
                    ? 'Reviewed screening saved'
                    : 'Save reviewed screening')),
      ]));

  Future<void> _openSavedRecord(String id) async {
    try {
      final record = await _repository.loadRecord(id);
      if (!mounted) return;
      if (record == null) {
        setState(() => _error =
            'This screening is unavailable or your access has changed.');
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('${record.patientName} · Reviewed screening'),
                  content: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        _classificationCard(record.result),
                        const SizedBox(height: 12),
                        Text(record.result.disclaimer),
                        const SizedBox(height: 12),
                        Text('Clinician notes: ${record.reviewNotes}'),
                        const SizedBox(height: 12),
                        Text('Examination: ${record.result.examinationId}'),
                        Text(
                            'Model: ${record.modelId} · Device: ${record.result.deviceId}'),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'The saved screening could not be reopened. Check your connection and permissions.');
    }
  }

  Color _classificationColor(String label) => switch (label) {
        'No Anemia' => DawaTokens.statusSuccess,
        'Mild Anemia' => DawaTokens.statusWarning,
        'Moderate Anemia' => const Color(0xFFEA580C),
        _ => DawaTokens.statusDanger,
      };

  Widget _classificationCard(AnemiaResult result) => Container(
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
          color: _classificationColor(result.classification)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AI estimate: ${result.classification}',
            style: DawaTextStyles.cardTitle
                .copyWith(color: _classificationColor(result.classification))),
        Text(
            'Model confidence: ${(result.confidence * 100).toStringAsFixed(1)}%'),
      ]));

  Widget _historyPanel() => _panel(
      'Saved reviewed screenings',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loadingHistory)
          const LinearProgressIndicator()
        else if (_historyError != null)
          Text(_historyError!)
        else if (_records.isEmpty)
          const Text('No reviewed anemia screenings have been saved.')
        else
          for (final record in _records)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${record.patientName} · ${record.result.classification}'),
                subtitle: Text(
                    '${record.patientId} · ${record.createdAt.toLocal().toString().split('.').first} · Reviewed'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSavedRecord(record.id)),
        TextButton(
            onPressed: _loadHistory, child: const Text('Refresh history')),
      ]));
}
