import 'package:flutter/material.dart';

import '/application/shared/clinical_tools/clinical_tool_dashboard.dart';
import '../controllers/ct_scan_controller.dart';

class CtScanModuleShell extends StatelessWidget {
  const CtScanModuleShell({
    super.key,
    required this.controller,
  });

  final CtScanController controller;

  @override
  Widget build(BuildContext context) {
    return ClinicalToolDashboard(controller: controller);
  }
}
