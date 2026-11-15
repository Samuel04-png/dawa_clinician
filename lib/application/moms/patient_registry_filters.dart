import '/application/home/data/home_dashboard_repository.dart';

enum PatientRegistryFilter {
  all('All'),
  needsCompletion('Needs completion'),
  firstEncounter('With first encounter'),
  newImported('New from Dawa Mom'),
  recentlyAdded('Recently added');

  const PatientRegistryFilter(this.label);
  final String label;
  String get description => switch (this) {
        all => 'All patient records visible to your account.',
        needsCompletion =>
          'Missing required name, date of birth or phone number.',
        firstEncounter => 'Records with a linked first encounter.',
        newImported => 'Dawa Mom records awaiting a linked first encounter.',
        recentlyAdded =>
          'Registered today or during the previous six local calendar days.',
      };
}

bool registryMatchesSearch(DashboardPatient patient, String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return true;
  final values = [
    patient.name,
    patient.identifier,
    patient.id,
    patient.phone,
    ...patient.searchValues
  ];
  if (values.any((value) => value.toLowerCase().contains(text))) return true;
  // Normalize formatting only for phone-shaped input. Other identifier searches
  // retain their letters and separators to avoid unrelated phone matches.
  if (!RegExp(r'^[+\d\s().-]+$').hasMatch(text)) return false;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.isNotEmpty &&
      patient.phone.replaceAll(RegExp(r'\D'), '').contains(digits);
}

bool registryMatchesFilter(
    DashboardPatient patient, PatientRegistryFilter filter, DateTime now) {
  switch (filter) {
    case PatientRegistryFilter.all:
      return true;
    case PatientRegistryFilter.needsCompletion:
      return patient.missingFields.isNotEmpty;
    case PatientRegistryFilter.firstEncounter:
      return patient.firstEncounterId != null;
    case PatientRegistryFilter.newImported:
      return patient.imported && patient.firstEncounterId == null;
    case PatientRegistryFilter.recentlyAdded:
      final created = patient.createdAt?.toLocal();
      final today = now.toLocal();
      final start = DateTime(today.year, today.month, today.day - 6);
      return created != null &&
          !created.isBefore(start) &&
          !created.isAfter(today);
  }
}

int? registryPatientAge(DashboardPatient patient, DateTime now) {
  final birth = patient.dateOfBirth;
  if (birth == null) return null;
  final today = now.toLocal();
  final age = today.year -
      birth.year -
      ((today.month < birth.month ||
              today.month == birth.month && today.day < birth.day)
          ? 1
          : 0);
  return age >= 0 && age <= 120 ? age : null;
}
