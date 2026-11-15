import 'package:flutter/material.dart';
import '/components/navigation_design_system.dart';
import '/services/edge_device/edge_device_manager.dart';

class WorkspacePageHeader extends StatelessWidget {
  const WorkspacePageHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onOpenNavigation,
      this.contextLabel,
      this.action,
      this.deviceManager,
      this.fitTitle = false});
  final String title, subtitle;
  final String? contextLabel;
  final Widget? action;
  final VoidCallback onOpenNavigation;
  final EdgeDeviceManager? deviceManager;
  final bool fitTitle;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final desktop = MediaQuery.sizeOf(context).width >=
            NavigationTokens.desktopBreakpoint;
        final largeType = MediaQuery.textScalerOf(context).scale(14) > 21;
        final wide = constraints.maxWidth >= 760 && !largeType;
        final titleText = Text(title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: NavigationTokens.text,
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w600));
        final heading = Semantics(
            header: true,
            child: fitTitle
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: titleText)
                : titleText);
        final description = Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavigationTokens.secondary, fontSize: 13, height: 1.45));
        final contextText = contextLabel == null
            ? null
            : Text(contextLabel!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NavigationTokens.secondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500));
        const menu = SizedBox.shrink();
        const controls = SizedBox.shrink();
        if (constraints.maxWidth < 600 && largeType) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!desktop) menu else const SizedBox.shrink(),
                      controls
                    ]),
                const SizedBox(height: 8),
                heading,
                const SizedBox(height: 6),
                description,
                if (contextText != null) ...[
                  const SizedBox(height: 6),
                  contextText
                ],
                if (action != null) ...[const SizedBox(height: 12), action!],
              ]);
        }
        if (!wide && action != null) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!desktop) ...[menu, const SizedBox(width: 8)],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        heading,
                        const SizedBox(height: 6),
                        description,
                      ])),
                  const SizedBox(width: 12),
                  controls,
                ]),
                const SizedBox(height: 12),
                action!,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!desktop) ...[menu, const SizedBox(width: 8)],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                heading,
                const SizedBox(height: 6),
                description,
                if (!wide && contextText != null) ...[
                  const SizedBox(height: 6),
                  contextText
                ],
              ])),
          const SizedBox(width: 12),
          if (wide && contextText != null) ...[
            Padding(
                padding: const EdgeInsets.only(top: 10), child: contextText),
            const SizedBox(width: 8)
          ],
          if (action != null) ...[action!, const SizedBox(width: 12)],
          controls,
        ]);
      });
}
