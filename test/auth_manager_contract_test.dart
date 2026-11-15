import 'dart:convert';
import 'package:clinician/auth/firebase_auth/auth_util.dart';

import 'package:clinician/auth/firebase_auth/firebase_auth_manager.dart';
import 'package:clinician/auth/firebase_auth/firebase_user_provider.dart';
import 'package:clinician/backend/backend.dart';
import 'package:clinician/services/offline_auth_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  String? errorCode;
  bool confirmationRequired = false, existingProfile = true, rejectOtp = false;
  const uid = '11111111-1111-4111-8111-111111111111';
  final user = {
    'id': uid,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'qa@example.invalid',
    'created_at': '2026-01-01T00:00:00Z',
    'email_confirmed_at': '2026-01-01T00:00:00Z',
    'user_metadata': {'display_name': 'Synthetic Clinician'}
  };
  Map<String, dynamic> session() => {
        'access_token': 'synthetic-token',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': user
      };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'local-test-key',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          dynamic data = {};
          var status = 200;
          if (request.url.path.contains('/auth/')) {
            if (errorCode != null && request.url.path.endsWith('token')) {
              status = 400;
              data = {
                'msg': errorCode == 'email_not_confirmed'
                    ? 'Email not confirmed'
                    : 'Invalid login credentials',
                'code': errorCode
              };
            } else if (request.url.path.endsWith('signup') &&
                confirmationRequired) {
              data = user;
            } else if (request.url.path.endsWith('otp') && rejectOtp) {
              status = 429;
              data = {
                'msg': 'Please wait before requesting another code',
                'code': 'over_sms_send_rate_limit'
              };
            } else if (request.url.path.endsWith('user')) {
              data = user;
            } else if (request.url.path.endsWith('token') ||
                request.url.path.endsWith('verify') ||
                request.url.path.endsWith('signup')) {
              data = session();
            }
          } else if (request.url.path.endsWith('/user')) {
            data = request.method == 'GET' && !existingProfile
                ? null
                : {
                    'id': uid,
                    'uid': uid,
                    'email': 'qa@example.invalid',
                    'role': 'clinician'
                  };
          }
          return http.Response(jsonEncode(data), status,
              headers: {'content-type': 'application/json'}, request: request);
        }));
  });
  setUp(() async {
    errorCode = null;
    confirmationRequired = false;
    existingProfile = true;
    rejectOtp = false;
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    emitClinicianAuthUser(ClinicianFirebaseUser(null));
    await OfflineAuthCache.clear();
    requests.clear();
  });
  tearDownAll(() async => Supabase.instance.dispose());
  Future<BuildContext> contextFor(WidgetTester tester) async {
    late BuildContext context;
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    }))));
    return context;
  }

  testWidgets(
      'valid email sign-in loads profile, caches identity and sign-out clears it',
      (tester) async {
    final context = await contextFor(tester);
    final manager = FirebaseAuthManager();
    final result = await manager.signInWithEmail(
        context, ' qa@example.invalid ', 'synthetic-password');
    expect(result?.uid, uid);
    expect(result?.displayName, 'Synthetic Clinician');
    expect(currentUserDocument?.role, 'clinician');
    expect((await OfflineAuthCache.readSession())?.uid, uid);
    expect(jsonDecode(requests.first.body)['email'], 'qa@example.invalid');
    await tester.runAsync(() => manager.signOut());
    expect(await OfflineAuthCache.readSession(), isNull);
    expect(Supabase.instance.client.auth.currentUser, isNull);
  });
  testWidgets(
      'missing profile is created without inventing an administrator role',
      (tester) async {
    existingProfile = false;
    final context = await contextFor(tester);
    await FirebaseAuthManager()
        .signInWithEmail(context, 'qa@example.invalid', 'synthetic-password');
    final write = requests
        .singleWhere((r) => r.url.path.endsWith('/user') && r.method == 'POST');
    final payload = jsonDecode(write.body) as Map;
    expect(payload['uid'], uid);
    expect(payload['email'], 'qa@example.invalid');
    expect(payload.containsKey('role'), isFalse);
    expect(currentUserDocument?.displayName, 'Synthetic Clinician');
  });
  for (final code in ['invalid_credentials', 'email_not_confirmed']) {
    testWidgets('$code cannot bypass credentials through a cached identity',
        (tester) async {
      errorCode = code;
      await OfflineAuthCache.saveSession(CachedAuthSession(
          uid: uid, email: 'qa@example.invalid', cachedAt: DateTime.utc(2026)));
      final context = await contextFor(tester);
      expect(
          await FirebaseAuthManager()
              .signInWithEmail(context, 'qa@example.invalid', 'wrong-password'),
          isNull);
      await tester.pump();
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(requests.where((r) => r.url.path.endsWith('/user')), isEmpty);
      expect(
          find.textContaining(code == 'invalid_credentials'
              ? 'Invalid email or password'
              : 'Please confirm your email'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'signup requiring email confirmation does not create a profile or cached login',
      (tester) async {
    confirmationRequired = true;
    final context = await contextFor(tester);
    expect(
        await tester.runAsync(() => FirebaseAuthManager()
            .createAccountWithEmail(
                context, 'qa@example.invalid', 'synthetic-password')),
        isNull);
    await tester.pump();
    expect(find.textContaining('Please check your email'), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('/user')), isEmpty);
    expect(await OfflineAuthCache.readSession(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('logged-out account mutations do not send network requests',
      (tester) async {
    final context = await contextFor(tester);
    final manager = FirebaseAuthManager();
    await manager.deleteUser(context);
    await manager.updateEmail(email: 'other@example.invalid', context: context);
    await manager.updatePassword(
        newPassword: 'synthetic-password', context: context);
    expect(requests, isEmpty);
  });
  testWidgets('password reset trims the email and confirms the request',
      (tester) async {
    final context = await contextFor(tester);
    await tester.runAsync(() => FirebaseAuthManager()
        .resetPassword(email: ' qa@example.invalid ', context: context));
    await tester.pump();
    expect(jsonDecode(requests.single.body)['email'], 'qa@example.invalid');
    expect(find.text('Password reset email sent'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'OTP success triggers callback once and missing phone cannot verify',
      (tester) async {
    final context = await contextFor(tester);
    final manager = FirebaseAuthManager();
    var callbacks = 0;
    manager.handlePhoneAuthStateChanges(context);
    expect(
        await tester.runAsync(() => manager.beginPhoneAuth(
            context: context,
            phoneNumber: '+260000000000',
            onCodeSent: (_) => callbacks++)),
        isTrue);
    expect(callbacks, 1);
    expect(manager.phoneAuthManager.triggerOnCodeSent, isFalse);
    manager.phoneAuthManager.update(() {});
    expect(callbacks, 1);
    manager.phoneAuthManager.phoneNumber = null;
    final before = requests.length;
    expect(await manager.verifySmsCode(context: context, smsCode: '123456'),
        isNull);
    expect(requests.length, before);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'OTP rejection is recoverable and never triggers the code-sent callback',
      (tester) async {
    rejectOtp = true;
    final context = await contextFor(tester);
    final manager = FirebaseAuthManager();
    var callbacks = 0;
    manager.handlePhoneAuthStateChanges(context);
    expect(
        await tester.runAsync(() => manager.beginPhoneAuth(
            context: context,
            phoneNumber: '+260000000000',
            onCodeSent: (_) => callbacks++)),
        isFalse);
    await tester.pump();
    expect(callbacks, 0);
    expect(manager.phoneAuthManager.phoneAuthError, isNull);
    expect(
        find.textContaining('Please wait before requesting'), findsOneWidget);
    rejectOtp = false;
    expect(
        await tester.runAsync(() => manager.beginPhoneAuth(
            context: context,
            phoneNumber: '+260000000000',
            onCodeSent: (_) => callbacks++)),
        isTrue);
    expect(callbacks, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
