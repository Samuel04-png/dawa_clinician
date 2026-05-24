import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';
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

Stream<BaseAuthUser> clinicianSupabaseUserStream() =>
    supabaseClient.auth.onAuthStateChange
        .map((state) => state.session?.user)
        .debounce((user) => user == null && !loggedIn
            ? TimerStream(true, const Duration(seconds: 1))
            : Stream.value(user))
        .map<BaseAuthUser>(
      (user) {
        currentUser = ClinicianFirebaseUser(user);
        return currentUser!;
      },
    );

Stream<BaseAuthUser> clinicianFirebaseUserStream() =>
    clinicianSupabaseUserStream();
