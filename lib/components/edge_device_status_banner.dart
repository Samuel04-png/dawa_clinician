import 'package:flutter/material.dart';

import '/components/dawa_design_system.dart';
import '/services/edge_device/edge_device_models.dart';

class EdgeDeviceStatusBanner extends StatelessWidget {
  const EdgeDeviceStatusBanner({
    super.key,
    required this.state,
    this.message,
    this.model,
  });

  final EdgeAIModel? model;
  final EdgeDeviceState state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(state, model);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: presentation.color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(presentation.icon, color: presentation.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: DawaTextStyles.secondary.copyWith(
                    color: presentation.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    message!,
                    style: DawaTextStyles.secondary.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _EdgeDeviceStatusPresentation _presentation(
    EdgeDeviceState state,
    EdgeAIModel? model,
  ) {
    return switch (state) {
      EdgeDeviceState.disconnected => const _EdgeDeviceStatusPresentation(
          'Device unavailable',
          Icons.portable_wifi_off,
          DawaTokens.statusDanger,
          DawaTokens.statusDangerBg,
        ),
      EdgeDeviceState.connecting ||
      EdgeDeviceState.connected ||
      EdgeDeviceState.checkingCapabilities =>
        const _EdgeDeviceStatusPresentation(
          'Connecting to device',
          Icons.sync,
          DawaTokens.statusInfo,
          DawaTokens.statusInfoBg,
        ),
      EdgeDeviceState.loadingModel => _EdgeDeviceStatusPresentation(
          switch (model) {
            EdgeAIModel.cervicalCancer => 'Preparing cervical AI',
            EdgeAIModel.ultrasound => 'Preparing ultrasound AI',
            null => 'Preparing AI model',
          },
          Icons.hourglass_top,
          DawaTokens.statusInfo,
          DawaTokens.statusInfoBg,
        ),
      EdgeDeviceState.ready => const _EdgeDeviceStatusPresentation(
          'Model ready',
          Icons.check_circle_outline,
          DawaTokens.statusSuccess,
          DawaTokens.statusSuccessBg,
        ),
      EdgeDeviceState.examining => const _EdgeDeviceStatusPresentation(
          'Examination in progress',
          Icons.monitor_heart_outlined,
          DawaTokens.statusInfo,
          DawaTokens.statusInfoBg,
        ),
      EdgeDeviceState.busy => const _EdgeDeviceStatusPresentation(
          'Device busy',
          Icons.hourglass_empty,
          DawaTokens.statusWarning,
          DawaTokens.statusWarningBg,
        ),
      EdgeDeviceState.error => const _EdgeDeviceStatusPresentation(
          'Model initialization failed',
          Icons.error_outline,
          DawaTokens.statusDanger,
          DawaTokens.statusDangerBg,
        ),
      EdgeDeviceState.unverified => const _EdgeDeviceStatusPresentation(
          'Model readiness unverified',
          Icons.help_outline,
          DawaTokens.statusWarning,
          DawaTokens.statusWarningBg,
        ),
      EdgeDeviceState.unsupported => const _EdgeDeviceStatusPresentation(
          'Model unavailable',
          Icons.info_outline,
          DawaTokens.statusWarning,
          DawaTokens.statusWarningBg,
        ),
    };
  }
}

class _EdgeDeviceStatusPresentation {
  const _EdgeDeviceStatusPresentation(
    this.title,
    this.icon,
    this.color,
    this.background,
  );

  final String title;
  final IconData icon;
  final Color color;
  final Color background;
}
