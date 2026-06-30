import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_manager.dart';
import '/services/offline_auth_cache.dart';
import '/services/offline_connectivity_service.dart';

import '/backend/backend.dart';
import 'anonymous_auth.dart';
import 'apple_auth.dart';
import 'email_auth.dart';
import 'firebase_user_provider.dart';
import 'github_auth.dart';
import 'google_auth.dart';
import 'jwt_token_auth.dart';

export '../base_auth_user_provider.dart';

class FirebasePhoneAuthManager extends ChangeNotifier {
  bool? _triggerOnCodeSent;
  Object? phoneAuthError;
  String? phoneNumber;
  void Function(BuildContext)? _onCodeSent;

  bool get triggerOnCodeSent => _triggerOnCodeSent ?? false;
  set triggerOnCodeSent(bool val) => _triggerOnCodeSent = val;

  void Function(BuildContext) get onCodeSent =>
      _onCodeSent == null ? (_) {} : _onCodeSent!;
  set onCodeSent(void Function(BuildContext) func) => _onCodeSent = func;

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }
}

class FirebaseAuthManager extends AuthManager
    with
        EmailSignInManager,
        GoogleSignInManager,
        AppleSignInManager,
        AnonymousSignInManager,
        JwtSignInManager,
        GithubSignInManager,
        PhoneSignInManager {
  FirebasePhoneAuthManager phoneAuthManager = FirebasePhoneAuthManager();

  @override
  Future signOut() async {
    await OfflineAuthCache.clear();
    emitClinicianAuthUser(ClinicianFirebaseUser.fromSupabaseUser(null));

    try {
      await supabaseClient.auth.signOut().timeout(const Duration(seconds: 6));
    } catch (error) {
      debugPrint('[Auth] Supabase sign out failed: $error');
    }
  }

  @override
  Future deleteUser(BuildContext context) async {
    try {
      if (!loggedIn) {
        print('Error: delete user attempted with no logged in user!');
        return;
      }
      await supabaseClient.functions.invoke('delete-user');
      await signOut();
    } catch (e) {
      _showError(context, e);
    }
  }

  @override
  Future updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      if (!loggedIn) {
        print('Error: update email attempted with no logged in user!');
        return;
      }
      await supabaseClient.auth.updateUser(UserAttributes(email: email));
      await updateUserDocument(email: email);
    } catch (e) {
      _showError(context, e);
    }
  }

  @override
  Future updatePassword({
    required String newPassword,
    required BuildContext context,
  }) async {
    try {
      if (!loggedIn) {
        print('Error: update password attempted with no logged in user!');
        return;
      }
      await supabaseClient.auth
          .updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      _showError(context, e);
    }
  }

  @override
  Future resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await supabaseClient.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      _showError(context, e);
      return null;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset email sent')),
    );
  }

  @override
  Future<BaseAuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) =>
      _signInOrCreateAccount(
        context,
        () => emailSignInFunc(email, password),
        offlineEmail: email,
      );

  @override
  Future<BaseAuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) =>
      _signInOrCreateAccount(
        context,
        () => emailCreateAccountFunc(email, password),
      );

  @override
  Future<BaseAuthUser?> signInAnonymously(BuildContext context) =>
      _signInOrCreateAccount(context, anonymousSignInFunc);

  @override
  Future<BaseAuthUser?> signInWithApple(BuildContext context) =>
      _signInOrCreateAccount(context, appleSignIn);

  @override
  Future<BaseAuthUser?> signInWithGoogle(BuildContext context) =>
      _signInOrCreateAccount(context, googleSignInFunc);

  @override
  Future<BaseAuthUser?> signInWithGithub(BuildContext context) =>
      _signInOrCreateAccount(context, githubSignInFunc);

  @override
  Future<BaseAuthUser?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  ) =>
      _signInOrCreateAccount(context, () => jwtTokenSignIn(jwtToken));

  void handlePhoneAuthStateChanges(BuildContext context) {
    phoneAuthManager.addListener(() {
      if (!context.mounted) {
        return;
      }

      if (phoneAuthManager.triggerOnCodeSent) {
        phoneAuthManager.onCodeSent(context);
        phoneAuthManager
            .update(() => phoneAuthManager.triggerOnCodeSent = false);
      } else if (phoneAuthManager.phoneAuthError != null) {
        _showError(context, phoneAuthManager.phoneAuthError!);
        phoneAuthManager.update(() => phoneAuthManager.phoneAuthError = null);
      }
    });
  }

  @override
  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  }) async {
    phoneAuthManager.update(() {
      phoneAuthManager.onCodeSent = onCodeSent;
      phoneAuthManager.phoneNumber = phoneNumber;
    });
    try {
      await supabaseClient.auth.signInWithOtp(phone: phoneNumber);
      phoneAuthManager.update(() {
        phoneAuthManager.triggerOnCodeSent = true;
        phoneAuthManager.phoneAuthError = null;
      });
      return true;
    } catch (e) {
      phoneAuthManager.update(() {
        phoneAuthManager.triggerOnCodeSent = false;
        phoneAuthManager.phoneAuthError = e;
      });
      return false;
    }
  }

  @override
  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  }) {
    final phone = phoneAuthManager.phoneNumber;
    if (phone == null || phone.isEmpty) {
      _showError(context, 'Phone number missing for OTP verification.');
      return Future.value(null);
    }
    return _signInOrCreateAccount(
      context,
      () => supabaseClient.auth.verifyOTP(
        phone: phone,
        token: smsCode,
        type: OtpType.sms,
      ),
    );
  }

  Future<BaseAuthUser?> _signInOrCreateAccount(
    BuildContext context,
    Future<AuthResponse?> Function() signInFunc, {
    String? offlineEmail,
  }) async {
    try {
      final authResponse = await signInFunc();
      final user = authResponse?.user ?? supabaseClient.auth.currentUser;
      final session =
          authResponse?.session ?? supabaseClient.auth.currentSession;

      if (user == null) {
        _showError(context, 'We could not complete sign in. Please try again.');
        return null;
      }

      if (session == null) {
        _showInfo(
          context,
          'Account created. Please check your email to confirm your account, then sign in.',
        );
        return null;
      }

      currentUser = ClinicianFirebaseUser.fromSupabaseUser(user);
      await maybeCreateUser(user);
      await OfflineAuthCache.saveSupabaseUser(user);
      emitClinicianAuthUser(currentUser!);
      return currentUser;
    } catch (e) {
      final offlineUser = await _tryOfflineCachedSignIn(
        context,
        email: offlineEmail,
        error: e,
      );
      if (offlineUser != null) {
        return offlineUser;
      }
      _showError(context, e);
      return null;
    }
  }

  Future<BaseAuthUser?> _tryOfflineCachedSignIn(
    BuildContext context, {
    required String? email,
    required Object error,
  }) async {
    if (email == null || email.trim().isEmpty) {
      return null;
    }
    if (error is AuthException && _isCredentialError(error)) {
      return null;
    }

    final supabaseReachable =
        await OfflineConnectivityService.isSupabaseReachable();
    if (supabaseReachable) {
      return null;
    }

    final cached = await OfflineAuthCache.readSessionForEmail(email);
    if (cached == null) {
      _showInfo(
        context,
        'Offline mode: this account must log in online once before offline access is available.',
      );
      return null;
    }

    final offlineUser = ClinicianCachedUser(cached);
    emitClinicianAuthUser(offlineUser);
    _showInfo(
      context,
      'Offline mode: signed in with cached account data.',
    );
    return offlineUser;
  }

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(BuildContext context, Object error) {
    final message = error is AuthException
        ? _friendlyAuthErrorMessage(error)
        : error.toString();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message')),
    );
  }

  String _friendlyAuthErrorMessage(AuthException error) {
    final message = error.message.trim();
    final lowerMessage = message.toLowerCase();
    final code = error.code;

    if (code == 'invalid_credentials' ||
        lowerMessage.contains('invalid login credentials')) {
      return 'Invalid email or password. If this is an existing migrated account, use Forgot Password once to set a new password, then sign in again.';
    }

    if (code == 'email_not_confirmed' ||
        lowerMessage.contains('email not confirmed')) {
      return 'Please confirm your email address before signing in.';
    }

    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        lowerMessage.contains('already registered')) {
      return 'An account with this email already exists. Try logging in or use Forgot Password.';
    }

    return message.isEmpty ? error.toString() : message;
  }

  bool _isCredentialError(AuthException error) {
    final code = error.code;
    final lowerMessage = error.message.toLowerCase();
    return code == 'invalid_credentials' ||
        lowerMessage.contains('invalid login credentials') ||
        code == 'email_not_confirmed' ||
        lowerMessage.contains('email not confirmed');
  }
}
