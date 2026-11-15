import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, PostgrestException;
import '/application/home/data/home_dashboard_repository.dart';
import '/application/home/widgets/home_dashboard_content.dart';
import '/backend/backend.dart';
import '/components/navigation_design_system.dart';
import '/components/workspace_page_header.dart';
import '/components/workspace_shell.dart';
import '/features/appointments/data/appointment_workspace_repository.dart';
import '/features/appointments/domain/appointment_entry.dart';
import '/features/appointments/domain/clinician_appointment.dart';
import '/features/appointments/presentation/appointment_workspace_content.dart';
import '/features/appointments/presentation/dawa_mom_appointment_requests.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/index.dart';
import 'schedule_appointment_dialog.dart';
export 'scheduled_encounters_model.dart';

class ScheduledEncountersWidget extends StatefulWidget {
  const ScheduledEncountersWidget(
      {super.key,
      this.initialAppointmentId,
      this.openCalendar = false,
      this.repository,
      this.deviceManager,
      this.now});
  final String? initialAppointmentId;
  final bool openCalendar;
  final AppointmentWorkspaceRepository? repository;
  final EdgeDeviceManager? deviceManager;
  final DateTime Function()? now;
  static String routeName = 'ScheduledEncounters';
  static String routePath = '/scheduledEncounters';
  @override
  State<ScheduledEncountersWidget> createState() =>
      _ScheduledEncountersWidgetState();
}

class _ScheduledEncountersWidgetState extends State<ScheduledEncountersWidget> {
  late final repository =
      widget.repository ?? const AppointmentWorkspaceRepository();
  AsyncSnapshot<List<AppointmentEntry>> appointments =
      const AsyncSnapshot.waiting();
  final search = TextEditingController();
  final busy = <String>{};
  StreamSubscription<AuthState>? authSubscription;
  StreamSubscription<List<ClinicianAppointment>>? appointmentChanges;
  Timer? refreshTimer;
  String? doctorId, message;
  String source = 'all', status = 'all', query = '';
  DateTime? date;
  late DateTime calendarDay;
  AppointmentView view = AppointmentView.today;
  late bool calendar;
  bool scheduling = false;
  int request = 0;
  String? focusedId;
  DateTime get clinicNow =>
      appointmentClinicTime(widget.now?.call() ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    FFAppState().selectedPage = 'Appointments';
    calendar = widget.openCalendar;
    calendarDay = appointmentDay(clinicNow);
    focusedId = widget.initialAppointmentId;
    if (widget.repository == null || widget.repository!.client != null) {
      var userId = repository.database.auth.currentUser?.id;
      authSubscription =
          repository.database.auth.onAuthStateChange.listen((event) {
        final next = event.session?.user.id;
        if (!mounted || userId == next) return;
        userId = next;
        Navigator.of(context).popUntil((route) => route is PageRoute);
        search.clear();
        query = '';
        source = 'all';
        status = 'all';
        view = AppointmentView.today;
        doctorId = null;
        message = null;
        focusedId = null;
        _watchAppointments();
        unawaited(_reload());
      });
      _watchAppointments();
    }
    unawaited(_reload());
  }

  void _watchAppointments() {
    appointmentChanges?.cancel();
    refreshTimer?.cancel();
    appointmentChanges = repository.watchDawaMomAppointments().listen((_) {
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) unawaited(_reload());
      });
    }, onError: (Object _) {
      if (mounted)
        setState(() => message =
            'Automatic updates are unavailable. Use Refresh appointments to check the latest records.');
    });
  }

  @override
  void dispose() {
    request++;
    authSubscription?.cancel();
    appointmentChanges?.cancel();
    refreshTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final current = ++request;
    setState(() => appointments = const AsyncSnapshot.waiting());
    try {
      final clinician = await repository.loadClinician();
      if (clinician == null) throw StateError('Clinician profile unavailable');
      final entries = await repository.loadAppointments(clinician.id);
      if (!mounted || current != request) return;
      doctorId = clinician.id;
      FFAppState().doctor = DoctorRecord.collection.doc(clinician.id);
      setState(() =>
          appointments = AsyncSnapshot.withData(ConnectionState.done, entries));
      if (focusedId != null) {
        final matches =
            entries.where((a) => a.id == focusedId && !a.legacy).toList();
        focusedId = null;
        if (matches.isNotEmpty)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusAppointment(matches.first);
          });
        else
          setState(() =>
              message = 'That appointment is unavailable to this account.');
      }
    } catch (error) {
      if (mounted && current == request)
        setState(() => appointments =
            AsyncSnapshot.withError(ConnectionState.done, error));
    }
  }

  void _focusAppointment(AppointmentEntry entry) {
    setState(() {
      view = entry.pending
          ? AppointmentView.requests
          : entry.inView(AppointmentView.upcoming, clinicNow)
              ? AppointmentView.upcoming
              : entry.inView(AppointmentView.today, clinicNow)
                  ? AppointmentView.today
                  : AppointmentView.history;
      source = 'all';
      status = 'all';
      query = '';
      date = null;
      search.clear();
      if (entry.startsAt != null) calendarDay = appointmentDay(entry.startsAt!);
    });
    _details(entry);
  }

  @override
  Widget build(BuildContext context) => WorkspaceShell(
        currentPage: 'Appointments',
        deviceManager: widget.deviceManager,
        notifications: DawaMomNotificationButton(
            repository: repository,
            onOpenAppointment: (id) {
              final matches = appointments.data
                      ?.where((a) => a.id == id && !a.legacy)
                      .toList() ??
                  [];
              if (matches.isNotEmpty)
                _focusAppointment(matches.first);
              else {
                focusedId = id;
                unawaited(_reload());
              }
            }),
        onRefresh: _reload,
        headerBuilder: (openNavigation) => WorkspacePageHeader(
            title: 'Appointments',
            fitTitle: true,
            subtitle: 'Manage scheduled visits and patient requests.',
            onOpenNavigation: openNavigation,
            deviceManager: widget.deviceManager,
            action: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                      onPressed:
                          doctorId == null || scheduling ? null : _schedule,
                      icon: const Icon(PhosphorIconsRegular.calendarPlus,
                          size: 18),
                      label: const Text('Schedule Appointment'),
                      style: FilledButton.styleFrom(
                          backgroundColor: NavigationTokens.brand,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)))),
                ])),
        slivers: [
          SliverToBoxAdapter(
              child: AppointmentWorkspaceContent(
                  entries: appointments.data,
                  view: view,
                  now: clinicNow,
                  source: source,
                  status: status,
                  query: query,
                  searchController: search,
                  onView: (value) => setState(() {
                        view = value;
                        message = null;
                      }),
                  onSource: (value) => setState(() => source = value),
                  onStatus: (value) => setState(() => status = value),
                  onSearch: (value) => setState(() => query = value),
                  calendar: calendar,
                  onCalendar: (value) => setState(() => calendar = value),
                  calendarDay: calendarDay,
                  onCalendarDay: (value) => setState(() => calendarDay = value),
                  date: date,
                  onDate: (value) => setState(() {
                        date = value;
                        if (value != null) calendarDay = value;
                      }),
                  onRefresh: () {
                    message = null;
                    unawaited(_reload());
                  },
                  onSchedule: _schedule,
                  onRetry: () => unawaited(_reload()),
                  onOpen: _details,
                  onAction: _action,
                  busy: busy,
                  message: message,
                  loading:
                      appointments.connectionState == ConnectionState.waiting,
                  error: appointments.error))
        ],
      );

  Future<void> _schedule() async {
    if (scheduling) return;
    setState(() => scheduling = true);
    try {
      final patients = await repository.loadSchedulingPatients();
      if (!mounted) return;
      final records = patients
          .map((p) => MotherRecord.getDocumentFromData(
              {'name': p.displayName}, MotherRecord.collection.doc(p.id)))
          .toList();
      await showScheduleAppointmentDialog(context,
          availablePatients: records, clinicNow: clinicNow);
      if (mounted) await _reload();
    } catch (_) {
      if (mounted)
        setState(() => message =
            'Could not load patients for scheduling. Refresh and try again.');
    } finally {
      if (mounted) setState(() => scheduling = false);
    }
  }

  void _action(AppointmentEntry entry, String action) {
    if (busy.contains(entry.key)) return;
    if (action == 'reschedule')
      unawaited(_reschedule(entry));
    else
      unawaited(_change(entry, action));
  }

  Future<bool> _confirm(AppointmentEntry entry, String action,
          {String? details}) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                scrollable: true,
                title: Text('$action appointment?'),
                content: Text(
                    '${entry.displayName}\n${entry.startsAt == null ? 'Date unavailable' : DateFormat('d MMM y, HH:mm').format(entry.startsAt!)}\n'
                    '${entry.pending && entry.pastDated(clinicNow) ? 'This request is past-dated. Review the date before deciding.\n' : ''}'
                    '${details ?? (entry.imported ? 'This update will use the existing Dawa Mom synchronization workflow.' : 'This will update the recorded appointment.')}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Keep current appointment')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(action))
                ],
              )) ??
      false;

  Future<void> _change(AppointmentEntry entry, String next,
      {DateTime? start, String? endTime, bool alreadyBusy = false}) async {
    if (doctorId == null || (!alreadyBusy && busy.contains(entry.key))) return;
    if (!alreadyBusy) setState(() => busy.add(entry.key));
    try {
      final label = switch (next) {
        'confirmed' => 'Confirm',
        'declined' => 'Decline',
        'cancelled' || 'canceled' => 'Cancel',
        'completed' => 'Complete',
        _ => 'Reschedule'
      };
      if (!await _confirm(entry, label,
              details: start == null
                  ? null
                  : 'New visit time ${DateFormat('d MMM y, HH:mm').format(start)}${endTime == null ? '' : '–$endTime'} · Africa/Lusaka') ||
          !mounted) return;
      await repository.changeAppointment(entry, doctorId!, next,
          start: start, endTime: endTime);
      if (mounted) {
        await _reload();
        if (mounted) setState(() => message = 'Appointment updated.');
      }
    } catch (error) {
      if (!mounted) return;
      await _reload();
      if (mounted)
        setState(() => message = error is AppointmentChangedException ||
                error is PostgrestException && error.code == '40001'
            ? 'This appointment changed. The list has been refreshed. Review its current state before trying again.'
            : 'The update could not be confirmed. Review the refreshed appointment before retrying.');
    } finally {
      if (mounted) setState(() => busy.remove(entry.key));
    }
  }

  Future<void> _reschedule(AppointmentEntry entry) async {
    setState(() => busy.add(entry.key));
    try {
      final now = clinicNow;
      final earliest = appointmentDay(now);
      final original = entry.startsAt;
      final initial = original != null && original.isAfter(now)
          ? appointmentDay(original)
          : earliest;
      final selectedDate = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: earliest,
          lastDate: DateTime(now.year + 2));
      if (selectedDate == null || !mounted) return;
      final selectedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(original ?? now));
      if (selectedTime == null || !mounted) return;
      final start = DateTime(selectedDate.year, selectedDate.month,
          selectedDate.day, selectedTime.hour, selectedTime.minute);
      if (!start.isAfter(clinicNow)) {
        setState(
            () => message = 'Choose a future date and time in Africa/Lusaka.');
        return;
      }
      var duration = const Duration(minutes: 30);
      if (original != null && entry.endTime.isNotEmpty) {
        final end = DateTime(
            original.year,
            original.month,
            original.day,
            int.parse(entry.endTime.substring(0, 2)),
            int.parse(entry.endTime.substring(3, 5)));
        if (end.isAfter(original)) duration = end.difference(original);
      }
      final end = start.add(duration);
      if (appointmentDay(end) != appointmentDay(start)) {
        setState(() => message = 'Choose a visit that ends on the same date.');
        return;
      }
      await _change(entry, 'rescheduled',
          start: start,
          endTime: DateFormat('HH:mm').format(end),
          alreadyBusy: true);
    } finally {
      if (mounted) setState(() => busy.remove(entry.key));
    }
  }

  Future<void> _details(AppointmentEntry entry) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: Text(entry.displayName),
            content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(entry.identifier, style: DashboardStyles.secondary),
                      const SizedBox(height: 12),
                      Text(entry.startsAt == null
                          ? 'Date unavailable'
                          : '${DateFormat('EEEE, d MMMM y').format(entry.startsAt!)} · ${entry.timeLabel}'),
                      const Text('Africa/Lusaka',
                          style: DashboardStyles.secondary),
                      const SizedBox(height: 12),
                      Text('${entry.statusLabel} · ${entry.sourceLabel}'),
                      if (entry.pending && entry.pastDated(clinicNow))
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                                'Past-dated request. A clinician decision is still required.')),
                      if (entry.type.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(entry.type)),
                      if (entry.reason.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(entry.reason)),
                      if (entry.notes.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(entry.notes)),
                      if (entry.imported && entry.integrationStatus.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                                switch (entry.integrationStatus) {
                                  'failed' =>
                                    'The update did not reach Dawa Mom. A server retry is required.',
                                  'pending' ||
                                  'retrying' =>
                                    'The update is awaiting Dawa Mom synchronization.',
                                  'synced' => 'Synchronized with Dawa Mom.',
                                  _ =>
                                    'Synchronization status ${entry.integrationStatus}',
                                },
                                style: DashboardStyles.secondary)),
                    ]))),
            actions: [
              if (entry.patientId.isNotEmpty && !entry.patientUnavailable)
                TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      unawaited(_openRecord(entry, false));
                    },
                    child: const Text('Open patient')),
              if (entry.encounterId != null &&
                  entry.patientId.isNotEmpty &&
                  !entry.patientUnavailable &&
                  (!entry.closed || entry.hasCompletedEncounter))
                TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      unawaited(_openRecord(entry, true));
                    },
                    child: Text(entry.hasCompletedEncounter
                        ? 'View encounter'
                        : 'Open encounter')),
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close')),
            ],
          ));

  Future<void> _openRecord(AppointmentEntry entry, bool encounter) async {
    final patient = MotherRecord.collection.doc(entry.patientId);
    final parameters = <String, String>{
      encounter && entry.hasCompletedEncounter ? 'momDets' : 'momDetails':
          serializeParam(patient, ParamType.DocumentReference)!,
      if (entry.firstEncounterId != null)
        'firstEncounter': serializeParam(
            FirstEncounterRecord.collection.doc(entry.firstEncounterId!),
            ParamType.DocumentReference)!,
      if (encounter && entry.encounterId != null)
        'encounterDetails': serializeParam(
            EncounterRecord.collection.doc(entry.encounterId!),
            ParamType.DocumentReference)!,
    };
    final route = !encounter
        ? PatientDetailsWidget.routeName
        : entry.hasCompletedEncounter
            ? EncounterDetsWidget.routeName
            : entry.firstEncounterId == null
                ? MomDetailsWidget.routeName
                : EditEncounterWidget.routeName;
    await context.pushNamed(route, queryParameters: parameters);
    if (mounted) await _reload();
  }
}
