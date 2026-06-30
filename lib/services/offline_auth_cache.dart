import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/auth/base_auth_user_provider.dart';

class CachedAuthSession {
  const CachedAuthSession({
    required this.uid,
    required this.email,
    required this.cachedAt,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.emailVerified = true,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final bool emailVerified;
  final DateTime cachedAt;

  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
      );

  bool matchesEmail(String value) =>
      email.trim().toLowerCase() == value.trim().toLowerCase();

  bool get isUsable => uid.trim().isNotEmpty && email.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'emailVerified': emailVerified,
        'cachedAt': cachedAt.toIso8601String(),
      };

  static CachedAuthSession? fromJson(Map<String, dynamic> json) {
    final uid = json['uid']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final cachedAt = DateTime.tryParse(json['cachedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final session = CachedAuthSession(
      uid: uid,
      email: email,
      displayName: json['displayName']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      emailVerified: json['emailVerified'] != false,
      cachedAt: cachedAt,
    );
    return session.isUsable ? session : null;
  }
}

class OfflineAuthCache {
  const OfflineAuthCache._();

  static const _cachedUserKey = 'dawa_offline_cached_auth_user_v1';

  static Future<void> saveSupabaseUser(User user) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      return;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final session = CachedAuthSession(
      uid: user.id,
      email: email,
      displayName: (metadata['display_name'] ??
              metadata['full_name'] ??
              metadata['name'])
          ?.toString(),
      photoUrl: (metadata['avatar_url'] ?? metadata['picture'])?.toString(),
      phoneNumber: user.phone,
      emailVerified: user.emailConfirmedAt != null,
      cachedAt: DateTime.now().toUtc(),
    );
    await saveSession(session);
  }

  static Future<void> saveSession(CachedAuthSession session) async {
    if (!session.isUsable) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(session.toJson()));
  }

  static Future<CachedAuthSession?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CachedAuthSession.fromJson(decoded);
      }
      if (decoded is Map) {
        return CachedAuthSession.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      await prefs.remove(_cachedUserKey);
    }
    return null;
  }

  static Future<CachedAuthSession?> readSessionForEmail(String email) async {
    final cached = await readSession();
    if (cached == null || !cached.matchesEmail(email)) {
      return null;
    }
    return cached;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }
}
