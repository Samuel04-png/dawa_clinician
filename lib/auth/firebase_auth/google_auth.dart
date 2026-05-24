import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';

Future<AuthResponse?> googleSignInFunc() async {
  await supabaseClient.auth.signInWithOAuth(OAuthProvider.google);
  return null;
}

Future signOutWithGoogle() => supabaseClient.auth.signOut();
