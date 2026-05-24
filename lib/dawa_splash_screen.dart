import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';

class DawaSplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const DawaSplashScreen({Key? key, required this.onAnimationComplete})
      : super(key: key);

  @override
  State<DawaSplashScreen> createState() => _DawaSplashScreenState();
}

class _DawaSplashScreenState extends State<DawaSplashScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _hasCompleted = false;
  Timer? _fallbackTimer;

  // Keep the animation controllers for fade in/out effects
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;

  late AnimationController _fadeOutController;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animations
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn),
    );

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeOut),
    );

    // Initialize video controller
    _videoController = VideoPlayerController.asset(
      'assets/Video_Not_a_GIF.mp4',
    );

    // Listen for video initialization
    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });

        // Start the animation sequence
        _startAnimationSequence();
      }
    }).catchError((error) {
      debugPrint('Error initializing video: $error');
      // Fallback: proceed after delay
      _fallbackTimer = Timer(const Duration(seconds: 3), _completeSplash);
    });
  }

  void _startAnimationSequence() async {
    // Fade in the video
    await _fadeInController.forward();

    if (!mounted || _hasCompleted) {
      return;
    }

    // Play the video
    _videoController.setVolume(0.0);
    _videoController.setLooping(false);
    _videoController.play();

    // Wait for video duration
    final duration = _videoController.value.duration;
    await Future.delayed(duration);

    if (!mounted || _hasCompleted) {
      return;
    }

    // Short pause at the end
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _hasCompleted) {
      return;
    }

    // Fade out
    await _fadeOutController.forward();

    // Trigger completion
    _completeSplash();
  }

  void _completeSplash() {
    if (!mounted || _hasCompleted) {
      return;
    }

    _hasCompleted = true;
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoController.dispose();
    _fadeInController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111F8A),
      body: Center(
        child: _buildVideoContent(),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (!_isVideoInitialized) {
      return _buildLoadingIndicator();
    }

    final screenSize = MediaQuery.of(context).size;

    final double containerWidth =
        (screenSize.width * 0.62).clamp(180.0, 520.0).toDouble();
    final double containerHeight =
        (screenSize.height * 0.48).clamp(160.0, 420.0).toDouble();

    // Get video aspect ratio
    final videoAspectRatio = _videoController.value.aspectRatio;

    // Calculate actual video dimensions within container
    double videoWidth;
    double videoHeight;

    if (containerWidth / containerHeight > videoAspectRatio) {
      // Container is wider than video aspect ratio
      videoHeight = containerHeight;
      videoWidth = videoHeight * videoAspectRatio;
    } else {
      // Container is taller than video aspect ratio
      videoWidth = containerWidth;
      videoHeight = videoWidth / videoAspectRatio;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeInController, _fadeOutController]),
      builder: (context, child) {
        // Combine fade in and fade out animations
        double opacity = 1.0;
        if (_fadeInController.isAnimating) {
          opacity = _fadeInAnimation.value;
        } else if (_fadeOutController.isAnimating) {
          opacity = _fadeOutAnimation.value;
        }

        return Opacity(
          opacity: opacity,
          child: SizedBox(
            width: containerWidth,
            height: containerHeight,
            child: Center(
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(_videoController),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    final indicatorSize = (MediaQuery.of(context).size.shortestSide * 0.34)
        .clamp(128.0, 220.0)
        .toDouble();

    return SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
