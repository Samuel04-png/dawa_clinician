import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase_config.dart';

class ScreeningPatient {
  const ScreeningPatient(
      {required this.id, required this.name, this.age, this.contact = ''});
  final String id;
  final String name;
  final int? age;
  final String contact;

  static List<ScreeningPatient> parseRows(Iterable<Map<String, dynamic>> rows) {
    final result = <ScreeningPatient>[];
    final seen = <String>{};
    var skipped = 0;
    for (final row in rows) {
      final id = row['id'];
      final name = row['name'];
      if (id is! String ||
          id.trim().isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          !seen.add(id)) {
        skipped++;
        continue;
      }
      final dob = DateTime.tryParse(
          row['dateOfBirth'] is String ? row['dateOfBirth'] as String : '');
      final now = DateTime.now();
      var age = dob == null
          ? null
          : now.year -
              dob.year -
              ((now.month < dob.month ||
                      now.month == dob.month && now.day < dob.day)
                  ? 1
                  : 0);
      if (age != null && (age < 0 || age > 120)) age = null;
      result.add(ScreeningPatient(
          id: id,
          name: name.trim(),
          age: age,
          contact: row['phone_number'] is String
              ? row['phone_number'] as String
              : ''));
    }
    if (skipped > 0)
      debugPrint('[Screening] Skipped $skipped invalid patient records.');
    return result;
  }
}

abstract interface class ScreeningPatientRepository {
  Future<List<ScreeningPatient>> loadPatients();
}

class SupabaseScreeningPatientRepository implements ScreeningPatientRepository {
  const SupabaseScreeningPatientRepository();
  @override
  Future<List<ScreeningPatient>> loadPatients() async {
    if (supabaseClient.auth.currentUser == null)
      throw StateError('Sign in to access patient records.');
    // Uses the authenticated session and the existing patient access policies.
    final rows = await runSupabaseRequest(() => supabaseClient
        .from('mother')
        .select('id,name,dateOfBirth,phone_number')
        .order('name'));
    return ScreeningPatient.parseRows(rows);
  }
}
