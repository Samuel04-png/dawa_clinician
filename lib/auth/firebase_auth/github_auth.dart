import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';

Future<AuthResponse?> githubSignInFunc() async {
  await supabaseClient.auth.signInWithOAuth(OAuthProvider.github);
  return null;
}
