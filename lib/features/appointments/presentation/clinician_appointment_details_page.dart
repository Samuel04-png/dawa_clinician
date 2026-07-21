import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/components/dawa_design_system.dart';
import '../domain/clinician_appointment.dart';

class ClinicianAppointmentDetailsPage extends StatefulWidget {
  const ClinicianAppointmentDetailsPage({
    super.key,
    required this.appointment,
    required this.onStatus,
    required this.onReschedule,
    required this.onAssess,
  });

  final ClinicianAppointment appointment;
  final Future<bool> Function(String status) onStatus;
  final Future<bool> Function() onReschedule;
  final Future<void> Function() onAssess;

  @override
  State<ClinicianAppointmentDetailsPage> createState() =>
      _ClinicianAppointmentDetailsPageState();
}

class _ClinicianAppointmentDetailsPageState
    extends State<ClinicianAppointmentDetailsPage> {
  bool _working = false;

  ClinicianAppointment get appointment => widget.appointment;

  Future<void> _changeStatus(String status) async {
    if (_working) return;
    setState(() => _working = true);
    final updated = await widget.onStatus(status);
    if (!mounted) return;
    if (updated) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _working = false);
  }

  Future<void> _reschedule() async {
    if (_working) return;
    setState(() => _working = true);
    final updated = await widget.onReschedule();
    if (!mounted) return;
    if (updated) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _working = false);
  }

  Future<void> _openAssessment() async {
    if (_working) return;
    setState(() => _working = true);
    await widget.onAssess();
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        backgroundColor: DawaTokens.surface,
        foregroundColor: DawaTokens.textPrimary,
        title: Text(
          'Appointment details',
          style: DawaTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          20,
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          40,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AppointmentHero(appointment: appointment),
                const SizedBox(height: 22),
                const _SectionHeading(
                  eyebrow: 'OVERVIEW',
                  title: 'Consultation overview',
                  subtitle:
                      'Review the patient, pregnancy context, and reason before taking action.',
                ),
                const SizedBox(height: 12),
                _OverviewGrid(appointment: appointment),
                const SizedBox(height: 18),
                _WorkflowCard(appointment: appointment),
                if (_hasActions) ...[
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    eyebrow: 'NEXT ACTION',
                    title: 'Manage appointment',
                    subtitle:
                        'Assessment is required before a confirmed appointment can be completed.',
                  ),
                  const SizedBox(height: 12),
                  _ActionPanel(
                    appointment: appointment,
                    working: _working,
                    onStatus: _changeStatus,
                    onReschedule: _reschedule,
                    onAssess: _openAssessment,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      appointment.isPending ||
      appointment.canReschedule ||
      appointment.canComplete ||
      appointment.canCancel;
}

class _AppointmentHero extends StatelessWidget {
  const _AppointmentHero({required this.appointment});

  final ClinicianAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final status = _statusSpec(appointment.status);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DawaTokens.brandPrimary, Color(0xFF173EA5)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x291D4ED8),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final avatar = DawaAvatarCircle(
            name: appointment.patientName,
            moduleColor: Colors.white,
            size: compact ? 52 : 60,
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroStatusBadge(spec: status),
              const SizedBox(height: 10),
              Text(
                appointment.patientName,
                style: DawaTextStyles.pageTitle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${DateFormat('EEEE, d MMMM y').format(appointment.scheduledStart)} · '
                '${DateFormat('HH:mm').format(appointment.scheduledStart)}–'
                '${DateFormat('HH:mm').format(appointment.scheduledEnd)}',
                style: DawaTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appointment.clinicName.isEmpty
                    ? 'Clinic not recorded'
                    : appointment.clinicName,
                style: DawaTextStyles.secondary.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroMeta(
                    icon: Icons.health_and_safety_outlined,
                    text: _appointmentTypeLabel(appointment.appointmentType),
                  ),
                  _HeroMeta(
                    icon: appointment.hasAssessmentDraft
                        ? Icons.edit_note_rounded
                        : Icons.assignment_outlined,
                    text: _assessmentLabel(appointment.assessmentStatus),
                  ),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 16), content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 18),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStatusBadge extends StatelessWidget {
  const _HeroStatusBadge({required this.spec});

  final _StatusSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            spec.label,
            style: DawaTextStyles.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DawaTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: DawaTextStyles.label.copyWith(
            color: DawaTokens.brandPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: DawaTextStyles.pageTitle.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: DawaTextStyles.secondary),
      ],
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.appointment});

  final ClinicianAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final patientCard = _InformationCard(
      icon: Icons.person_outline_rounded,
      title: 'Patient context',
      children: [
        _InformationRow(
          icon: Icons.person_outline_rounded,
          label: 'Patient',
          value: appointment.patientName,
        ),
        _InformationRow(
          icon: Icons.pregnant_woman_rounded,
          label: 'Pregnancy status',
          value: _pregnancyLabel(appointment.pregnancyStatus),
        ),
        if (appointment.pregnancyLnmp != null)
          _InformationRow(
            icon: Icons.history_rounded,
            label: 'LNMP',
            value: DateFormat('d MMMM y').format(appointment.pregnancyLnmp!),
          ),
        if (appointment.pregnancyEstimatedDueDate != null)
          _InformationRow(
            icon: Icons.event_available_outlined,
            label: 'Estimated due date',
            value: DateFormat('d MMMM y')
                .format(appointment.pregnancyEstimatedDueDate!),
          ),
        _InformationRow(
          icon: Icons.verified_user_outlined,
          label: 'Pregnancy information source',
          value: _pregnancySourceLabel(appointment.pregnancyProvenance),
        ),
      ],
    );
    final visitCard = _InformationCard(
      icon: Icons.event_note_outlined,
      title: 'Visit information',
      children: [
        _InformationRow(
          icon: Icons.health_and_safety_outlined,
          label: 'Appointment type',
          value: _appointmentTypeLabel(appointment.appointmentType),
        ),
        _InformationRow(
          icon: Icons.notes_rounded,
          label: 'Reason for visit',
          value: appointment.reason.isEmpty
              ? 'No reason recorded'
              : appointment.reason,
        ),
        if (appointment.notes.isNotEmpty)
          _InformationRow(
            icon: Icons.description_outlined,
            label: 'Booking note',
            value: appointment.notes,
          ),
        _InformationRow(
          icon: Icons.cloud_done_outlined,
          label: 'Source',
          value: 'Dawa Mom',
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [patientCard, const SizedBox(height: 14), visitCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: patientCard),
            const SizedBox(width: 14),
            Expanded(child: visitCard),
          ],
        );
      },
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DawaTokens.brandPrimaryPale,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                ),
                child: Icon(icon, color: DawaTokens.brandPrimary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(child: Text(title, style: DawaTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DawaTokens.brandPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DawaTextStyles.secondary),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: DawaTextStyles.body.copyWith(
                    color: DawaTokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.appointment});

  final ClinicianAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final sync = _syncSpec(appointment.integrationStatus);
    final assessmentStarted = appointment.hasAssessmentDraft;
    return DawaCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _WorkflowItem(
              icon: assessmentStarted
                  ? Icons.edit_note_rounded
                  : Icons.assignment_outlined,
              title: 'Assessment',
              value: _assessmentLabel(appointment.assessmentStatus),
              foreground: assessmentStarted
                  ? DawaTokens.brandPrimary
                  : DawaTokens.textSecondary,
              background: assessmentStarted
                  ? DawaTokens.brandPrimaryPale
                  : DawaTokens.surfaceTertiary,
            ),
            _WorkflowItem(
              icon: sync.icon,
              title: 'Dawa Mom sync',
              value: sync.label,
              foreground: sync.foreground,
              background: sync.background,
            ),
          ];
          if (constraints.maxWidth < 620) {
            return Column(
              children: [
                items.first,
                const Divider(height: 24),
                items.last,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: items.first),
              const SizedBox(width: 18),
              Expanded(child: items.last),
            ],
          );
        },
      ),
    );
  }
}

class _WorkflowItem extends StatelessWidget {
  const _WorkflowItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          ),
          child: Icon(icon, color: foreground, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DawaTextStyles.secondary),
              const SizedBox(height: 2),
              Text(
                value,
                style: DawaTextStyles.body.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.appointment,
    required this.working,
    required this.onStatus,
    required this.onReschedule,
    required this.onAssess,
  });

  final ClinicianAppointment appointment;
  final bool working;
  final ValueChanged<String> onStatus;
  final VoidCallback onReschedule;
  final VoidCallback onAssess;

  @override
  Widget build(BuildContext context) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (appointment.canComplete)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DawaTokens.brandPrimaryPale,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    color: DawaTokens.brandPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      appointment.hasAssessmentDraft
                          ? 'Continue the saved assessment. Completion will remain unavailable until required information is resolved.'
                          : 'Start the clinical assessment before completing this appointment.',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (appointment.canComplete) const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              if (appointment.isPending)
                FilledButton.icon(
                  onPressed: working ? null : () => onStatus('confirmed'),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirm appointment'),
                ),
              if (appointment.isPending)
                OutlinedButton.icon(
                  onPressed: working ? null : () => onStatus('declined'),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Decline'),
                ),
              if (appointment.canComplete)
                FilledButton.icon(
                  onPressed: working ? null : onAssess,
                  icon: Icon(
                    appointment.hasAssessmentDraft
                        ? Icons.edit_note_rounded
                        : Icons.playlist_add_rounded,
                    size: 18,
                  ),
                  label: Text(
                    appointment.hasAssessmentDraft
                        ? 'Continue assessment'
                        : 'Start consultation',
                  ),
                ),
              if (appointment.canReschedule)
                OutlinedButton.icon(
                  onPressed: working ? null : onReschedule,
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: const Text('Reschedule'),
                ),
              if (appointment.canCancel)
                TextButton.icon(
                  onPressed: working ? null : () => onStatus('cancelled'),
                  icon: const Icon(Icons.event_busy_outlined, size: 18),
                  label: const Text('Cancel appointment'),
                  style: TextButton.styleFrom(
                    foregroundColor: DawaTokens.statusDanger,
                  ),
                ),
              if (working)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusSpec {
  const _StatusSpec({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}

_StatusSpec _statusSpec(String status) => switch (status) {
      'confirmed' => const _StatusSpec(
          label: 'Confirmed',
          icon: Icons.event_available_outlined,
          foreground: DawaTokens.statusSuccessText,
          background: DawaTokens.statusSuccessBg,
        ),
      'completed' => const _StatusSpec(
          label: 'Completed',
          icon: Icons.task_alt_rounded,
          foreground: DawaTokens.statusSuccessText,
          background: DawaTokens.statusSuccessBg,
        ),
      'rescheduled' => const _StatusSpec(
          label: 'Rescheduled',
          icon: Icons.event_repeat_rounded,
          foreground: DawaTokens.statusInfo,
          background: DawaTokens.statusInfoBg,
        ),
      'declined' => const _StatusSpec(
          label: 'Declined',
          icon: Icons.block_outlined,
          foreground: DawaTokens.statusDangerText,
          background: DawaTokens.statusDangerBg,
        ),
      'cancelled' => const _StatusSpec(
          label: 'Cancelled',
          icon: Icons.event_busy_outlined,
          foreground: DawaTokens.statusDangerText,
          background: DawaTokens.statusDangerBg,
        ),
      _ => const _StatusSpec(
          label: 'Pending confirmation',
          icon: Icons.schedule_rounded,
          foreground: DawaTokens.statusWarningText,
          background: DawaTokens.statusWarningBg,
        ),
    };

_StatusSpec _syncSpec(String status) => switch (status) {
      'failed' => const _StatusSpec(
          label: 'Needs retry',
          icon: Icons.sync_problem_rounded,
          foreground: DawaTokens.statusDangerText,
          background: DawaTokens.statusDangerBg,
        ),
      'pending' || 'retrying' => const _StatusSpec(
          label: 'Sending update',
          icon: Icons.sync_rounded,
          foreground: DawaTokens.statusWarningText,
          background: DawaTokens.statusWarningBg,
        ),
      _ => const _StatusSpec(
          label: 'Up to date',
          icon: Icons.cloud_done_outlined,
          foreground: DawaTokens.statusSuccessText,
          background: DawaTokens.statusSuccessBg,
        ),
    };

String _pregnancyLabel(String status) => switch (status) {
      'pregnant' => 'Pregnant',
      'not_pregnant' => 'Not currently pregnant',
      'prefer_not_to_say' => 'Patient preferred not to say',
      _ => 'Pregnancy status not provided',
    };

String _assessmentLabel(String status) => switch (status) {
      'in_progress' => 'Assessment draft saved',
      'ready_for_review' => 'Ready for review',
      'completed' => 'Assessment completed',
      _ => 'Assessment not started',
    };

String _humanize(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _appointmentTypeLabel(String value) {
  final label = _humanize(value);
  return label.isEmpty ? 'General appointment' : label;
}

String _pregnancySourceLabel(String provenance) => switch (provenance) {
      'patient' => 'Patient-provided',
      'clinician' => 'Clinician-confirmed',
      _ => 'Source not recorded',
    };
