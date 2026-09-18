import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';
import '/services/offline_auth_cache.dart';
import '../base_auth_user_provider.dart';

export '../base_auth_user_provider.dart';

class ClinicianFirebaseUser extends BaseAuthUser {
  ClinicianFirebaseUser(this.user);
  User? user;
  bool get loggedIn => user != null;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: user?.id,
        email: user?.email,
        displayName: (user?.userMetadata?['display_name'] ??
                user?.userMetadata?['full_name'] ??
                user?.userMetadata?['name'])
            ?.toString(),
        photoUrl: (user?.userMetadata?['avatar_url'] ??
                user?.userMetadata?['picture'])
            ?.toString(),
        phoneNumber: user?.phone,
      );

  @override
  Future? delete() => supabaseClient.functions.invoke('delete-user');

  @override
  Future? updateEmail(String email) async {
    await supabaseClient.auth.updateUser(UserAttributes(email: email));
  }

  @override
  Future? updatePassword(String newPassword) async {
    await supabaseClient.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future? sendEmailVerification() {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      return Future.value();
    }
    return supabaseClient.auth.resend(type: OtpType.signup, email: email);
  }

  @override
  bool get emailVerified {
    if (loggedIn && user!.emailConfirmedAt == null) {
      refreshUser();
    }
    return user?.emailConfirmedAt != null;
  }

  @override
  Future refreshUser() async {
    final response = await supabaseClient.auth.getUser();
    user = response.user;
  }

  static BaseAuthUser fromSupabaseUser(User? user) =>
      ClinicianFirebaseUser(user);
}

class ClinicianCachedUser extends BaseAuthUser {
  ClinicianCachedUser(this.cachedSession);

  final CachedAuthSession cachedSession;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => cachedSession.emailVerified;

  @override
  AuthUserInfo get authUserInfo => cachedSession.authUserInfo;

  @override
  Future? delete() => Future.value();

  @override
  Future? updateEmail(String email) => Future.value();

  @override
  Future? updatePassword(String newPassword) => Future.value();

  @override
  Future? sendEmailVerification() => Future.value();
}

final _manualAuthUserController =
    StreamController<BaseAuthUser>.broadcast(sync: true);

void emitClinicianAuthUser(BaseAuthUser user) {
  currentUser = user;
  _manualAuthUserController.add(user);
}

Stream<BaseAuthUser> clinicianSupabaseUserStream() => Rx.merge<BaseAuthUser>([
      Stream.fromFuture(_cachedUserForStartup()).whereType<BaseAuthUser>(),
      supabaseClient.auth.onAuthStateChange
          .map((state) => state.session?.user)
          .debounce((user) => user == null && !loggedIn
              ? TimerStream(true, const Duration(seconds: 1))
              : Stream.value(user))
          .asyncMap<BaseAuthUser>(
        (user) async {
          if (user != null) {
            await OfflineAuthCache.saveSupabaseUser(user);
            currentUser = ClinicianFirebaseUser(user);
            return currentUser!;
          }

          final cached = await OfflineAuthCache.readSession();
          currentUser = cached == null
              ? ClinicianFirebaseUser(null)
              : ClinicianCachedUser(cached);
          return currentUser!;
        },
      ),
      _manualAuthUserController.stream,
    ]);

Stream<BaseAuthUser> clinicianFirebaseUserStream() =>
    clinicianSupabaseUserStream();

Future<BaseAuthUser?> _cachedUserForStartup() async {
  final liveUser = supabaseClient.auth.currentUser;
  if (liveUser != null) {
    await OfflineAuthCache.saveSupabaseUser(liveUser);
    currentUser = ClinicianFirebaseUser(liveUser);
    return currentUser;
  }

  final cached = await OfflineAuthCache.readSession();
  if (cached == null) {
    currentUser = ClinicianFirebaseUser(null);
    return currentUser;
  }
  currentUser = ClinicianCachedUser(cached);
  return currentUser;
}
