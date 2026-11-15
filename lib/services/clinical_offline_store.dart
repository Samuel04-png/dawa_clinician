import 'package:collection/collection.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/auth/base_auth_user_provider.dart';
import '/backend/supabase/supabase_config.dart';
import 'offline_connectivity_service.dart';

/// Clinician-scoped clinical snapshots and a durable outbox for reviewed results.
class ClinicalOfflineStore {
  static String get userId => currentUser?.loggedIn == true
      ? currentUser!.uid ?? ''
      : supabaseClient.auth.currentUser?.id ?? '';
  static bool get offline =>
      OfflineConnectivityService.statusNotifier.value?.isOffline == true;
  static String key(String uid, String name) => 'dawa_clinical_v1:$uid:$name';
  static Future<void>? _operation;
  static Future<T> locked<T>(Future<T> Function() action) {
    final previous = _operation;
    final result = previous == null ? action() : previous.then((_) => action());
    final done =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _operation = done;
    done.then((_) {
      if (identical(_operation, done)) _operation = null;
    });
    return result;
  }

  static Future<List<Map<String, dynamic>>?> cached(
      String uid, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(uid, name));
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  static Future<void> save(
      String uid, String name, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key(uid, name), jsonEncode(rows))) {
      throw StateError('Could not save clinical data on this device.');
    }
  }

  static Future<List<Map<String, dynamic>>> read(String uid, String name,
      Future<List<Map<String, dynamic>>> Function() fetch,
      {bool emptyOffline = false, String Function()? identity}) async {
    if (uid.isEmpty)
      throw StateError('Sign in before accessing clinical records.');
    Future<List<Map<String, dynamic>>> local() async {
      final rows = await cached(uid, name);
      if ((identity?.call() ?? userId) != uid)
        throw StateError('The signed-in clinician changed.');
      if (rows == null && !emptyOffline)
        throw StateError(
            'Connect once to download patients for offline screening.');
      return rows ?? [];
    }

    if (offline) return local();
    try {
      final rows = (await fetch()).toList();
      if ((identity?.call() ?? userId) != uid)
        throw StateError('The signed-in clinician changed.');
      // Preserve unsynced local history while an online refresh is in flight.
      final pending = await cached(uid, 'outbox') ?? [];
      final pendingIds = pending.map((r) => r['id']).toSet();
      final previous = await cached(uid, name) ?? [];
      for (final row in previous) {
        final exam = row['examination_id'] ?? row['examinationId'];
        if (exam != null &&
            pendingIds.contains(exam) &&
            !rows.any(
                (r) => (r['examination_id'] ?? r['examinationId']) == exam))
          rows.insert(0, row);
      }
      await save(uid, name, rows);
      return rows;
    } on AuthException {
      rethrow;
    } on PostgrestException {
      rethrow;
    } catch (_) {
      if ((await OfflineConnectivityService.refreshStatus()).isOffline)
        return local();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> persist(
      {required String uid,
      required String kind,
      required String id,
      required Map<String, dynamic> payload,
      required Map<String, dynamic> localRow,
      required Future<Map<String, dynamic>> Function() upload,
      String Function()? identity,
      void Function()? validateLocal}) async {
    if (!offline) {
      try {
        return await upload();
      } on AuthException {
        rethrow;
      } on PostgrestException {
        rethrow;
      } catch (_) {
        if (!(await OfflineConnectivityService.refreshStatus()).isOffline)
          rethrow;
      }
    }
    if (uid.isEmpty || (identity?.call() ?? userId) != uid)
      throw StateError('Sign in before saving results.');
    validateLocal?.call();
    await locked(() async {
      final rows = await cached(uid, 'outbox') ?? [];
      rows.removeWhere((r) => r['kind'] == kind && r['id'] == id);
      rows.add({'id': id, 'kind': kind, 'payload': payload});
      await save(uid, 'outbox', rows);
    });
    return localRow;
  }

  static Future<void> remember(
          String uid, String name, Map<String, dynamic> row) =>
      locked(() async {
        final rows = await cached(uid, name) ?? [];
        rows.removeWhere((r) =>
            r['id'] == row['id'] ||
            row['examination_id'] != null &&
                r['examination_id'] == row['examination_id']);
        rows.insert(0, row);
        await save(uid, name, rows);
      });
  static Future<Map<String, dynamic>> uploadUltrasound(
      Map<String, dynamic> payload) async {
    try {
      return await runSupabaseRequest(() => supabaseClient
          .from('ultrasound_scan_records')
          .insert(payload)
          .select()
          .single());
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final existing = await runSupabaseRequest(() => supabaseClient
          .from('ultrasound_scan_records')
          .select()
          .eq('examination_id', payload['examination_id'])
          .eq('user_id', payload['user_id'])
          .single());
      if (!payload.entries.every((entry) => const DeepCollectionEquality()
          .equals(existing[entry.key], entry.value))) {
        throw StateError(
            'This examination is already saved with different content.');
      }
      return existing;
    }
  }

  static Future<void> sync() => locked(() async {
        final uid = supabaseClient.auth.currentUser?.id;
        if (uid == null) return;
        final rows = await cached(uid, 'outbox') ?? [];
        final remaining = [...rows];
        for (final row in rows) {
          if (supabaseClient.auth.currentUser?.id != uid) break;
          final payload = Map<String, dynamic>.from(row['payload'] as Map);
          try {
            if (row['kind'] == 'anemia') {
              await runSupabaseRequest(() => supabaseClient
                  .rpc('save_anemia_screening_review', params: payload)
                  .single());
            } else if (row['kind'] == 'ultrasound') {
              await uploadUltrasound(payload);
            } else {
              continue;
            }
            remaining.remove(row);
            await save(uid, 'outbox', remaining);
          } catch (_) {
            /* Preserve rejected and interrupted uploads for retry. */
          }
        }
      });
}
