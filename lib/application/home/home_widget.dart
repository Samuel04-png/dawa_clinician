import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '/application/create_mom/create_patient_modal_widget.dart';
import '/application/patient_details/patient_details_widget.dart';
import '/application/scheduled_encounters/schedule_appointment_dialog.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/components/workspace_shell.dart';
import '/services/edge_device/edge_device_manager.dart';
import 'data/home_dashboard_repository.dart';
import 'home_dashboard_header.dart';
import 'widgets/home_dashboard_content.dart';
import 'widgets/home_examination_selector.dart';
export 'home_model.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget(
      {super.key,
      this.firstEncounter,
      this.repository,
      this.deviceManager,
      this.now});
  final DocumentReference? firstEncounter;
  final HomeDashboardRepository? repository;
  final EdgeDeviceManager? deviceManager;
  final DateTime Function()? now;
  static String routeName = 'Home';
  static String routePath = '/home';
  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  late final repository =
      widget.repository ?? const SupabaseHomeDashboardRepository();
  AsyncSnapshot<DashboardClinician?> clinician = const AsyncSnapshot.waiting();
  AsyncSnapshot<List<DashboardPatient>> patients =
      const AsyncSnapshot.waiting();
  AsyncSnapshot<List<DashboardAppointment>> schedule =
      const AsyncSnapshot.waiting();
  late DateTime localNow;
  Timer? clock;
  int profileRequest = 0, patientRequest = 0, scheduleRequest = 0;

  @override
  void initState() {
    super.initState();
    localNow = (widget.now?.call() ?? DateTime.now()).toLocal();
    FFAppState().selectedPage = 'Home';
    unawaited(_loadClinician());
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = (widget.now?.call() ?? DateTime.now()).toLocal();
      final changedDay = !sameLocalDay(localNow, next);
      if (next.hour != localNow.hour || changedDay) {
        setState(() => localNow = next);
        if (changedDay && clinician.hasData) unawaited(_loadSchedule());
      }
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    profileRequest++;
    patientRequest++;
    scheduleRequest++;
    super.dispose();
  }

  Future<void> _loadClinician() async {
    final request = ++profileRequest;
    setState(() => clinician = const AsyncSnapshot.waiting());
    try {
      final profile = await repository.loadClinician();
      if (!mounted || request != profileRequest) return;
      if (profile == null || !profile.profileComplete) {
        context.goNamed(CompleteClincianRegWidget.routeName);
        return;
      }
      FFAppState().doctor = DoctorRecord.collection.doc(profile.id);
      setState(() =>
          clinician = AsyncSnapshot.withData(ConnectionState.done, profile));
      await Future.wait([_loadPatients(), _loadSchedule()]);
    } catch (error) {
      if (mounted && request == profileRequest)
        setState(() =>
            clinician = AsyncSnapshot.withError(ConnectionState.done, error));
    }
  }

  Future<void> _loadPatients() async {
    final request = ++patientRequest;
    if (mounted) setState(() => patients = const AsyncSnapshot.waiting());
    try {
      final records = await repository.loadPatients();
      if (mounted && request == patientRequest)
        setState(() =>
            patients = AsyncSnapshot.withData(ConnectionState.done, records));
    } catch (error) {
      if (mounted && request == patientRequest)
        setState(() =>
            patients = AsyncSnapshot.withError(ConnectionState.done, error));
    }
  }

  Future<void> _loadSchedule() async {
    final profile = clinician.data;
    if (profile == null) return;
    final request = ++scheduleRequest;
    if (mounted) setState(() => schedule = const AsyncSnapshot.waiting());
    try {
      final appointments =
          await repository.loadSchedule(profile.id, localNow, lookbackDays: 30);
      if (mounted && request == scheduleRequest)
        setState(() => schedule =
            AsyncSnapshot.withData(ConnectionState.done, appointments));
    } catch (error) {
      if (mounted && request == scheduleRequest)
        setState(() =>
            schedule = AsyncSnapshot.withError(ConnectionState.done, error));
    }
  }

  Future<void> _refresh() async {
    localNow = (widget.now?.call() ?? DateTime.now()).toLocal();
    await Future.wait([_loadPatients(), _loadSchedule()]);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return WorkspaceShell(
      currentPage: 'Home',
      deviceManager: widget.deviceManager,
      onRefresh: _refresh,
      headerBuilder: (openNavigation) => HomeDashboardHeader(
          greeting: dashboardGreeting(localNow),
          date: DateFormat('EEEE, d MMMM y').format(localNow),
          onOpenNavigation: openNavigation,
          deviceManager: widget.deviceManager),
      slivers: [SliverToBoxAdapter(child: _content())],
    );
  }

  Widget _content() {
    if (clinician.hasError)
      return DashboardMessage(
          title: 'Dashboard unavailable',
          message: dashboardError(clinician.error, 'dashboard data'),
          onRetry: _loadClinician);
    if (!clinician.hasData) return const DashboardSkeleton(rows: 6);
    return HomeDashboardContent(
        now: localNow,
        patients: patients,
        schedule: schedule,
        onPatients: () => context.goNamed(MomsWidget.routeName),
        onAppointments: () =>
            context.goNamed(ScheduledEncountersWidget.routeName),
        onCalendar: () async {
          await context.pushNamed(ScheduledEncountersWidget.routeName,
              queryParameters: {'calendar': 'true'});
          if (mounted) await _loadSchedule();
        },
        onNewPatient: _newPatient,
        onExamination: _newExamination,
        onSchedule: _scheduleAppointment,
        onPatient: _openPatient,
        onAppointment: _openAppointment,
        onRetryPatients: _loadPatients,
        onRetrySchedule: _loadSchedule,
        onCompletion: _showCompletion);
  }

  Future<void> _newPatient() async {
    final result = await showDialog<CreatePatientModalResult>(
        context: context, builder: (_) => const CreatePatientModalWidget());
    if (!mounted) return;
    if (result?.existingPatientReference != null) {
      context.pushNamed(PatientDetailsWidget.routeName, queryParameters: {
        'momDetails': serializeParam(
            result!.existingPatientReference, ParamType.DocumentReference)!,
      });
    } else if (result?.created == true) {
      await _loadPatients();
    }
  }

  void _newExamination() => showDialog<void>(
      context: context,
      builder: (_) => HomeExaminationSelector(onSelected: (route) async {
            await context.pushNamed(route);
            if (mounted) await _refresh();
          }));

  Future<void> _scheduleAppointment() async {
    if (!patients.hasData) await _loadPatients();
    if (!mounted || !patients.hasData) return;
    final records = patients.data!
        .map((patient) => MotherRecord.getDocumentFromData(
            {'name': patient.name}, MotherRecord.collection.doc(patient.id)))
        .toList();
    await showScheduleAppointmentDialog(context, availablePatients: records);
    if (mounted) await _loadSchedule();
  }

  Future<void> _openPatient(DashboardPatient patient) async {
    await context.pushNamed(PatientDetailsWidget.routeName, queryParameters: {
      'momDetails': serializeParam(MotherRecord.collection.doc(patient.id),
          ParamType.DocumentReference)!,
      if (patient.firstEncounterId != null)
        'firstEncounter': serializeParam(
            FirstEncounterRecord.collection.doc(patient.firstEncounterId!),
            ParamType.DocumentReference)!,
    });
    if (mounted) await _loadPatients();
  }

  Future<void> _openAppointment(DashboardAppointment appointment) async {
    try {
      if (appointment.imported) {
        await context.pushNamed(ScheduledEncountersWidget.routeName,
            queryParameters: {'appointment': appointment.id});
        return;
      }
      final matching = (patients.data ?? [])
          .where((patient) => patient.id == appointment.patientId);
      if (matching.isEmpty) {
        await context.pushNamed(ScheduledEncountersWidget.routeName);
        return;
      }
      final patient = matching.first;
      await context.pushNamed(
          patient.firstEncounterId == null
              ? MomDetailsWidget.routeName
              : EditEncounterWidget.routeName,
          queryParameters: {
            'momDetails': serializeParam(
                MotherRecord.collection.doc(patient.id),
                ParamType.DocumentReference)!,
            'encounterDetails': serializeParam(
                EncounterRecord.collection.doc(appointment.id),
                ParamType.DocumentReference)!,
            if (patient.firstEncounterId != null)
              'firstEncounter': serializeParam(
                  FirstEncounterRecord.collection
                      .doc(patient.firstEncounterId!),
                  ParamType.DocumentReference)!,
          });
    } finally {
      if (mounted) await _refresh();
    }
  }

  void _showCompletion() => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('Records needing completion'),
            content: SizedBox(
                width: 560,
                height: MediaQuery.sizeOf(context).height * .55,
                child: ListView(children: [
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          'The registration form requires a patient name, date of birth and phone number.',
                          style: DashboardStyles.secondary)),
                  for (final patient in patients.data!
                      .where((record) => record.missingFields.isNotEmpty))
                    DashboardPatientRow(
                        patient: patient,
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openPatient(patient);
                        }),
                ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'))
            ],
          ));
}
