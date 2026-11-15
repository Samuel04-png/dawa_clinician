import '/backend/supabase/supabase_config.dart';
import '/features/appointments/domain/appointment_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '/backend/backend.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showScheduleAppointmentDialog(BuildContext context,
    {List<MotherRecord>? availablePatients, DateTime? clinicNow}) async {
  final clock = clinicNow ?? getCurrentTimestamp;
  final patients = availablePatients ??
      await queryMotherRecordOnce(
        queryBuilder: (motherRecord) => motherRecord.orderBy('mother_id'),
      );
  if (!context.mounted) return;

  if (patients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add a patient before scheduling an appointment.'),
        backgroundColor: DawaTokens.statusWarning,
      ),
    );
    return;
  }

  MotherRecord selectedPatient = patients.first;
  DateTime selectedDate = clock.add(const Duration(days: 1));
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(clock);
  var saving = false;
  String? saveError;
  final appointmentId = EncounterRecord.collection.doc().id;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final scheduledAt = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
            ),
            title: Text(
              'Schedule Appointment',
              style: DawaTextStyles.cardTitle.copyWith(fontSize: 18),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (saveError != null) ...[
                    Text(saveError!,
                        style: const TextStyle(color: DawaTokens.statusDanger)),
                    const SizedBox(height: 12),
                  ],
                  Text('Patient', style: DawaTextStyles.label),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MotherRecord>(
                    value: selectedPatient,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: DawaTokens.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DawaTokens.radiusMd),
                        borderSide: const BorderSide(color: DawaTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DawaTokens.radiusMd),
                        borderSide: const BorderSide(color: DawaTokens.border),
                      ),
                    ),
                    items: [
                      for (final patient in patients)
                        DropdownMenuItem(
                          value: patient,
                          child: Text(
                            patient.name.isEmpty
                                ? patient.reference.id
                                : patient.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => selectedPatient = value);
                          },
                  ),
                  const SizedBox(height: 16),
                  Text(
                      clinicNow == null
                          ? 'Date and time'
                          : 'Date and time · Africa/Lusaka',
                      style: DawaTextStyles.label),
                  const SizedBox(height: 8),
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
                                  firstDate: DateTime(
                                      clock.year, clock.month, clock.day),
                                  lastDate:
                                      clock.add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(dateTimeFormat('d MMM y', selectedDate)),
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
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DawaTokens.brandPrimaryPale,
                      borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                    ),
                    child: Text(
                      'This will create a pending appointment for ${dateTimeFormat('EEEE, d MMMM y', scheduledAt)} at ${selectedTime.format(dialogContext)}.',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        try {
                          await _createScheduledAppointment(
                            patient: selectedPatient,
                            scheduledAt: scheduledAt,
                            appointmentId: appointmentId,
                            clinicTime: clinicNow != null,
                          );
                        } catch (_) {
                          if (dialogContext.mounted)
                            setDialogState(() {
                              saving = false;
                              saveError =
                                  'Could not confirm this appointment. Check your connection and retry, or check Appointments before booking again.';
                            });
                          return;
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Appointment scheduled for ${selectedPatient.name}.',
                            ),
                            backgroundColor: DawaTokens.statusSuccess,
                          ),
                        );
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(saving ? 'Scheduling...' : 'Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DawaTokens.brandPrimary,
                  foregroundColor: DawaTokens.textInverse,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _createScheduledAppointment({
  required MotherRecord patient,
  required DateTime scheduledAt,
  required String appointmentId,
  bool clinicTime = false,
}) async {
  final scheduledUtc =
      clinicTime ? appointmentUtc(scheduledAt) : scheduledAt.toUtc();
  final doctor = FFAppState().doctor;
  if (doctor == null || supabaseClient.auth.currentUser == null) {
    throw StateError('A signed-in clinician is required.');
  }
  final payload = {
    'id': appointmentId,
    'date': scheduledUtc.toIso8601String(),
    'next_visit': scheduledUtc.toIso8601String(),
    'mother_id': patient.reference.path,
    'doctor_id': doctor.path,
    'status': 'scheduled',
    'is_instant': false,
    'time': dateTimeFormat('Hm', scheduledAt),
  };
  try {
    // A stable ID makes a retry after an interrupted response idempotent.
    await runSupabaseRequest(
        () => supabaseClient.from('encounter').insert(payload));
  } on PostgrestException catch (error) {
    if (error.code != '23505') rethrow;
    final existing = await runSupabaseRequest(() => supabaseClient
        .from('encounter')
        .select('mother_id,doctor_id,date,status')
        .eq('id', appointmentId)
        .single());
    final existingDate = DateTime.tryParse(existing['date']?.toString() ?? '');
    if (existing['mother_id'] != patient.reference.path ||
        existing['doctor_id'] != doctor.path ||
        existing['status'] != 'scheduled' ||
        existingDate == null ||
        !existingDate.isAtSameMomentAs(scheduledUtc)) rethrow;
  }
}
