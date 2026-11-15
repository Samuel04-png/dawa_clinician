import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/backend/supabase/supabase_config.dart';
import '/backend/supabase/supabase_offline_cache.dart';
import '/auth/base_auth_user_provider.dart';
import '/services/offline_connectivity_service.dart';

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
  const SupabaseScreeningPatientRepository({
    this.fetchRows,
    this.userId,
    this.isOffline,
  });

  final Future<List<Map<String, dynamic>>> Function()? fetchRows;
  final String? Function()? userId;
  final Future<bool> Function()? isOffline;

  static Future<void> cachePatients(
      String uid, List<Map<String, dynamic>> rows) async {
    if (uid.isEmpty) return;
    await SupabaseOfflineCache.saveQueryRows(
      SupabaseOfflineCache.queryKey(
          {'workflow': 'cervical-patients-v1', 'user_id': uid}),
      rows
          .map((row) => <String, dynamic>{
                'id': row['id'],
                'name': row['name'],
                'dateOfBirth': row['dateOfBirth'],
                'phone_number': row['phone_number'],
              })
          .toList(),
    );
  }

  String? _identity() => userId != null
      ? userId!()
      : (currentUser?.loggedIn == true
          ? currentUser!.uid
          : supabaseClient.auth.currentUser?.id);

  Future<bool> _offline() async => isOffline != null
      ? await isOffline!()
      : (await OfflineConnectivityService.refreshStatus()).isOffline;

  @override
  Future<List<ScreeningPatient>> loadPatients() async {
    final uid = _identity();
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to access patient records.');
    }
    // Keep authorized snapshots separate for every clinician and workflow.
    final key = SupabaseOfflineCache.queryKey({
      'workflow': 'cervical-patients-v1',
      'user_id': uid,
    });
    Future<List<ScreeningPatient>> cached() async {
      final rows = await SupabaseOfflineCache.readQueryRows(key);
      if (_identity() != uid) throw StateError('The signed-in user changed.');
      if (rows == null) {
        throw StateError(
            'No offline patient records available. Connect once and open cervical screening to download your patient list.');
      }
      return ScreeningPatient.parseRows(rows);
    }

    final knownOffline = isOffline != null
        ? await isOffline!()
        : OfflineConnectivityService.statusNotifier.value?.isOffline == true;
    if (knownOffline) return cached();

    late final List<Map<String, dynamic>> rows;
    try {
      rows = await (fetchRows?.call() ??
          runSupabaseRequest(() => supabaseClient
              .from('mother')
              .select('id,name,dateOfBirth,phone_number')
              .order('name')));
    } on AuthException {
      rethrow;
    } on PostgrestException {
      rethrow;
    } catch (_) {
      // Authorization/server errors must not silently grant cached access.
      if (await _offline()) return cached();
      rethrow;
    }
    if (_identity() != uid) throw StateError('The signed-in user changed.');
    await SupabaseOfflineCache.saveQueryRows(key, rows);
    return ScreeningPatient.parseRows(rows);
  }
}
