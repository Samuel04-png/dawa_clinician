import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import '/backend/supabase/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '/application/create_mom/create_patient_modal_widget.dart';
import '/application/home/data/home_dashboard_repository.dart';
import '/application/home/widgets/home_dashboard_content.dart';
import '/application/patient_details/patient_details_widget.dart';
import '/backend/backend.dart';
import '/components/navigation_design_system.dart';
import '/components/workspace_page_header.dart';
import '/components/workspace_shell.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/edge_device/edge_device_manager.dart';
import 'patient_registry_filters.dart';
export 'moms_model.dart';

class MomsWidget extends StatefulWidget {
  const MomsWidget({super.key, this.repository, this.deviceManager, this.now});
  final HomeDashboardRepository? repository;
  final EdgeDeviceManager? deviceManager;
  final DateTime Function()? now;
  static String routeName = 'Moms';
  static String routePath = '/moms';
  @override
  State<MomsWidget> createState() => _MomsWidgetState();
}

class _MomsWidgetState extends State<MomsWidget> {
  late final repository = widget.repository ??
      const SupabaseHomeDashboardRepository(includeRegistryFields: true);
  final searchController = TextEditingController();
  final searchFocus = FocusNode();
  AsyncSnapshot<List<DashboardPatient>> patients =
      const AsyncSnapshot.waiting();
  PatientRegistryFilter filter = PatientRegistryFilter.all;
  int request = 0;
  StreamSubscription<AuthState>? authSubscription;
  DateTime get now => (widget.now?.call() ?? DateTime.now()).toLocal();

  @override
  void initState() {
    super.initState();
    FFAppState().selectedPage = 'Patients';
    final source = repository;
    if (source is SupabaseHomeDashboardRepository) {
      final client = source.client ?? supabaseClient;
      var userId = client.auth.currentUser?.id;
      authSubscription = client.auth.onAuthStateChange.listen((event) {
        final nextUserId = event.session?.user.id;
        if (!mounted || userId == nextUserId) return;
        userId = nextUserId;
        searchController.clear();
        filter = PatientRegistryFilter.all;
        // Clear the previous account's data immediately. Generation tracking
        // prevents an older in-flight request from restoring it.
        unawaited(_reload());
      });
    }
    _reload();
  }

  @override
  void dispose() {
    request++;
    authSubscription?.cancel();
    searchController.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final current = ++request;
    setState(() => patients = const AsyncSnapshot.waiting());
    try {
      final records = await repository.loadPatients();
      if (mounted && current == request)
        setState(() =>
            patients = AsyncSnapshot.withData(ConnectionState.done, records));
    } catch (error) {
      if (mounted && current == request)
        setState(() =>
            patients = AsyncSnapshot.withError(ConnectionState.done, error));
    }
  }

  Future<void> _newPatient() async {
    final result = await showDialog<CreatePatientModalResult>(
        context: context, builder: (_) => const CreatePatientModalWidget());
    if (!mounted) return;
    if (result?.existingPatientReference != null) {
      await _openReference(result!.existingPatientReference!);
    } else if (result?.created == true) {
      await _reload();
    }
  }

  Future<void> _openReference(DocumentReference reference,
      {String? firstEncounterId}) async {
    FFAppState().makingFIrstEncounter = false;
    await context.pushNamed(PatientDetailsWidget.routeName, queryParameters: {
      'momDetails': serializeParam(reference, ParamType.DocumentReference)!,
      if (firstEncounterId != null)
        'firstEncounter': serializeParam(
            FirstEncounterRecord.collection.doc(firstEncounterId),
            ParamType.DocumentReference)!,
    });
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) => WorkspaceShell(
        currentPage: 'Patients',
        onRefresh: _reload,
        headerBuilder: (openNavigation) => WorkspacePageHeader(
            title: 'Patients',
            subtitle: 'Manage patient records and clinical history.',
            onOpenNavigation: openNavigation,
            deviceManager: widget.deviceManager,
            action: FilledButton.icon(
                onPressed: _newPatient,
                icon: const Icon(PhosphorIconsRegular.userPlus, size: 18),
                label: const Text('New Patient'),
                style: FilledButton.styleFrom(
                    backgroundColor: NavigationTokens.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))))),
        slivers: _slivers(),
      );

  List<Widget> _slivers() {
    final records = patients.data;
    final searched = records
            ?.where((p) => registryMatchesSearch(p, searchController.text))
            .toList() ??
        [];
    final visible =
        searched.where((p) => registryMatchesFilter(p, filter, now)).toList();
    return [
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _metrics(records),
        const SizedBox(height: 24),
        _searchAndFilters(),
        const SizedBox(height: 16),
      ])),
      if (patients.hasError)
        SliverToBoxAdapter(
            child: _surface(DashboardMessage(
                title: 'Patient registry unavailable',
                message: dashboardError(patients.error, 'patient records'),
                onRetry: _reload)))
      else if (records == null)
        SliverToBoxAdapter(
            child: _surface(const DashboardSkeleton(
                rows: 6, label: 'Loading patient records')))
      else if (visible.isEmpty)
        SliverToBoxAdapter(
            child: _surface(DashboardMessage(
                title: records.isEmpty
                    ? 'No patients registered yet'
                    : 'No matching patients',
                message: records.isEmpty
                    ? 'Use New Patient to register a patient.'
                    : 'Try another search or change the selected filter.',
                action: records.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => filter = PatientRegistryFilter.all);
                          searchFocus.requestFocus();
                        },
                        child: const Text('Clear search and filters')))))
      else ...[
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                          'Showing ${visible.length} of ${records.length} patients',
                          style: DashboardStyles.secondary),
                      TextButton.icon(
                          onPressed: _reload,
                          icon: const Icon(PhosphorIconsRegular.arrowClockwise,
                              size: 16),
                          label: const Text('Refresh')),
                    ]))),
        SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
          final patient = visible[index];
          return RegistryPatientRow(
              key: ValueKey(patient.id),
              patient: patient,
              now: now,
              first: index == 0,
              last: index == visible.length - 1,
              onOpen: () => _openReference(
                  MotherRecord.collection.doc(patient.id),
                  firstEncounterId: patient.firstEncounterId));
        }, childCount: visible.length)),
      ],
    ];
  }

  Widget _surface(Widget child) => Material(
      color: NavigationTokens.surface,
      shape: DashboardStyles.shape,
      child: child);

  Widget _metrics(List<DashboardPatient>? records) =>
      LayoutBuilder(builder: (context, size) {
        final values = [
          records?.length,
          records?.where((p) => p.missingFields.isNotEmpty).length,
          records?.where((p) => p.firstEncounterId != null).length
        ];
        final labels = [
          'Total patients',
          'Needs completion',
          'With first encounter'
        ];
        final short = ['Patients', 'To complete', 'First visit'];
        final details = [
          'Visible to your account',
          'Required registration details',
          'Linked first encounter'
        ];
        final icons = [
          PhosphorIconsRegular.users,
          PhosphorIconsRegular.notePencil,
          PhosphorIconsRegular.clipboardText
        ];
        final stack = MediaQuery.textScalerOf(context).scale(14) > 21;
        final cards = [
          for (var i = 0; i < 3; i++)
            DashboardMetric(
                label: labels[i],
                shortLabel: short[i],
                value: values[i]?.toString(),
                detail: details[i],
                icon: icons[i],
                loading: patients.connectionState == ConnectionState.waiting,
                explanation: patients.hasError
                    ? 'Patient data unavailable. Retry the registry request.'
                    : null,
                onTap: records == null
                    ? null
                    : () => setState(() => filter = [
                          PatientRegistryFilter.all,
                          PatientRegistryFilter.needsCompletion,
                          PatientRegistryFilter.firstEncounter
                        ][i]))
        ];
        if (stack)
          return Column(children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i]
            ]
          ]);
        return IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i])
          ]
        ]));
      });

  Widget _searchAndFilters() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: searchController,
            focusNode: searchFocus,
            onChanged: (_) => setState(() {}),
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            style: DashboardStyles.body,
            decoration: InputDecoration(
                labelText: 'Search patients',
                hintText: 'Name, patient ID, phone, NRC or location',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                    size: 20, color: NavigationTokens.secondary),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                          searchFocus.requestFocus();
                        },
                        icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: NavigationTokens.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: NavigationTokens.brand, width: 2)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 0, children: [
          for (final option in PatientRegistryFilter.values)
            Tooltip(
                message: option.description,
                child: ChoiceChip(
                  label: Text(option.label),
                  selected: filter == option,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => filter = option),
                  selectedColor: NavigationTokens.selected,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: filter == option
                          ? NavigationTokens.brand.withValues(alpha: .4)
                          : NavigationTokens.border),
                  labelStyle: DashboardStyles.secondary.copyWith(
                      color: filter == option
                          ? NavigationTokens.brand
                          : NavigationTokens.secondary,
                      fontWeight: FontWeight.w500),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ))
        ]),
        if (filter != PatientRegistryFilter.all) ...[
          const SizedBox(height: 8),
          Text(filter.description, style: DashboardStyles.secondary),
        ],
      ]);
}

class RegistryPatientRow extends StatelessWidget {
  const RegistryPatientRow(
      {super.key,
      required this.patient,
      required this.now,
      required this.onOpen,
      this.first = false,
      this.last = false});
  final DashboardPatient patient;
  final DateTime now;
  final VoidCallback onOpen;
  final bool first, last;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 860 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final age = registryPatientAge(patient, now);
        final words = patient.name
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
        final initials = words.isEmpty
            ? '?'
            : words.take(2).map((p) => p.characters.first.toUpperCase()).join();
        final updated = patient.activityAt == null
            ? null
            : 'Updated ${DateFormat('d MMM y').format(patient.activityAt!.toLocal())}';
        final status = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  patient.missingFields.isEmpty
                      ? 'Registration complete'
                      : 'Needs completion',
                  style: DashboardStyles.secondary.copyWith(
                      color: patient.missingFields.isEmpty
                          ? NavigationTokens.secondary
                          : NavigationTokens.warning)),
              if (patient.missingFields.isNotEmpty)
                Text('Missing ${patient.missingFields.join(', ')}',
                    style: DashboardStyles.secondary),
            ]);
        final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(patient.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardStyles.body
                      .copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                  patient.identifier.isEmpty
                      ? 'Record ${patient.id}'
                      : 'ID ${patient.identifier}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardStyles.secondary),
              if (patient.imported)
                const Text('Dawa Mom', style: DashboardStyles.secondary),
            ]);
        final radius = BorderRadius.vertical(
            top: first ? const Radius.circular(14) : Radius.zero,
            bottom: last ? const Radius.circular(14) : Radius.zero);
        return Semantics(
            button: true,
            label: 'Open patient record',
            child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: radius,
                    side: const BorderSide(color: NavigationTokens.border)),
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: radius,
                  hoverColor: NavigationTokens.hover,
                  focusColor: NavigationTokens.selected,
                  splashColor: NavigationTokens.pressed,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                                child: CircleAvatar(
                                    radius: 17,
                                    backgroundColor: NavigationTokens.selected,
                                    child: Text(initials,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: NavigationTokens.brand)))),
                            const SizedBox(width: 12),
                            if (wide) ...[
                              Expanded(flex: 5, child: identity),
                              const SizedBox(width: 16),
                              SizedBox(
                                  width: 64,
                                  child: Text(age == null ? '—' : '$age years',
                                      style: DashboardStyles.secondary,
                                      semanticsLabel: age == null
                                          ? 'Age unavailable'
                                          : '$age years old')),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: status),
                              const SizedBox(width: 16),
                              SizedBox(
                                  width: 130,
                                  child: Text(
                                      updated ?? 'Activity date unavailable',
                                      style: DashboardStyles.secondary)),
                            ] else
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    identity,
                                    const SizedBox(height: 8),
                                    if (age != null || updated != null) ...[
                                      Text(
                                          [
                                            if (age != null) '$age years',
                                            if (updated != null) updated
                                          ].join(' · '),
                                          style: DashboardStyles.secondary),
                                      const SizedBox(height: 4)
                                    ],
                                    status,
                                  ])),
                            const SizedBox(width: 12),
                            const ExcludeSemantics(
                                child: Icon(PhosphorIconsRegular.caretRight,
                                    size: 18,
                                    color: NavigationTokens.secondary)),
                          ])),
                )));
      });
}
