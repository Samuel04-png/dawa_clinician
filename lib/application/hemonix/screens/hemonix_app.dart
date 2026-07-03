import 'package:flutter/material.dart';

import '../controllers/hemonix_controller.dart';
import '../widgets/hemonix_module_shell.dart';

class HemonixApp extends StatefulWidget {
  const HemonixApp({super.key});

  static String routeName = 'HemoNix';
  static String routePath = '/hemonix';

  @override
  State<HemonixApp> createState() => _HemonixAppState();
}

class _HemonixAppState extends State<HemonixApp> {
  late final HemonixController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HemonixController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HemonixModuleShell(controller: _controller);
  }
}
