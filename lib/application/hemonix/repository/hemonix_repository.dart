import '../models/hemonix_record.dart';

class HemonixRepository {
  const HemonixRepository();

  List<HemonixRecord> getRecentRecords() {
    return const []; // Real screening history is loaded by SupabaseAnemiaRepository.
  }
}
