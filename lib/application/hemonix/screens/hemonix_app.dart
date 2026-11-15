import '/services/clinical_offline_store.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '/components/dawa_design_system.dart';
import '/components/clinical_page_intro.dart' show ClinicalStatusChip;
import 'package:go_router/go_router.dart';
import '/components/clinical_tab_bar.dart';
import '/components/navigation_design_system.dart';
import '/components/edge_workflow_status.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_image_input.dart';
import '/services/screening_patient_repository.dart';
import '../models/anemia_result.dart';
import '../repository/anemia_repository.dart';
import '../services/anemia_online_service.dart';
import '../services/anemia_analysis_service.dart';

class HemonixApp extends StatefulWidget {
  const HemonixApp(
      {super.key,
      this.deviceManager,
      this.repository,
      this.pickImage,
      this.allowOnlineFallback = AnemiaOnlineConfig.allowFallback,
      this.onlineService = const AnemiaOnlineService()});
  static String routeName = 'HemoNix';
  static String routePath = '/hemonix';
  final bool allowOnlineFallback;
  final AnemiaOnlineService onlineService;
  final EdgeDeviceManager? deviceManager;
  final AnemiaRepository? repository;
  final Future<EdgeImageInput?> Function(ImageSource source)? pickImage;

  @override
  State<HemonixApp> createState() => _HemonixAppState();
}

class _HemonixAppState extends State<HemonixApp> {
  late final EdgeDeviceManager _manager;
  late final AnemiaRepository _repository;
  late final AnemiaAnalysisService _analysis;
  bool _analysingOnline = false;
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
    _analysis = AnemiaAnalysisService(_manager,
        allowOnlineFallback: widget.allowOnlineFallback,
        online: widget.onlineService);
    _manager.addListener(_deviceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_manager.prepareWorkflow(EdgeAIModel.anemia));
    });
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
          _patientError = ClinicalOfflineStore.offline
              ? 'No downloaded anemia assignments are available. Connect online to download assigned patients; an empty online list means screening access needs to be configured.'
              : 'Patient records could not be loaded. Check your connection and sign-in, then retry.';
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
      _analysis.canAnalyze;

  Future<void> _analyze() async {
    if (!_canAnalyze) return;
    final image = _image!;
    final id = const Uuid().v4();
    _examinationId = id;
    setState(() {
      _clearResult();
      _busy = true;
      _analysingOnline = false;
    });
    final work = () async {
      try {
        final result = await _analysis.analyze(
            image: image,
            examinationId: id,
            isCancelled: () => !mounted,
            onOnline: () {
              if (mounted) setState(() => _analysingOnline = true);
            });
        if (mounted) setState(() => _result = result);
      } on AnemiaAnalysisCancelled {
        // Navigation ended this screening attempt. Do not start an online call.
      } on AnemiaOnlineException catch (e) {
        if (mounted) setState(() => _error = e.message);
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
      if (ClinicalOfflineStore.offline)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Reviewed screening saved on this device. It will sync when online.')));
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
        backgroundColor: NavigationTokens.canvas,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              ClinicalTabBar(
                tabs: const [
                  ClinicalTab('New Screening', icon: Icons.add),
                  ClinicalTab('History', icon: Icons.history)
                ],
                activeIndex: _history ? 1 : 0,
                enabled: !_busy && !_saving,
                onSelected: (index) => setState(() => _history = index == 1),
              ),
              Expanded(child: LayoutBuilder(builder: (context, size) {
                final padding = size.maxWidth < 600 ? 16.0 : 24.0;
                return ListView(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
                    children: [
                      Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: DawaTokens.workspaceMaxWidth),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!_history) ...[
                                    _workflowSteps(),
                                    const SizedBox(height: 16)
                                  ],
                                  EdgeWorkflowStatus(
                                      manager: _manager,
                                      model: EdgeAIModel.anemia,
                                      compact: true,
                                      examinationId: _examinationId,
                                      isRelevant: !_history ||
                                          _patient != null ||
                                          _image != null ||
                                          _busy ||
                                          _examinationId != null),
                                  if (_manager.activeExaminationId ==
                                          _examinationId &&
                                      _examinationId != null &&
                                      !_busy &&
                                      {
                                        EdgeDeviceState.error,
                                        EdgeDeviceState.busy
                                      }.contains(_manager.state))
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                            onPressed: _checkSession,
                                            icon: const Icon(Icons.sync),
                                            label: const Text(
                                                'Check interrupted device session'))),
                                  _prototypeNoticePanel(),
                                  const SizedBox(height: 16),
                                  if (_history)
                                    _historyPanel()
                                  else ...[
                                    _patientPanel(),
                                    const SizedBox(height: 20),
                                    if (_result != null) ...[
                                      _resultPanel(_result!),
                                      const SizedBox(height: 16),
                                      Material(
                                          color: Colors.transparent,
                                          child: ExpansionTile(
                                            tilePadding: EdgeInsets.zero,
                                            title: const Text(
                                                'Image and screening controls'),
                                            children: [_preparationLayout()],
                                          )),
                                    ] else
                                      _preparationLayout(),
                                  ],
                                ]),
                          )),
                    ]);
              })),
            ])),
      );

  Widget _workflowSteps() {
    final completed = [
      _patient != null,
      _image != null,
      _result != null,
      _savedExaminationId != null
    ];
    final current = _patient == null
        ? 0
        : _image == null
            ? 1
            : _result == null
                ? 2
                : 3;
    const labels = ['Patient', 'Image', 'Screening', 'Review & save'];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var index = 0; index < labels.length; index++)
        Semantics(
            label:
                'Step ${index + 1}, ${labels[index]}, ${completed[index] ? 'complete' : current == index ? 'current' : 'pending'}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: current == index
                      ? NavigationTokens.selected
                      : DawaTokens.surface,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                  border: Border.all(
                      color: current == index
                          ? NavigationTokens.brand
                          : DawaTokens.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (completed[index])
                  const Icon(Icons.check_rounded,
                      size: 16, color: NavigationTokens.brand)
                else
                  Text('${index + 1}',
                      style: DawaTextStyles.secondary
                          .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(labels[index],
                    style: DawaTextStyles.secondary.copyWith(
                        color: current == index
                            ? NavigationTokens.brand
                            : DawaTokens.textSecondary,
                        fontWeight: current == index
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ]),
            )),
    ]);
  }

  Widget _preparationLayout() => LayoutBuilder(builder: (context, size) {
        final image = _imagePanel();
        final analysis = _analysisPanel();
        if (MediaQuery.sizeOf(context).width <
                NavigationTokens.desktopBreakpoint ||
            size.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, const SizedBox(height: 16), analysis]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: image),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: analysis),
        ]);
      });

  Widget _analysisPanel() => _panel(
      '3. AI screening',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _preparedItem(
            _patient != null, _patient?.name ?? 'Patient selection required'),
        const SizedBox(height: 10),
        _preparedItem(_image != null,
            _image == null ? 'Lower-eyelid image required' : 'Image prepared'),
        const Divider(height: 28, color: DawaTokens.border),
        Text(
            widget.allowOnlineFallback
                ? 'When you start screening, the image is analysed on the Dawa device if ready. If unavailable, the image is sent to the online Anemia service. Patient details and notes are not sent.'
                : 'The image is sent to the local Dawa device only when you start screening. Online analysis is disabled.',
            style: DawaTextStyles.secondary),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: _canAnalyze ? _analyze : null,
            icon: const Icon(Icons.biotech_outlined, size: 18),
            label: Text(_busy ? 'Screening image…' : 'Start anemia screening')),
        if (_busy)
          Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                  semanticsLabel: _analysingOnline
                      ? 'Device unavailable — analysing online'
                      : 'Analyzing the image on the Dawa device')),
        const SizedBox(height: 10),
        Semantics(
            liveRegion: true,
            child: Text(
                _patient == null
                    ? 'Select a patient above to continue.'
                    : _image == null
                        ? 'Choose or take a lower-eyelid image to continue.'
                        : !_canAnalyze
                            ? _screeningBlockerMessage()
                            : !_analysis.edgeReady
                                ? 'Dawa device unavailable — analysis will run online.'
                                : 'Ready to screen the selected patient.',
                style: DawaTextStyles.secondary.copyWith(fontSize: 12))),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _workflowMessage(_error!),
                    TextButton(
                        onPressed: _canAnalyze ? _analyze : null,
                        child: const Text('Retry screening')),
                  ])),
      ]));

  Widget _preparedItem(bool ready, String label) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            ready
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked,
            size: 18,
            color: ready ? NavigationTokens.brand : DawaTokens.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: DawaTextStyles.body)),
      ]);

  String _screeningBlockerMessage() {
    if (_busy)
      return _analysingOnline
          ? 'Device unavailable — analysing online'
          : 'Screening is already in progress.';
    if (_saving) return 'Wait for the reviewed screening to finish saving.';
    return switch (_manager.state) {
      EdgeDeviceState.loadingModel => 'Anemia AI is still preparing.',
      EdgeDeviceState.disconnected =>
        'Local AI analysis is unavailable. Reconnect the device to continue.',
      EdgeDeviceState.error =>
        'Local AI analysis is unavailable. Retry the device connection to continue.',
      EdgeDeviceState.busy =>
        'Another examination is using the device. Wait before starting this screening.',
      EdgeDeviceState.ready =>
        'The active device model is not the Anemia model yet.',
      _ => 'Preparing the local screening device. Try again when it is ready.',
    };
  }

  Widget _workflowMessage(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DawaTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: DawaTokens.border),
        ),
        child: Text(message,
            style: DawaTextStyles.secondary
                .copyWith(color: DawaTokens.textSecondary)),
      );

  Widget _prototypeNoticePanel() => Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        dense: true,
        title: const Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ClinicalStatusChip(
                  label: 'Prototype model', color: NavigationTokens.secondary),
              Text('About this model')
            ]),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [
          Text(AnemiaResult.prototypeNotice,
              style: DawaTextStyles.secondary
                  .copyWith(fontSize: 12.5, height: 1.5))
        ],
      ));

  Widget _panel(String title, Widget child, {Widget? action}) => DawaCard(
      padding: const EdgeInsets.all(18),
      child: Material(
          type: MaterialType.transparency,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text(title, style: DawaTextStyles.cardTitle))),
              if (action != null) action,
            ]),
            const SizedBox(height: 12),
            child,
          ])));

  Widget _patientPanel() => _panel(
      '1. Select patient',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loadingPatients)
          const LinearProgressIndicator()
        else if (_patientError != null) ...[
          Text(_patientError!, style: DawaTextStyles.secondary),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: _loadPatients,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry patient records'))),
        ] else if (_patients.isEmpty) ...[
          Text(
              ClinicalOfflineStore.offline
                  ? 'No anemia patients downloaded for this account'
                  : 'No patients available for Anemia screening',
              style: DawaTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
              'Your anemia patient list comes from clinician and clinic assignments. If it is empty while online, those assignments need to be configured before patients can be downloaded for offline use.',
              style: DawaTextStyles.secondary),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                  onPressed: () => context.goNamed('Moms'),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Open Patients'))),
        ] else ...[
          _patientFields(),
          if (_patient != null) ...[
            const SizedBox(height: 12),
            Text(
                'Selected: ${_patient!.name} • Ref ${_patient!.id.length > 8 ? _patient!.id.substring(0, 8) : _patient!.id}',
                style: DawaTextStyles.secondary.copyWith(
                    color: NavigationTokens.brand,
                    fontWeight: FontWeight.w600)),
          ] else if (!_patients.any(
              (p) => '${p.name} ${p.id}'.toLowerCase().contains(_search))) ...[
            const SizedBox(height: 10),
            Text(
                'No patients match this search. Try another name or reference.',
                style: DawaTextStyles.secondary),
          ],
        ],
      ]),
      action: IconButton(
          tooltip: 'Refresh patients',
          onPressed: _busy || _saving ? null : _loadPatients,
          icon: const Icon(Icons.refresh_rounded, size: 18)));

  Widget _patientFields() => LayoutBuilder(builder: (context, size) {
        final search = TextFormField(
            initialValue: _search,
            enabled: !_busy && !_saving,
            decoration: const InputDecoration(
                labelText: 'Search patient name or ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: (value) =>
                setState(() => _search = value.toLowerCase()));
        final picker = DropdownButtonFormField<String>(
            key: ValueKey(_patient?.id),
            initialValue: _patient?.id,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: const InputDecoration(
                labelText: 'Patient', border: OutlineInputBorder()),
            items: _patients
                .where((p) =>
                    p.id == _patient?.id ||
                    '${p.name} ${p.id}'.toLowerCase().contains(_search))
                .map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(
                        '${p.name} · ${p.age == null ? 'Age not recorded' : '${p.age} years'} · Ref ${p.id.length > 8 ? p.id.substring(0, 8) : p.id}',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _busy || _saving
                ? null
                : (id) => setState(() {
                      _patient = _patients.firstWhere((p) => p.id == id);
                      _clearResult();
                    }));
        if (size.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(children: [search, const SizedBox(height: 12), picker]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: search),
          const SizedBox(width: 16),
          Expanded(child: picker),
        ]);
      });

  Widget _imagePanel() => _panel(
      '2. Prepare lower-eyelid image',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Use a clear close-up of the lower eyelid as specified by the device model. Review focus and lighting before screening. This workflow does not use a blood sample or measure Hb.'),
        const SizedBox(height: 12),
        if (_image != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: DawaTokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DawaTokens.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_image!.bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                              'Image preview unavailable. Choose a readable image.'))),
                ),
              ))
        else
          Container(
            height: 160,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DawaTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DawaTokens.border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_a_photo_outlined,
                  size: 30, color: DawaTokens.textMuted),
              SizedBox(height: 8),
              Text('No lower-eyelid image selected',
                  style: DawaTextStyles.secondary),
            ]),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _busy || _saving
                  ? null
                  : () => _chooseImage(ImageSource.gallery),
              icon: const Icon(Icons.upload_file),
              label: Text(_image == null ? 'Choose image' : 'Replace image')),
          OutlinedButton.icon(
              onPressed: _busy || _saving
                  ? null
                  : () => _chooseImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: Text(_image == null ? 'Take photo' : 'Retake photo')),
          if (_image != null)
            TextButton.icon(
                onPressed: _busy || _saving
                    ? null
                    : () => setState(() {
                          _image = null;
                          _clearResult();
                        }),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove image')),
        ]),
      ]));

  Widget _resultPanel(AnemiaResult result) => _panel(
      '4. Clinician review',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _resultInspectionLayout(result),
        const Text('AI estimate — clinician must review'),
        Text(
            result.isOnline
                ? 'Analysed online (device unavailable) · Analysis time not supplied by model'
                : 'Analysed on Dawa device · Analysis time not supplied by model',
            style: TextStyle(fontSize: 12, color: NavigationTokens.secondary)),
        const SizedBox(height: 12),
        Text(
            _patient == null
                ? 'Clinician review'
                : 'Review for ${_patient!.name}',
            style: DawaTextStyles.cardTitle),
        const SizedBox(height: 4),
        Text(
            'Review the AI estimate alongside the clinical assessment before saving.',
            style: DawaTextStyles.secondary),
        const SizedBox(height: 10),
        TextField(
            controller: _notes,
            enabled: !_saving && _savedExaminationId == null,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Clinician findings and follow-up notes',
                helperText: 'Required before saving the reviewed screening',
                helperMaxLines: 3),
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
        if (_error != null) ...[
          const SizedBox(height: 12),
          _workflowMessage(_error!),
        ],
        if (_savedExaminationId != null)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: () => setState(() => _history = true),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('View saved history'))),
      ]));

  Widget _resultInspectionLayout(AnemiaResult result) {
    final output =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('AI-estimated classification', style: DawaTextStyles.cardTitle),
      const SizedBox(height: 8),
      _classificationCard(result),
      if (result.lowConfidence) ...[
        const SizedBox(height: 8),
        const Text(
            'Low-confidence estimate. Do not treat this classification as a confirmed finding.',
            style: TextStyle(color: DawaTokens.statusWarningText)),
      ],
      const SizedBox(height: 12),
      Text('Model output probabilities',
          style:
              DawaTextStyles.secondary.copyWith(fontWeight: FontWeight.w700)),
      for (final p in result.probabilities.entries)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${p.key}: ${(p.value * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
                value: p.value,
                color: DawaTokens.brandPrimary,
                backgroundColor: DawaTokens.surfaceTertiary,
                minHeight: 5),
          ]),
        ),
      const SizedBox(height: 12),
      _workflowMessage(result.disclaimer),
    ]);
    final image = _image == null
        ? const SizedBox.shrink()
        : Container(
            height: 300,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: DawaTokens.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DawaTokens.border)),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_image!.bytes, fit: BoxFit.contain)),
          );
    return LayoutBuilder(builder: (context, constraints) {
      if (_image == null || constraints.maxWidth < 820) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_image != null) image,
              if (_image != null) const SizedBox(height: 16),
              output,
            ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: image),
        const SizedBox(width: 18),
        Expanded(child: output),
      ]);
    });
  }

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
                        Text('Model output probabilities',
                            style: DawaTextStyles.cardTitle),
                        const SizedBox(height: 6),
                        for (final probability
                            in record.result.probabilities.entries)
                          Text(
                              '${probability.key}: ${(probability.value * 100).toStringAsFixed(1)}%'),
                        const SizedBox(height: 12),
                        Text(record.result.disclaimer),
                        const SizedBox(height: 12),
                        Text('Clinician notes: ${record.reviewNotes}'),
                        const SizedBox(height: 12),
                        Text('Examination: ${record.result.examinationId}'),
                        Text(record.result.isOnline
                            ? 'Model: ${record.modelId} · Online service: ${record.result.onlineServiceUrl}'
                            : 'Model: ${record.modelId} · Device: ${record.result.deviceId}'),
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
          color: DawaTokens.brandPrimaryPale,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DawaTokens.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result.classification,
            style: DawaTextStyles.cardTitle
                .copyWith(color: DawaTokens.textPrimary)),
        Text(
            'Highest-scoring model class: ${(result.confidence * 100).toStringAsFixed(1)}%'),
      ]));

  Widget _historyPanel() => _panel(
      'Saved reviewed screenings',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loadingHistory)
          const LinearProgressIndicator()
        else if (_historyError != null)
          Text(_historyError!)
        else if (_records.isEmpty) ...[
          const Text('No reviewed anemia screenings have been saved.'),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () => setState(() => _history = false),
                  child: const Text('Start a screening'))),
        ] else
          for (final record in _records) ...[
            DawaCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: const Icon(Icons.fact_check_outlined,
                      color: DawaTokens.brandPrimary),
                  title:
                      Text(record.patientName, style: DawaTextStyles.cardTitle),
                  subtitle: Text(
                      '${record.createdAt.toLocal().toString().split('.').first} • ${record.result.classification} • Reviewed'),
                  trailing: TextButton(
                      onPressed: () => _openSavedRecord(record.id),
                      child: const Text('Open')),
                  onTap: () => _openSavedRecord(record.id),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        TextButton(
            onPressed: _loadHistory, child: const Text('Refresh history')),
      ]));
}
