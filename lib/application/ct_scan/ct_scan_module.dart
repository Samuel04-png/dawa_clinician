import 'package:flutter/widgets.dart';

import '/application/shared/clinical_tools/clinical_tool_models.dart';
import 'repository/ct_scan_repository.dart';
import 'screens/ct_scan_app.dart';
import 'services/ct_scan_service.dart';

export 'controllers/ct_scan_controller.dart';
export 'models/ct_scan_record.dart';
export 'repository/ct_scan_repository.dart';
export 'screens/ct_scan_app.dart';
export 'services/ct_scan_service.dart';
export 'widgets/ct_scan_module_shell.dart';

class CtScanModule {
  const CtScanModule._();

  static List<ClinicalToolRecord> records() {
    return const CtScanRepository()
        .getRecentRecords()
        .map((record) => record.toClinicalToolRecord())
        .toList();
  }

  static ClinicalToolSummary summary() {
    return buildClinicalToolSummary(
      config: const CtScanService().config,
      records: records(),
      builder: (BuildContext context) => const CtScanApp(),
      description: 'CT imaging records & results',
    );
  }
}
