import 'package:flutter/widgets.dart';

import '/application/shared/clinical_tools/clinical_tool_models.dart';
import 'repository/hemonix_repository.dart';
import 'screens/hemonix_app.dart';
import 'services/hemonix_service.dart';

export 'controllers/hemonix_controller.dart';
export 'models/hemonix_record.dart';
export 'repository/hemonix_repository.dart';
export 'screens/hemonix_app.dart';
export 'services/hemonix_service.dart';
export 'widgets/hemonix_module_shell.dart';

class HemonixModule {
  const HemonixModule._();

  static List<ClinicalToolRecord> records() {
    return const HemonixRepository()
        .getRecentRecords()
        .map((record) => record.toClinicalToolRecord())
        .toList();
  }

  static ClinicalToolSummary summary() {
    return buildClinicalToolSummary(
      config: const HemonixService().config,
      records: records(),
      builder: (BuildContext context) => const HemonixApp(),
      description: 'Haemoglobin & anaemia tracking',
    );
  }
}
