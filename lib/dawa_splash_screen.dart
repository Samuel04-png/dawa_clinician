import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/components/dawa_design_system.dart';

class DawaSplashScreen extends StatefulWidget {
  const DawaSplashScreen({
    super.key,
    required this.onAnimationComplete,
  });

  static const assetPath = 'assets/dawa_intro.gif';

  // The GIF contains one 8.3-second animation cycle, closely matching the
  // previous video splash sequence without adding an unrelated startup delay.
  static const splashDuration = Duration(milliseconds: 8300);

  final VoidCallback onAnimationComplete;

  @override
  State<DawaSplashScreen> createState() => _DawaSplashScreenState();
}

class _DawaSplashScreenState extends State<DawaSplashScreen> {
  bool _hasCompleted = false;
  bool _didPrecache = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DawaSplashScreen.splashDuration, _completeSplash);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    precacheImage(
      const AssetImage(DawaSplashScreen.assetPath),
      context,
    );
  }

  void _completeSplash() {
    if (!mounted || _hasCompleted) return;
    _hasCompleted = true;
    _timer?.cancel();
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: DawaTokens.brandPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DawaTokens.brandPrimary,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widthFactor = constraints.maxWidth < 600
                  ? 0.68
                  : constraints.maxWidth < 1024
                      ? 0.50
                      : 0.38;
              final animationWidth = (constraints.maxWidth * widthFactor)
                  .clamp(180.0, 560.0)
                  .toDouble();

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: animationWidth,
                    maxHeight: constraints.maxHeight * 0.60,
                  ),
                  child: Image.asset(
                    DawaSplashScreen.assetPath,
                    width: animationWidth,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
