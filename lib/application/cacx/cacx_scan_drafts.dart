import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '/backend/supabase/supabase_config.dart';

/// Captured images awaiting analysis. These are never presented as AI results.
class CacxScanDrafts {
  static const _key = 'dawa_cervical_drafts_v1';
  static Future<void> _serial = Future.value();

  static Future<T> _locked<T>(Future<T> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<List<Map<String, dynamic>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<void> _write(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(rows))) {
      throw StateError('Could not save scan on this device.');
    }
  }

  static Future<List<Map<String, dynamic>>> forUser(String uid) =>
      _locked(() async {
        if (uid.isEmpty) return [];
        return (await _read())
            .where((row) =>
                row['user_id'] == uid && row['status'] == 'awaiting_analysis')
            .toList();
      });

  static Future<String> save(
          {required String uid,
          required String patientId,
          required String patientName,
          required String image,
          String? id}) =>
      _locked(() async {
        if (uid.isEmpty ||
            patientId.isEmpty ||
            !image.startsWith('data:image/')) {
          throw StateError(
              'Sign in, select a patient and prepare an image first.');
        }
        final rows = await _read();
        final draftId = id ?? const Uuid().v4();
        rows.removeWhere((row) =>
            row['id'] == draftId &&
            row['user_id'] == uid &&
            row['status'] == 'awaiting_analysis');
        rows.add({
          'id': draftId,
          'user_id': uid,
          'patient_id': patientId,
          'patient_name': patientName,
          'image_data_uri': image,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'awaiting_analysis',
          'synced': false
        });
        await _write(rows);
        return draftId;
      });

  static Future<void> markAnalyzed(String uid, String id) => _locked(() async {
        final rows = await _read();
        for (final row in rows) {
          if (row['user_id'] == uid && row['id'] == id) {
            row['status'] = 'analyzed';
            row['synced'] = false;
          }
        }
        await _write(rows);
      });

  static Future<void> sync(
          {String? userId,
          Future<void> Function(Map<String, dynamic>)? upload}) =>
      _locked(() async {
        final uid = userId ?? supabaseClient.auth.currentUser?.id;
        if (uid == null || uid.isEmpty) return;
        final rows = await _read();
        for (final row in rows) {
          if (row['user_id'] != uid || row['synced'] == true) continue;
          final payload = Map<String, dynamic>.from(row)..remove('synced');
          try {
            if (upload != null) {
              await upload(payload);
            } else {
              if (supabaseClient.auth.currentUser?.id != uid) break;
              await runSupabaseRequest(() => supabaseClient
                  .from('cacx_scan_drafts')
                  .upsert(payload, onConflict: 'id'));
            }
            row['synced'] = true;
            await _write(rows);
          } catch (_) {
            // Retain the complete image until upload succeeds; retry on reconnect.
          }
        }
      });
}
