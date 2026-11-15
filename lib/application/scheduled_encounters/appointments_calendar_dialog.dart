import 'package:flutter/material.dart';
import '/application/home/data/home_dashboard_repository.dart';
import '/application/home/widgets/home_dashboard_content.dart';
import '/components/navigation_design_system.dart';
import '/flutter_flow/flutter_flow_calendar.dart';

/// The existing monthly calendar remains an explicit Appointments action.
class AppointmentsCalendarDialog extends StatefulWidget {
  const AppointmentsCalendarDialog(
      {super.key, required this.doctorId, this.loadDays});
  final String doctorId;
  final Future<List<DateTime>> Function()? loadDays;
  @override
  State<AppointmentsCalendarDialog> createState() =>
      _AppointmentsCalendarDialogState();
}

class _AppointmentsCalendarDialogState
    extends State<AppointmentsCalendarDialog> {
  AsyncSnapshot<List<DateTime>> days = const AsyncSnapshot.waiting();
  int request = 0;
  @override
  void initState() {
    super.initState();
    _refreshDays();
  }

  Future<void> _refreshDays() async {
    final current = ++request;
    setState(() => days = const AsyncSnapshot.waiting());
    try {
      final records = await (widget.loadDays?.call() ??
          const SupabaseHomeDashboardRepository()
              .loadCalendarDays(widget.doctorId));
      if (mounted && current == request)
        setState(
            () => days = AsyncSnapshot.withData(ConnectionState.done, records));
    } catch (error) {
      if (mounted && current == request)
        setState(
            () => days = AsyncSnapshot.withError(ConnectionState.done, error));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Appointment calendar'),
        content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
                primary: false,
                child: days.hasError
                    ? DashboardMessage(
                        title: 'Calendar unavailable',
                        message: dashboardError(days.error, 'appointments'),
                        onRetry: _refreshDays)
                    : !days.hasData
                        ? const DashboardSkeleton(rows: 4)
                        : FlutterFlowCalendar(
                            color: NavigationTokens.brand,
                            weekFormat: false,
                            initialDate: DateTime.now(),
                            markedDates: days.data!,
                            rowHeight: 34))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
}
