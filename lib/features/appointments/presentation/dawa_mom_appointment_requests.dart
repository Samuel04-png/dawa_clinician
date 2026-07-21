import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/components/dawa_design_system.dart';
import '../data/clinician_appointment_repository.dart';
import '../domain/clinician_appointment.dart';
import 'appointment_assessment_page.dart';
import 'clinician_appointment_details_page.dart';

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
              onAssess: () => _openAssessment(appointment),
              onViewDetails: () => _openDetails(appointment),
            );
          },
        );
      },
    );
  }

  Future<void> _openAssessment(ClinicianAppointment appointment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentAssessmentPage(appointment: appointment),
        settings: RouteSettings(
          name: 'appointment-assessment/${appointment.id}',
        ),
      ),
    );
  }

  Future<void> _openDetails(ClinicianAppointment appointment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClinicianAppointmentDetailsPage(
          appointment: appointment,
          onStatus: (status) => _setStatus(appointment, status),
          onReschedule: () => _reschedule(appointment),
          onAssess: () => _openAssessment(appointment),
        ),
        settings: RouteSettings(
          name: 'appointment-details/${appointment.id}',
        ),
      ),
    );
  }

  Future<bool> _setStatus(
    ClinicianAppointment appointment,
    String status,
  ) async {
    final confirmed = await _confirmStatusChange(appointment, status);
    if (!confirmed || !mounted) return false;

    setState(() => _busyAppointmentIds.add(appointment.id));
    try {
      await _repository.updateStatus(
        appointmentId: appointment.id,
        status: status,
        patientSafeMessage: _patientMessageFor(status),
      );
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked ${_statusLabel(status)}.'),
          backgroundColor: DawaTokens.statusSuccess,
        ),
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The appointment could not be updated. Check the slot and try again.',
            ),
            backgroundColor: DawaTokens.statusDanger,
          ),
        );
      }
      return false;
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
    if (status == 'confirmed') return true;
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

  Future<bool> _reschedule(ClinicianAppointment appointment) async {
    final now = DateTime.now();
    var selectedDate = appointment.scheduledStart.isAfter(now)
        ? appointment.scheduledStart
        : now.add(const Duration(days: 1));
    var selectedTime = TimeOfDay.fromDateTime(selectedDate);
    final originalDuration =
        appointment.scheduledEnd.difference(appointment.scheduledStart);
    final duration = originalDuration.inMinutes > 0
        ? originalDuration
        : const Duration(minutes: 30);
    var saving = false;

    final updated = await showDialog<bool>(
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
                                  firstDate:
                                      DateTime(now.year, now.month, now.day),
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
                            Navigator.pop(dialogContext, true);
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
    return updated ?? false;
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
    required this.onAssess,
    required this.onViewDetails,
  });

  final ClinicianAppointment appointment;
  final bool busy;
  final bool highlighted;
  final ValueChanged<String> onStatus;
  final VoidCallback onAssess;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);
    final pregnancyLabel = switch (appointment.pregnancyStatus) {
      'pregnant' => 'Pregnant',
      'not_pregnant' => 'Not currently pregnant',
      'prefer_not_to_say' => 'Preferred not to say',
      _ => 'Pregnancy status not provided',
    };
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final patient = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DawaAvatarCircle(
                    name: appointment.patientName,
                    moduleColor: DawaTokens.brandPrimary,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DawaTextStyles.cardTitle.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appointment.reason.isEmpty
                              ? _humanizeAppointmentType(
                                  appointment.appointmentType,
                                )
                              : appointment.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DawaTextStyles.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final status = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(appointment.status),
                  style: DawaTextStyles.label.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [patient, const SizedBox(height: 10), status],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: patient), status],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AppointmentMetaChip(
                icon: Icons.calendar_month_outlined,
                label: DateFormat('EEE, d MMM y')
                    .format(appointment.scheduledStart),
              ),
              _AppointmentMetaChip(
                icon: Icons.schedule_rounded,
                label:
                    '${DateFormat('HH:mm').format(appointment.scheduledStart)}–'
                    '${DateFormat('HH:mm').format(appointment.scheduledEnd)}',
              ),
              if (appointment.clinicName.isNotEmpty)
                _AppointmentMetaChip(
                  icon: Icons.local_hospital_outlined,
                  label: appointment.clinicName,
                ),
              _AppointmentMetaChip(
                icon: Icons.pregnant_woman_rounded,
                label: pregnancyLabel,
              ),
            ],
          ),
          if (appointment.hasAssessmentDraft) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DawaTokens.brandPrimaryPale,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: DawaTokens.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Assessment draft saved',
                    style: DawaTextStyles.label.copyWith(
                      color: DawaTokens.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
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
          if (appointment.isPending || appointment.canComplete) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onViewDetails,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View details'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: appointment.isPending
                      ? FilledButton.icon(
                          onPressed: busy ? null : () => onStatus('confirmed'),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Confirm'),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: busy ? null : onAssess,
                          icon: Icon(
                            appointment.hasAssessmentDraft
                                ? Icons.edit_note_rounded
                                : Icons.playlist_add_rounded,
                            size: 18,
                          ),
                          label: Text(
                            appointment.hasAssessmentDraft
                                ? 'Continue'
                                : 'Start consultation',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                if (busy) ...[
                  const SizedBox(width: 10),
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onViewDetails,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View appointment details'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentMetaChip extends StatelessWidget {
  const _AppointmentMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: DawaTokens.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: DawaTextStyles.label.copyWith(
              color: DawaTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
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

String _humanizeAppointmentType(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
