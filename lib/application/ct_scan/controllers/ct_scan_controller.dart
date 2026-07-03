import '/application/shared/clinical_tools/clinical_tool_controller.dart';
import '../repository/ct_scan_repository.dart';
import '../services/ct_scan_service.dart';

class CtScanController extends ClinicalToolController {
  CtScanController({
    CtScanRepository repository = const CtScanRepository(),
    CtScanService service = const CtScanService(),
  }) : super(
          config: service.config,
          records: repository
              .getRecentRecords()
              .map((record) => record.toClinicalToolRecord())
              .toList(),
        );
}
