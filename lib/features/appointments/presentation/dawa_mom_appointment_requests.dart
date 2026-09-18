import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/components/dawa_design_system.dart';
import '../data/clinician_appointment_repository.dart';
import '../domain/clinician_appointment.dart';

class DawaMomAppointmentRequests extends StatefulWidget {
  const DawaMomAppointmentRequests({
    super.key,
    this.focusedAppointmentId,
  });

  final String? focusedAppointmentId;

  @override
  State<DawaMomAppointmentRequests> createState() =>
      _DawaMomAppointmentRequestsState();
}

class _DawaMomAppointmentRequestsState
    extends State<DawaMomAppointmentRequests> {
  final _repository = const ClinicianAppointmentRepository();
  late final Stream<List<ClinicianAppointment>> _appointments;
  final Set<String> _busyAppointmentIds = {};

  @override
  void initState() {
    super.initState();
    _appointments = _repository.watchDawaMomAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicianAppointment>>(
      stream: _appointments,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.cloud_off_rounded,
            title: 'Appointment requests are unavailable',
            message: 'Check the connection and try this page again.',
            color: DawaTokens.statusWarning,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = [...snapshot.data!];
        if (appointments.isEmpty) {
          return const _MessageCard(
            icon: Icons.event_available_rounded,
            title: 'No Dawa Mom requests',
            message:
                'New appointments assigned to you will appear here automatically.',
            color: DawaTokens.brandPrimary,
          );
        }

        final focusedId = widget.focusedAppointmentId;
        if (focusedId != null && focusedId.isNotEmpty) {
          appointments.sort((left, right) {
            if (left.id == focusedId) return -1;
            if (right.id == focusedId) return 1;
            return left.scheduledStart.compareTo(right.scheduledStart);
          });
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            return _AppointmentCard(
              appointment: appointment,
              busy: _busyAppointmentIds.contains(appointment.id),
              highlighted: appointment.id == focusedId,
              onStatus: (status) => _setStatus(appointment, status),
              onReschedule: () => _reschedule(appointment),
            );
          },
        );
      },
    );
  }

  Future<void> _setStatus(
    ClinicianAppointment appointment,
    String status,
  ) async {
    final confirmed = await _confirmStatusChange(appointment, status);
    if (!confirmed || !mounted) return;

    setState(() => _busyAppointmentIds.add(appointment.id));
    try {
      await _repository.updateStatus(
        appointmentId: appointment.id,
        status: status,
        patientSafeMessage: _patientMessageFor(status),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked ${_statusLabel(status)}.'),
          backgroundColor: DawaTokens.statusSuccess,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The appointment could not be updated. Check the slot and try again.',
          ),
          backgroundColor: DawaTokens.statusDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyAppointmentIds.remove(appointment.id));
      }
    }
  }

  Future<bool> _confirmStatusChange(
    ClinicianAppointment appointment,
    String status,
  ) async {
    if (status == 'confirmed' || status == 'completed') return true;
    final label = _statusLabel(status);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              '${label[0].toUpperCase()}${label.substring(1)} appointment?',
            ),
            content: Text(
              'This will update ${appointment.patientName} and send a safe status message to Dawa Mom.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep appointment'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(label),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _reschedule(ClinicianAppointment appointment) async {
    final now = DateTime.now();
    var selectedDate = appointment.scheduledStart.isAfter(now)
        ? appointment.scheduledStart
        : now.add(const Duration(days: 1));
    var selectedTime = TimeOfDay.fromDateTime(selectedDate);
    final originalDuration = appointment.scheduledEnd
        .difference(appointment.scheduledStart);
    final duration = originalDuration.inMinutes > 0
        ? originalDuration
        : const Duration(minutes: 30);
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final newStart = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          final newEnd = newStart.add(duration);
          return AlertDialog(
            title: const Text('Reschedule appointment'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.patientName,
                    style: DawaTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(now.year, now.month, now.day),
                                  lastDate: now.add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(DateFormat('d MMM y').format(selectedDate)),
                      ),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedTime = picked);
                                }
                              },
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(selectedTime.format(dialogContext)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${DateFormat('EEEE, d MMMM y').format(newStart)} · '
                    '${DateFormat('HH:mm').format(newStart)}–${DateFormat('HH:mm').format(newEnd)}',
                    style: DawaTextStyles.secondary,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (!newStart.isAfter(DateTime.now())) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Choose a future date and time.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _repository.updateStatus(
                            appointmentId: appointment.id,
                            status: 'rescheduled',
                            appointmentDate: newStart,
                            startTime: DateFormat('HH:mm').format(newStart),
                            endTime: DateFormat('HH:mm').format(newEnd),
                            patientSafeMessage:
                                'The clinic proposed a new appointment time.',
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Appointment rescheduled.'),
                                backgroundColor: DawaTokens.statusSuccess,
                              ),
                            );
                          }
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'That slot is unavailable or could not be saved.',
                              ),
                              backgroundColor: DawaTokens.statusDanger,
                            ),
                          );
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_repeat_rounded),
                label: Text(saving ? 'Saving...' : 'Reschedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _patientMessageFor(String status) {
    return switch (status) {
      'confirmed' => 'Your appointment has been confirmed.',
      'declined' =>
        'This appointment could not be confirmed. Please choose another time.',
      'completed' => 'Your appointment is marked complete.',
      'cancelled' => 'This appointment was cancelled by the clinic.',
      _ => 'Your appointment status was updated.',
    };
  }
}

class DawaMomNotificationButton extends StatefulWidget {
  const DawaMomNotificationButton({
    super.key,
    this.onOpenAppointment,
  });

  final ValueChanged<String>? onOpenAppointment;

  @override
  State<DawaMomNotificationButton> createState() =>
      _DawaMomNotificationButtonState();
}

class _DawaMomNotificationButtonState extends State<DawaMomNotificationButton> {
  final _repository = const ClinicianAppointmentRepository();
  late final Stream<List<ClinicianNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _repository.watchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicianNotification>>(
      stream: _notifications,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <ClinicianNotification>[];
        final unread = notifications.where((item) => !item.isRead).length;
        return IconButton(
          tooltip: 'Appointment notifications',
          onPressed: () => _showNotifications(notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  Future<void> _showNotifications(
    List<ClinicianNotification> notifications,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text('Notifications', style: DawaTextStyles.pageTitle),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Text('No appointment notifications yet.'),
                      )
                    : ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: notification.isRead
                                  ? DawaTokens.surfaceTertiary
                                  : DawaTokens.brandPrimaryPale,
                              child: Icon(
                                Icons.event_note_rounded,
                                color: notification.isRead
                                    ? DawaTokens.textSecondary
                                    : DawaTokens.brandPrimary,
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: DawaTextStyles.cardTitle.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${notification.body}\n${DateFormat('d MMM y, HH:mm').format(notification.createdAt.toLocal())}',
                            ),
                            isThreeLine: true,
                            trailing: notification.isRead
                                ? null
                                : const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: DawaTokens.brandPrimary,
                                  ),
                            onTap: () async {
                              if (!notification.isRead) {
                                try {
                                    await _repository
                                        .markNotificationRead(notification.id);
                                } catch (_) {
                                  // Opening the linked appointment remains
                                  // useful if mark-read is temporarily offline.
                                }
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (notification.appointmentId.isNotEmpty) {
                                widget.onOpenAppointment
                                    ?.call(notification.appointmentId);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.busy,
    required this.highlighted,
    required this.onStatus,
    required this.onReschedule,
  });

  final ClinicianAppointment appointment;
  final bool busy;
  final bool highlighted;
  final ValueChanged<String> onStatus;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted) ...[
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: DawaTokens.brandPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Opened from notification',
                  style: DawaTextStyles.label.copyWith(
                    color: DawaTokens.brandPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: DawaTokens.brandPrimaryPale,
                foregroundColor: DawaTokens.brandPrimary,
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.patientName, style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('EEE, d MMM y').format(appointment.scheduledStart)} · '
                      '${DateFormat('HH:mm').format(appointment.scheduledStart)}–'
                      '${DateFormat('HH:mm').format(appointment.scheduledEnd)}',
                      style: DawaTextStyles.secondary,
                    ),
                    if (appointment.clinicName.isNotEmpty)
                      Text(appointment.clinicName, style: DawaTextStyles.secondary),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(appointment.status),
                  style: DawaTextStyles.label.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          if (appointment.reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Reason', style: DawaTextStyles.label),
            const SizedBox(height: 4),
            Text(appointment.reason, style: DawaTextStyles.body),
          ],
          if (appointment.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Booking note', style: DawaTextStyles.label),
            const SizedBox(height: 4),
            Text(appointment.notes, style: DawaTextStyles.body),
          ],
          if (appointment.integrationStatus == 'failed') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DawaTokens.statusDangerBg,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              ),
              child: Text(
                appointment.status == 'rescheduled'
                    ? 'This time did not reach Dawa Mom. Choose another available time to retry.'
                    : 'This update did not reach Dawa Mom. It needs a safe server retry.',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.statusDangerText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (appointment.integrationStatus == 'pending' ||
              appointment.integrationStatus == 'retrying') ...[
            const SizedBox(height: 10),
            Text(
              'Sending this update to Dawa Mom…',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusWarningText,
              ),
            ),
          ],
          if (appointment.isPending ||
              appointment.canReschedule ||
              appointment.canComplete) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (appointment.isPending)
                  FilledButton.icon(
                    onPressed: busy ? null : () => onStatus('confirmed'),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirm'),
                  ),
                if (appointment.isPending)
                  OutlinedButton(
                    onPressed: busy ? null : () => onStatus('declined'),
                    child: const Text('Decline'),
                  ),
                if (appointment.canReschedule)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReschedule,
                    icon: const Icon(Icons.event_repeat_rounded, size: 18),
                    label: const Text('Reschedule'),
                  ),
                if (appointment.canComplete)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => onStatus('completed'),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Complete'),
                  ),
                if (appointment.canCancel)
                  TextButton(
                    onPressed: busy ? null : () => onStatus('cancelled'),
                    child: const Text('Cancel appointment'),
                  ),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DawaCard(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 12),
              Text(title, style: DawaTextStyles.cardTitle),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DawaTextStyles.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Pending',
    'confirmed' => 'Confirmed',
    'declined' => 'Declined',
    'rescheduled' => 'Rescheduled',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status.isEmpty ? 'Unknown' : status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'confirmed' || 'completed' => DawaTokens.statusSuccess,
    'declined' || 'cancelled' => DawaTokens.statusDanger,
    'rescheduled' => DawaTokens.statusInfo,
    _ => DawaTokens.statusWarning,
  };
}
