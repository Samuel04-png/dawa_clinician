import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';

Future<AuthResponse> emailSignInFunc(
  String email,
  String password,
) =>
    supabaseClient.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

Future<AuthResponse> emailCreateAccountFunc(
  String email,
  String password,
) =>
    supabaseClient.auth.signUp(
      email: email.trim(),
      password: password,
    );
