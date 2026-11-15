import 'package:flutter/material.dart';
import '/components/navigation_design_system.dart';

enum SecondOpinionChoice { sendOnline, retryDevice, cancel }

class CacxSecondOpinionDialog extends StatelessWidget {
  const CacxSecondOpinionDialog(
      {super.key, required this.reason, required this.canRetry});
  final String reason;
  final bool canRetry;
  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        backgroundColor: NavigationTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 480),
        title: const Text('Online second opinion',
            style: NavigationTokens.titleStyle),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reason),
          const SizedBox(height: 12),
          const Text(
              'Sending uploads the selected cervical image to the online second-opinion service, outside the clinic network. Internet access is required.'),
          const SizedBox(height: 12),
          const Text('Service: kmunzwa-medsiglip-demo.hf.space'),
          const SizedBox(height: 12),
          const Text('Choosing “Do not send” keeps the image in this workflow.',
              style: TextStyle(color: NavigationTokens.secondary)),
        ]),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, SecondOpinionChoice.cancel),
              child: const Text('Do not send')),
          if (canRetry)
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, SecondOpinionChoice.retryDevice),
                child: const Text('Retry device')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: NavigationTokens.brand),
              onPressed: () =>
                  Navigator.pop(context, SecondOpinionChoice.sendOnline),
              child: const Text('Send online')),
        ],
      );
}
