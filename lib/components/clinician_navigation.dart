import 'package:flutter/material.dart';

/// Route-derived selection also works after a browser refresh.
String clinicianDestination(String path) {
  path = path.toLowerCase();
  if (path.contains('scheduledencounters')) return 'Appointments';
  if (path.contains('cervical-cancer')) return 'Cervical Cancer';
  if (path.contains('ultrasound')) return 'Ultrasound';
  if (path.contains('hemonix')) return 'Anemia';
  if (path.contains('ct-scan')) return 'CT Scan';
  if (path.contains('bp-monitor')) return 'BP Monitor';
  if (path.contains('care-tools')) return 'Screenings';
  if (path.contains('profile')) return 'Settings';
  if (path.contains('mom') ||
      path.contains('patient') ||
      path.contains('encounter')) {
    return 'Patients';
  }
  return 'Home';
}

// Shared across route changes; the drawer always remains expanded.
final clinicianSidebarCollapsed = ValueNotifier<bool>(false);

final clinicianScreeningsExpanded = ValueNotifier<bool>(true);

String clinicianPageTitle(String path) {
  final destination = clinicianDestination(path);
  return destination == 'Anemia' ? 'Anemia Screening' : destination;
}
