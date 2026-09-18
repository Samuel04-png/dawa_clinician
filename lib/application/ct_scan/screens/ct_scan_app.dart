import 'package:flutter/material.dart';

import '../controllers/ct_scan_controller.dart';
import '../widgets/ct_scan_module_shell.dart';

class CtScanApp extends StatefulWidget {
  const CtScanApp({super.key});

  static String routeName = 'CtScan';
  static String routePath = '/ct-scan';

  @override
  State<CtScanApp> createState() => _CtScanAppState();
}

class _CtScanAppState extends State<CtScanApp> {
  late final CtScanController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CtScanController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CtScanModuleShell(controller: _controller);
  }
}
