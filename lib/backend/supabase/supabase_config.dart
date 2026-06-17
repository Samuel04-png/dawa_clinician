import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://eatliepvwrviogsnqavu.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_Ezu7cDbD58QMAbSfz04UNA_DkLOt2-J',
);

bool _supabaseInitialized = false;
Future<void>? _sessionRefreshFuture;

Future<void> initSupabase() async {
  if (_supabaseInitialized) {
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  _supabaseInitialized = true;
}

Future<void> initSupabaseForMigration() => initSupabase();

SupabaseClient get supabaseClient => Supabase.instance.client;
SupabaseClient get supabaseMigrationClient => supabaseClient;

Future<T> runSupabaseRequest<T>(FutureOr<T> Function() request) async {
  await ensureFreshSupabaseSession();
  try {
    return await request();
  } on PostgrestException catch (error) {
    if (!_isExpiredJwtError(error)) {
      rethrow;
    }
    await ensureFreshSupabaseSession(forceRefresh: true);
    return await request();
  } on FormatException catch (e) {
    // Supabase returned non-JSON (e.g. HTML maintenance page).
    // Wrap in a more descriptive error so callers can handle it gracefully.
    throw FormatException(
      'Supabase returned non-JSON response. The project may be paused or unavailable.\n'
      'Details: ${e.message}',
    );
  }
}

Future<void> ensureFreshSupabaseSession({bool forceRefresh = false}) async {
  final session = supabaseClient.auth.currentSession;
  if (session == null || session.refreshToken == null) {
    return;
  }

  if (!forceRefresh && !session.isExpired && !_expiresSoon(session.expiresAt)) {
    return;
  }

  final refreshFuture = _sessionRefreshFuture ??=
      supabaseClient.auth.refreshSession().then((_) {});
  try {
    await refreshFuture;
  } finally {
    if (identical(_sessionRefreshFuture, refreshFuture)) {
      _sessionRefreshFuture = null;
    }
  }
}

bool _expiresSoon(int? expiresAt) {
  if (expiresAt == null) {
    return false;
  }
  final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  return DateTime.now().add(const Duration(minutes: 2)).isAfter(expiryTime);
}

bool _isExpiredJwtError(PostgrestException error) {
  final code = error.code?.toUpperCase();
  final message = error.message.toLowerCase();
  return code == 'PGRST303' ||
      (code == '401' && message.contains('jwt')) ||
      message.contains('jwt expired');
}
