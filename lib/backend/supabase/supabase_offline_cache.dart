import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseOfflineCache {
  const SupabaseOfflineCache._();

  static const _queryPrefix = 'dawa_supabase_query_cache_v1:';
  static const _documentPrefix = 'dawa_supabase_document_cache_v1:';

  static String queryKey(Map<String, dynamic> descriptor) {
    return '$_queryPrefix${base64Url.encode(utf8.encode(jsonEncode(descriptor)))}';
  }

  static String documentKey(String table, String id) =>
      '$_documentPrefix$table:$id';

  static Future<void> saveQueryRows(
    String cacheKey,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(rows));
    } catch (error) {
      debugPrint('[Supabase cache] query save failed: $error');
    }
  }

  static Future<List<Map<String, dynamic>>?> readQueryRows(
    String cacheKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      return decoded
          .whereType<Map>()
          .map(
              (row) => row.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    } catch (error) {
      debugPrint('[Supabase cache] query read failed: $error');
      return null;
    }
  }

  static Future<void> saveDocumentRow(
    String table,
    String id,
    Map<String, dynamic> row,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(documentKey(table, id), jsonEncode(row));
    } catch (error) {
      debugPrint('[Supabase cache] document save failed: $error');
    }
  }

  static Future<Map<String, dynamic>?> readDocumentRow(
    String table,
    String id,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(documentKey(table, id));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (error) {
      debugPrint('[Supabase cache] document read failed: $error');
    }
    return null;
  }

  static Future<void> mergeDocumentRow(
    String table,
    String id,
    Map<String, dynamic> updates,
  ) async {
    final existing = await readDocumentRow(table, id) ?? <String, dynamic>{};
    await saveDocumentRow(table, id, {
      ...existing,
      ...updates,
      'id': id,
    });
  }
}
