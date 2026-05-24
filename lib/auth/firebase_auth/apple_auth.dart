import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';

Future<AuthResponse?> appleSignIn() async {
  await supabaseClient.auth.signInWithOAuth(OAuthProvider.apple);
  return null;
}
