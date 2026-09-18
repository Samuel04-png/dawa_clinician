import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'shimmer_animation_model.dart';
export 'shimmer_animation_model.dart';

class ShimmerAnimationWidget extends StatefulWidget {
  const ShimmerAnimationWidget({super.key});

  @override
  State<ShimmerAnimationWidget> createState() => _ShimmerAnimationWidgetState();
}

class _ShimmerAnimationWidgetState extends State<ShimmerAnimationWidget>
    with TickerProviderStateMixin {
  late ShimmerAnimationModel _model;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ShimmerAnimationModel());

    animationsMap.addAll({
      'imageOnPageLoadAnimation': AnimationInfo(
        loop: true,
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 830.0.ms,
            begin: Offset(0.0, 800.0),
            end: Offset(0.0, -800.0),
          ),
        ],
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                height: 40.0,
                constraints: BoxConstraints(
                  maxWidth: 250.0,
                ),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 6.0,
                      sigmaY: 6.0,
                    ),
                    child: Transform.rotate(
                      angle: 108.0 * (math.pi / 180),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.asset(
                          'assets/images/background.jpg',
                          width: double.infinity,
                          height: 60.0,
                          fit: BoxFit.cover,
                        ),
                      ).animateOnPageLoad(
                          animationsMap['imageOnPageLoadAnimation']!),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ].divide(SizedBox(height: 8.0)),
    );
  }
}
