import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';

Future<AuthResponse> anonymousSignInFunc() =>
    supabaseClient.auth.signInAnonymously();
