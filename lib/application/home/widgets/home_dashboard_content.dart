import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/components/navigation_design_system.dart';
import '../data/home_dashboard_repository.dart';

abstract final class DashboardStyles {
  static const heading = TextStyle(
      fontSize: 17,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: NavigationTokens.text);
  static const body =
      TextStyle(fontSize: 14, height: 1.4, color: NavigationTokens.text);
  static const secondary =
      TextStyle(fontSize: 12, height: 1.45, color: NavigationTokens.secondary);
  static const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      side: BorderSide(color: NavigationTokens.border));
}

class HomeDashboardContent extends StatelessWidget {
  const HomeDashboardContent(
      {super.key,
      required this.patients,
      this.now,
      required this.schedule,
      required this.onPatients,
      required this.onAppointments,
      required this.onCalendar,
      required this.onNewPatient,
      required this.onExamination,
      required this.onSchedule,
      required this.onPatient,
      required this.onAppointment,
      required this.onRetryPatients,
      required this.onRetrySchedule,
      required this.onCompletion});
  final DateTime? now;
  final AsyncSnapshot<List<DashboardPatient>> patients;
  final AsyncSnapshot<List<DashboardAppointment>> schedule;
  final VoidCallback onCalendar,
      onPatients,
      onAppointments,
      onNewPatient,
      onExamination,
      onSchedule,
      onRetryPatients,
      onRetrySchedule,
      onCompletion;
  final ValueChanged<DashboardPatient> onPatient;
  final ValueChanged<DashboardAppointment> onAppointment;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final overview = _overview(context);
        final work = _schedule(context);
        final actions = _actions(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          overview,
          const SizedBox(height: 24),
          actions,
          const SizedBox(height: 24),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: work),
              const SizedBox(width: 24),
              Expanded(flex: 6, child: _patients(context)),
            ])
          else ...[work, const SizedBox(height: 24), _patients(context)],
          const SizedBox(height: 24),
          _completion(context),
        ]);
      });

  Widget _overview(BuildContext context) {
    final cards = [
      DashboardMetric(
          label: 'Appointments today',
          shortLabel: 'Today’s visits',
          value: schedule.hasData
              ? '${schedule.data!.where((item) => sameLocalDay(item.startsAt, now ?? DateTime.now())).length}'
              : null,
          loading: schedule.connectionState == ConnectionState.waiting,
          detail:
              schedule.hasError ? 'Schedule unavailable' : 'Scheduled visits',
          icon: PhosphorIconsRegular.calendarBlank,
          onTap: onAppointments),
      const DashboardMetric(
          label: 'Pending reviews',
          shortLabel: 'Reviews',
          value: '—',
          detail: 'Review queue unavailable',
          icon: PhosphorIconsRegular.clipboardText,
          explanation:
              'The screening tools do not yet expose a shared clinician-review queue.'),
      DashboardMetric(
          label: 'Registered patients',
          shortLabel: 'Patients',
          value: patients.hasData ? '${patients.data!.length}' : null,
          loading: patients.connectionState == ConnectionState.waiting,
          detail: patients.hasError
              ? 'Patients unavailable'
              : 'Visible to your account',
          icon: PhosphorIconsRegular.users,
          onTap: onPatients),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      if (MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: cards[i]),
          ]
        ]);
      }
      return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ]
      ]));
    });
  }

  Widget _schedule(BuildContext context) => _Panel(
        title: 'Recent schedules',
        action: TextButton(
            onPressed: onCalendar, child: const Text('View calendar')),
        child: schedule.hasError
            ? DashboardMessage(
                title: 'Schedule unavailable',
                message: dashboardError(schedule.error, 'appointments'),
                onRetry: onRetrySchedule)
            : !schedule.hasData
                ? const DashboardSkeleton(rows: 3)
                : schedule.data!.isEmpty
                    ? DashboardMessage(
                        title: 'No recent scheduled visits.',
                        message:
                            'Scheduled visits from the past 30 days appear here.',
                        icon: PhosphorIconsRegular.calendarCheck,
                        action: TextButton.icon(
                            onPressed: onSchedule,
                            icon:
                                const Icon(PhosphorIconsRegular.plus, size: 16),
                            label: const Text('Schedule Appointment')))
                    : Column(children: [
                        for (final appointment in schedule.data!.take(4))
                          _ScheduleRow(
                              appointment: appointment,
                              onTap: () => onAppointment(appointment)),
                        if (schedule.data!.length > 4)
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: TextButton(
                                  onPressed: onAppointments,
                                  child: Text(
                                      'View all ${schedule.data!.length} appointments'))),
                      ]),
      );

  Widget _actions(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final stack = MediaQuery.textScalerOf(context).scale(14) > 21;
        final compact = constraints.maxWidth < 650;
        final actions = [
          _QuickAction(
              label: 'New Patient',
              subtitle: 'Register a patient',
              icon: PhosphorIconsRegular.userPlus,
              onTap: onNewPatient,
              compact: compact && !stack),
          _QuickAction(
              label: 'New Examination',
              subtitle: 'Start a clinical screening',
              icon: PhosphorIconsRegular.stethoscope,
              onTap: onExamination,
              primary: true,
              compact: compact && !stack),
          _QuickAction(
              label: 'Schedule Appointment',
              subtitle: 'Book a patient visit',
              icon: PhosphorIconsRegular.calendarPlus,
              onTap: onSchedule,
              compact: compact && !stack),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Quick actions', style: DashboardStyles.heading)),
          if (stack) ...[
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              actions[i],
            ]
          ] else
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: actions[i]),
                  ]
                ])),
        ]);
      });

  Widget _patients(BuildContext context) => _Panel(
        title: 'Recent patients',
        action:
            TextButton(onPressed: onPatients, child: const Text('View all')),
        child: patients.hasError
            ? DashboardMessage(
                title: 'Patient records unavailable',
                message: dashboardError(patients.error, 'patient records'),
                onRetry: onRetryPatients)
            : !patients.hasData
                ? const DashboardSkeleton(rows: 4)
                : patients.data!.isEmpty
                    ? DashboardMessage(
                        title: 'No patient records available.',
                        message: 'Register a patient to begin.',
                        icon: PhosphorIconsRegular.users,
                        action: TextButton(
                            onPressed: onNewPatient,
                            child: const Text('New Patient')))
                    : Column(children: [
                        for (final patient in patients.data!.take(5))
                          DashboardPatientRow(
                              patient: patient, onTap: () => onPatient(patient))
                      ]),
      );

  Widget _completion(BuildContext context) {
    if (!patients.hasData) return const SizedBox.shrink();
    final incomplete = patients.data!
        .where((patient) => patient.missingFields.isNotEmpty)
        .length;
    if (incomplete == 0) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFFFFBF3),
      shape: DashboardStyles.shape,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(PhosphorIconsRegular.notePencil,
                    size: 20, color: NavigationTokens.warning),
                const SizedBox(width: 10),
                Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '$incomplete ${incomplete == 1 ? 'record needs' : 'records need'} completion',
                          style: DashboardStyles.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      const Text(
                          'Required registration details are missing. Review name, date of birth or phone number.',
                          style: DashboardStyles.secondary),
                    ])),
              ]),
              TextButton(
                  onPressed: onCompletion,
                  child: const Text('View affected records')),
            ],
          )),
    );
  }
}

class DashboardMetric extends StatelessWidget {
  const DashboardMetric(
      {required this.label,
      required this.value,
      required this.detail,
      required this.icon,
      this.onTap,
      this.loading = false,
      this.explanation,
      this.shortLabel});
  final String label, detail;
  final String? value, explanation, shortLabel;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return _Surface(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                      message: label,
                      child: Text(compact ? shortLabel ?? label : label,
                          style: DashboardStyles.secondary.copyWith(
                              color: NavigationTokens.text,
                              fontWeight: FontWeight.w500))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: loading
                            ? const _SkeletonBar(width: 36, height: 28)
                            : Text(value ?? '—',
                                style: const TextStyle(
                                    fontSize: 28,
                                    height: 1.15,
                                    fontWeight: FontWeight.w600,
                                    color: NavigationTokens.text))),
                    if (!compact)
                      Icon(icon, size: 20, color: NavigationTokens.secondary),
                  ]),
                  if (!compact || explanation != null) ...[
                    const SizedBox(height: 4),
                    Tooltip(
                        message: explanation ?? detail,
                        child: Text(
                            compact && explanation != null
                                ? 'Unavailable'
                                : detail,
                            style: DashboardStyles.secondary)),
                  ],
                ])));
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => _Surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
            child: SizedBox(
                width: double.infinity,
                child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(title, style: DashboardStyles.heading),
                      if (action != null) action!
                    ]))),
        const Divider(height: 1, color: NavigationTokens.border),
        child,
      ]));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: NavigationTokens.surface,
      shape: DashboardStyles.shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              hoverColor: NavigationTokens.hover,
              highlightColor: NavigationTokens.pressed,
              focusColor: NavigationTokens.selected,
              child: child));
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.label,
      required this.subtitle,
      required this.icon,
      required this.onTap,
      this.primary = false,
      this.compact = false});
  final String label, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary, compact;
  @override
  Widget build(BuildContext context) => _Surface(
      onTap: onTap,
      child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 14),
          child: compact
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 21, color: NavigationTokens.brand),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: DashboardStyles.body
                          .copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                ])
              : Row(children: [
                  Icon(icon, size: 21, color: NavigationTokens.brand),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: DashboardStyles.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: DashboardStyles.secondary),
                      ])),
                  const SizedBox(width: 8),
                  Icon(PhosphorIconsRegular.arrowUpRight,
                      size: 16,
                      color: primary
                          ? NavigationTokens.brand
                          : NavigationTokens.secondary),
                ])));
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.appointment, required this.onTap});
  final DashboardAppointment appointment;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      hoverColor: NavigationTokens.hover,
      focusColor: NavigationTokens.selected,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: MediaQuery.textScalerOf(context).scale(54),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('d MMM').format(appointment.startsAt),
                          style: DashboardStyles.secondary),
                      const SizedBox(height: 3),
                      Text(DateFormat.Hm().format(appointment.startsAt),
                          style: DashboardStyles.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ])),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(appointment.patientName,
                      style: DashboardStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${appointment.type} · ${appointment.status}',
                      style: DashboardStyles.secondary),
                ])),
            const SizedBox(width: 8),
            const Icon(PhosphorIconsRegular.caretRight,
                size: 16, color: NavigationTokens.secondary),
          ])));
}

class DashboardPatientRow extends StatelessWidget {
  const DashboardPatientRow(
      {super.key, required this.patient, required this.onTap});
  final DashboardPatient patient;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final words = patient.displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final initials =
        words.map((word) => word.characters.first).join().toUpperCase();
    return Column(children: [
      InkWell(
          onTap: onTap,
          hoverColor: NavigationTokens.hover,
          focusColor: NavigationTokens.selected,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(children: [
                CircleAvatar(
                    radius: 17,
                    backgroundColor: NavigationTokens.selected,
                    child: Text(initials,
                        style: const TextStyle(
                            fontSize: 11,
                            color: NavigationTokens.brand,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(patient.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DashboardStyles.body
                              .copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                          'ID ${patient.identifier.isEmpty ? patient.id : patient.identifier}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DashboardStyles.secondary),
                      if (patient.missingFields.isNotEmpty)
                        Text(
                            'Record incomplete · ${patient.missingFields.join(', ')}',
                            style: DashboardStyles.secondary
                                .copyWith(color: NavigationTokens.warning)),
                    ])),
                if (patient.activityAt != null &&
                    MediaQuery.sizeOf(context).width >= 700) ...[
                  const SizedBox(width: 12),
                  Text(
                      'Updated ${DateFormat('d MMM').format(patient.activityAt!.toLocal())}',
                      style: DashboardStyles.secondary),
                ],
                const SizedBox(width: 12),
                const Icon(PhosphorIconsRegular.caretRight,
                    size: 16, color: NavigationTokens.secondary),
              ]))),
      const Divider(height: 1, indent: 64, color: NavigationTokens.border),
    ]);
  }
}

String dashboardError(Object? error, String subject) {
  if (error is AuthException ||
      error is PostgrestException &&
          ['42501', 'PGRST301', '403'].contains(error.code)) {
    return 'Your account cannot access these $subject. Check your sign-in or contact your clinic administrator.';
  }
  return 'Could not load $subject. Check your connection and try again.';
}

class DashboardMessage extends StatelessWidget {
  const DashboardMessage(
      {super.key,
      required this.title,
      this.message,
      this.icon,
      this.action,
      this.onRetry});
  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, size: 24, color: NavigationTokens.secondary),
          const SizedBox(height: 12)
        ],
        Text(title,
            style: DashboardStyles.body.copyWith(fontWeight: FontWeight.w500)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, style: DashboardStyles.secondary)
        ],
        if (action != null) ...[const SizedBox(height: 8), action!],
        if (onRetry != null)
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
              label: const Text('Retry')),
      ]));
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton(
      {super.key, this.rows = 3, this.label = 'Loading dashboard data'});
  final int rows;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            for (var i = 0; i < rows; i++)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    _SkeletonBar(width: 32, height: 28),
                    SizedBox(width: 12),
                    Expanded(
                        child: _SkeletonBar(width: double.infinity, height: 18))
                  ])),
          ])));
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});
  final double width, height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: NavigationTokens.hover,
              borderRadius: BorderRadius.circular(5))));
}
