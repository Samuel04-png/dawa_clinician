import '/application/shared/clinical_tools/clinical_tool_controller.dart';
import '../repository/hemonix_repository.dart';
import '../services/hemonix_service.dart';

class HemonixController extends ClinicalToolController {
  HemonixController({
    HemonixRepository repository = const HemonixRepository(),
    HemonixService service = const HemonixService(),
  }) : super(
          config: service.config,
          records: repository
              .getRecentRecords()
              .map((record) => record.toClinicalToolRecord())
              .toList(),
        );
}
