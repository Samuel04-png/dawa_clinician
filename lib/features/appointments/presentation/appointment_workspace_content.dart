import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '/application/home/widgets/home_dashboard_content.dart';
import '/components/navigation_design_system.dart';
import '/components/clinical_workspace_components.dart';
import '/flutter_flow/flutter_flow_calendar.dart';
import '../domain/appointment_entry.dart';

class AppointmentWorkspaceContent extends StatelessWidget {
  const AppointmentWorkspaceContent(
      {super.key,
      required this.entries,
      required this.view,
      required this.now,
      required this.source,
      required this.status,
      required this.query,
      required this.onView,
      required this.onSource,
      required this.onStatus,
      required this.onSearch,
      required this.searchController,
      required this.calendar,
      required this.onCalendar,
      required this.calendarDay,
      required this.onCalendarDay,
      required this.date,
      required this.onDate,
      required this.onRefresh,
      required this.onSchedule,
      required this.onOpen,
      required this.onAction,
      required this.busy,
      this.message,
      this.loading = false,
      this.error,
      required this.onRetry});
  final List<AppointmentEntry>? entries;
  final AppointmentView view;
  final DateTime now, calendarDay;
  final String source, status, query;
  final TextEditingController searchController;
  final bool calendar, loading;
  final DateTime? date;
  final Object? error;
  final String? message;
  final Set<String> busy;
  final ValueChanged<AppointmentView> onView;
  final ValueChanged<String> onSource, onStatus, onSearch;
  final ValueChanged<bool> onCalendar;
  final ValueChanged<DateTime> onCalendarDay;
  final ValueChanged<DateTime?> onDate;
  final VoidCallback onRefresh, onRetry;
  final VoidCallback onSchedule;
  final ValueChanged<AppointmentEntry> onOpen;
  final void Function(AppointmentEntry, String) onAction;

  List<AppointmentEntry> get filtered {
    final result = entries
            ?.where((a) =>
                a.inView(view, now) &&
                appointmentMatches(a, query, source, status, date))
            .toList() ??
        [];
    if (view == AppointmentView.history)
      result.sort((a, b) => (b.startsAt ?? DateTime(1970))
          .compareTo(a.startsAt ?? DateTime(1970)));
    return result;
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final tab in AppointmentView.values)
            ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tab.label),
                  if (entries != null) ...[
                    const SizedBox(width: 8),
                    Text('${entries!.where((a) => a.inView(tab, now)).length}',
                        style: const TextStyle(fontSize: 12))
                  ]
                ]),
                selected: view == tab,
                showCheckmark: false,
                onSelected: (_) => onView(tab),
                selectedColor: NavigationTokens.selected,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: view == tab
                        ? NavigationTokens.brand
                        : NavigationTokens.border),
                labelStyle: DashboardStyles.body.copyWith(
                    color: view == tab
                        ? NavigationTokens.brand
                        : NavigationTokens.secondary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
        ]),
        const SizedBox(height: 20),
        TextField(
            controller: searchController,
            onChanged: onSearch,
            autocorrect: false,
            enableSuggestions: false,
            style: DashboardStyles.body,
            decoration: InputDecoration(
                labelText: 'Find a patient or appointment',
                filled: true,
                fillColor: Colors.white,
                prefixIcon:
                    const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          onSearch('');
                        },
                        icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: NavigationTokens.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: NavigationTokens.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: NavigationTokens.brand, width: 2)))),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, size) {
          final width = size.maxWidth < 420
              ? MediaQuery.textScalerOf(context).scale(14) > 21
                  ? size.maxWidth
                  : (size.maxWidth - 12) / 2
              : 190.0;
          return Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dropdown(
                    context,
                    'Source',
                    source,
                    {
                      'all': 'All sources',
                      for (final a in entries ?? <AppointmentEntry>[])
                        a.source: a.sourceLabel,
                      if (source != 'all' &&
                          !(entries ?? <AppointmentEntry>[])
                              .any((a) => a.source == source))
                        source: source == 'dawa_mom'
                            ? 'Dawa Mom'
                            : source == 'clinician'
                                ? 'Clinic'
                                : source
                    },
                    onSource,
                    width),
                _dropdown(
                    context,
                    'Status',
                    status,
                    {
                      'all': 'All statuses',
                      for (final a in entries ?? <AppointmentEntry>[])
                        a.status: a.statusLabel,
                      if (status != 'all' &&
                          !(entries ?? <AppointmentEntry>[])
                              .any((a) => a.status == status))
                        status: status
                    },
                    onStatus,
                    width),
                OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                          context: context,
                          initialDate: date ?? now,
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100));
                      if (selected != null) onDate(selected);
                    },
                    icon: const Icon(PhosphorIconsRegular.calendarBlank,
                        size: 18),
                    label: Text(date == null
                        ? 'Any date'
                        : DateFormat('d MMM y').format(date!))),
                if (date != null)
                  IconButton(
                      tooltip: 'Clear date filter',
                      onPressed: () => onDate(null),
                      icon: const Icon(PhosphorIconsRegular.x, size: 18)),
              ]);
        }),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                      switch (view) {
                        AppointmentView.today =>
                          'Scheduled for today · Africa/Lusaka',
                        AppointmentView.upcoming =>
                          'Confirmed visits after today · Africa/Lusaka',
                        AppointmentView.requests =>
                          'Requests awaiting a decision, including past-dated requests',
                        AppointmentView.history =>
                          'Past, closed and undated records · recorded status retained',
                      },
                      style: DashboardStyles.secondary),
                  Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                            label: const Text('List'),
                            avatar: const Icon(PhosphorIconsRegular.listBullets,
                                size: 16),
                            selected: !calendar,
                            onSelected: (_) => onCalendar(false),
                            showCheckmark: false,
                            selectedColor: NavigationTokens.selected),
                        ChoiceChip(
                            label: const Text('Calendar'),
                            avatar: const Icon(
                                PhosphorIconsRegular.calendarBlank,
                                size: 16),
                            selected: calendar,
                            onSelected: (_) => onCalendar(true),
                            showCheckmark: false,
                            selectedColor: NavigationTokens.selected),
                        IconButton(
                            tooltip: 'Refresh appointments',
                            onPressed: onRefresh,
                            icon: const Icon(
                                PhosphorIconsRegular.arrowClockwise,
                                size: 20)),
                      ]),
                ])),
        if (message != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                  liveRegion: true,
                  child: Text(message!,
                      style: DashboardStyles.body
                          .copyWith(color: NavigationTokens.text)))),
        const SizedBox(height: 16),
        if (error != null)
          DashboardMessage(
              title: 'Appointments unavailable',
              message: dashboardError(error, 'appointments'),
              onRetry: onRetry)
        else if (loading || entries == null)
          const DashboardSkeleton(rows: 4, label: 'Loading appointments')
        else if (calendar)
          _calendar(context)
        else if (filtered.isEmpty)
          ClinicalEmptyState(
              icon: view == AppointmentView.requests
                  ? Icons.inbox_outlined
                  : Icons.event_available_outlined,
              title: switch (view) {
                AppointmentView.today => 'No appointments today',
                AppointmentView.upcoming => 'No upcoming appointments',
                AppointmentView.requests => 'No appointment requests',
                AppointmentView.history => 'No appointment history',
              },
              message: query.isNotEmpty ||
                      source != 'all' ||
                      status != 'all' ||
                      date != null
                  ? 'No appointments match these filters. Clear or adjust them to continue.'
                  : switch (view) {
                      AppointmentView.today =>
                        'Schedule a visit or review upcoming appointments.',
                      AppointmentView.upcoming =>
                        'Schedule a future visit when the patient is ready.',
                      AppointmentView.requests =>
                        'New requests will appear here when they are received.',
                      AppointmentView.history =>
                        'Completed and closed appointments will appear here.',
                    },
              actionLabel: query.isNotEmpty ||
                      source != 'all' ||
                      status != 'all' ||
                      date != null
                  ? 'Clear filters'
                  : view == AppointmentView.today ||
                          view == AppointmentView.upcoming
                      ? 'Schedule appointment'
                      : view == AppointmentView.requests
                          ? 'View today'
                          : 'View upcoming',
              onAction: query.isNotEmpty ||
                      source != 'all' ||
                      status != 'all' ||
                      date != null
                  ? () {
                      searchController.clear();
                      onSearch('');
                      onSource('all');
                      onStatus('all');
                      onDate(null);
                    }
                  : view == AppointmentView.today ||
                          view == AppointmentView.upcoming
                      ? onSchedule
                      : () => onView(view == AppointmentView.requests
                          ? AppointmentView.today
                          : AppointmentView.upcoming))
        else ...[
          for (final entry in filtered)
            Padding(
                padding: const EdgeInsets.only(bottom: 8), child: _row(entry))
        ],
      ]);

  Widget _dropdown(
          BuildContext context,
          String label,
          String selected,
          Map<String, String> values,
          ValueChanged<String> onChanged,
          double width) =>
      SizedBox(
          width: width,
          child: DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: label,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: NavigationTokens.border))),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.merge(DashboardStyles.body),
              icon: const Icon(PhosphorIconsRegular.caretDown, size: 16),
              items: values.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              }));

  Widget _row(AppointmentEntry entry) => SizedBox(
      width: double.infinity,
      child: AppointmentWorkspaceRow(
          key: ValueKey(entry.key),
          entry: entry,
          now: now,
          busy: busy.contains(entry.key),
          onOpen: () => onOpen(entry),
          onAction: (status) => onAction(entry, status)));

  Widget _calendar(BuildContext context) {
    final selected = filtered
        .where((a) =>
            a.startsAt != null &&
            appointmentDay(a.startsAt!) == appointmentDay(calendarDay))
        .toList();
    final month = Material(
        color: Colors.white,
        shape: DashboardStyles.shape,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: FlutterFlowCalendar(
                key: ValueKey('appointments-calendar-$calendarDay'),
                color: NavigationTokens.brand,
                initialDate: calendarDay,
                markedDates: filtered
                    .where((a) => a.startsAt != null)
                    .map((a) => a.startsAt!)
                    .toList(),
                onChange: (range) {
                  if (range != null &&
                      appointmentDay(range.start) !=
                          appointmentDay(calendarDay))
                    onCalendarDay(range.start);
                },
                rowHeight:
                    MediaQuery.textScalerOf(context).scale(14) > 21 ? 52 : 38,
                titleStyle: DashboardStyles.heading,
                dateStyle: DashboardStyles.secondary,
                dayOfWeekStyle: DashboardStyles.secondary,
                inactiveDateStyle: DashboardStyles.secondary,
                selectedDateStyle:
                    DashboardStyles.secondary.copyWith(color: Colors.white))));
    final agenda =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(DateFormat('EEEE, d MMMM y').format(calendarDay),
          style: DashboardStyles.heading),
      const SizedBox(height: 12),
      if (selected.isEmpty)
        const DashboardMessage(
            title: 'No appointments on this date',
            message: 'The calendar uses the current view and filters.')
      else
        for (final entry in selected)
          Padding(
              padding: const EdgeInsets.only(bottom: 8), child: _row(entry)),
    ]);
    return LayoutBuilder(
        builder: (context, size) => size.maxWidth >= 1000 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 340, child: month),
                const SizedBox(width: 24),
                Expanded(child: agenda)
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: month),
                const SizedBox(height: 24),
                agenda
              ]));
  }
}

class AppointmentWorkspaceRow extends StatelessWidget {
  const AppointmentWorkspaceRow(
      {super.key,
      required this.entry,
      required this.now,
      required this.busy,
      required this.onOpen,
      required this.onAction});
  final AppointmentEntry entry;
  final DateTime now;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: DashboardStyles.shape,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (context, size) {
            final narrow = size.maxWidth < 800 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(entry.identifier,
                      style: DashboardStyles.secondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (entry.type.isNotEmpty || entry.reason.isNotEmpty)
                    Text(entry.type.isNotEmpty ? entry.type : entry.reason,
                        style: DashboardStyles.secondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ]);
            final schedule = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      entry.startsAt == null
                          ? 'Date unavailable'
                          : DateFormat('d MMM y').format(entry.startsAt!),
                      style: DashboardStyles.body),
                  Text(entry.timeLabel, style: DashboardStyles.secondary),
                ]);
            final state = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.statusLabel,
                      style: DashboardStyles.secondary.copyWith(
                          color: entry.pending
                              ? NavigationTokens.warning
                              : NavigationTokens.brand,
                          fontWeight: FontWeight.w500)),
                  Text(entry.sourceLabel, style: DashboardStyles.secondary),
                  if (entry.pending && entry.pastDated(now))
                    const ClinicalStatusChip(
                        label: 'Date passed',
                        tone: ClinicalStatusTone.warning,
                        icon: Icons.schedule_outlined),
                  if (entry.imported && entry.integrationStatus == 'failed')
                    Text('Sync needs attention',
                        style: DashboardStyles.secondary
                            .copyWith(color: NavigationTokens.warning)),
                ]);
            final actions = Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (entry.pending)
                    FilledButton(
                        onPressed: busy ? null : () => onAction('confirmed'),
                        style: FilledButton.styleFrom(
                            backgroundColor: NavigationTokens.brand),
                        child: const Text('Confirm')),
                  TextButton(
                      onPressed: busy ? null : onOpen,
                      child: Text(entry.pending || entry.closed
                          ? 'View details'
                          : 'Open appointment')),
                  if (entry.canReschedule || entry.pending || entry.canCancel)
                    PopupMenuButton<String>(
                        tooltip: 'Appointment actions',
                        enabled: !busy,
                        onSelected: onAction,
                        icon: const Icon(PhosphorIconsRegular.dotsThree,
                            size: 22),
                        itemBuilder: (_) => [
                              if (entry.pending)
                                const PopupMenuItem(
                                    value: 'declined', child: Text('Decline')),
                              if (entry.canReschedule)
                                const PopupMenuItem(
                                    value: 'reschedule',
                                    child: Text('Reschedule')),
                              if (entry.canCancel)
                                PopupMenuItem(
                                    value:
                                        entry.legacy ? 'canceled' : 'cancelled',
                                    child: const Text('Cancel appointment')),
                            ]),
                  if (busy)
                    Semantics(
                        liveRegion: true,
                        child: const Text('Action in progress',
                            style: DashboardStyles.secondary)),
                ]);
            if (narrow)
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [schedule, state]),
                    const SizedBox(height: 10),
                    actions
                  ]);
            return Row(children: [
              Expanded(flex: 4, child: identity),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: schedule),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: state),
              const SizedBox(width: 12),
              Flexible(flex: 4, child: actions)
            ]);
          })));
}
