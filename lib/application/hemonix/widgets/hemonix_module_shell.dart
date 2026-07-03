import 'package:flutter/material.dart';

import '/application/shared/clinical_tools/clinical_tool_dashboard.dart';
import '../controllers/hemonix_controller.dart';

class HemonixModuleShell extends StatelessWidget {
  const HemonixModuleShell({
    super.key,
    required this.controller,
  });

  final HemonixController controller;

  @override
  Widget build(BuildContext context) {
    return ClinicalToolDashboard(controller: controller);
  }
}
