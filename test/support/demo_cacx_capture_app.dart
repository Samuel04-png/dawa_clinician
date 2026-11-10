import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'http://127.0.0.1:54321',
    anonKey: 'local-anon-key-for-demo-capture',
  );
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CaCxApp(),
    ),
  );
}
