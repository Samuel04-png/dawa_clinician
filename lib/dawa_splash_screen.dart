import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DawaSplashScreen extends StatefulWidget {
  const DawaSplashScreen({
    super.key,
    required this.onAnimationComplete,
  });

  static const assetPath = 'assets/dawa_intro.gif';
  static const splashBackgroundColor = Color(0xFF102490);
  static const splashDuration = Duration(seconds: 2);

  final VoidCallback onAnimationComplete;

  @override
  State<DawaSplashScreen> createState() => _DawaSplashScreenState();
}

class _DawaSplashScreenState extends State<DawaSplashScreen> {
  Timer? _timer;
  bool _hasCompleted = false;
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Splash] Showing ${DawaSplashScreen.assetPath}.');
    _timer = Timer(DawaSplashScreen.splashDuration, _completeAnimation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    precacheImage(
      const AssetImage(DawaSplashScreen.assetPath),
      context,
    ).catchError((Object error) {
      debugPrint('[Splash] Failed to precache the intro GIF: $error');
    });
  }

  void _completeAnimation() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _timer?.cancel();
    debugPrint('[Splash] Intro GIF display completed.');
    if (mounted) widget.onAnimationComplete();
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
        systemNavigationBarColor: DawaSplashScreen.splashBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DawaSplashScreen.splashBackgroundColor,
        body: Semantics(
          label: 'Dawa introduction animation',
          image: true,
          child: SizedBox.expand(
            child: Image.asset(
              DawaSplashScreen.assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
