import 'package:flutter/material.dart';

import 'dawa_design_system.dart';
import 'navigation_design_system.dart';

/// The common top-of-content pattern for a clinical tool. The contextual page
/// title stays in the shared app bar; this header gives the clinician purpose,
/// current context, and one primary next action.
class ClinicalPageHeader extends StatelessWidget {
  const ClinicalPageHeader({
    super.key,
    required this.subtitle,
    this.status,
    this.action,
    this.padding = const EdgeInsets.symmetric(vertical: DawaTokens.space3),
  });

  final String subtitle;
  final Widget? status;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: LayoutBuilder(builder: (context, constraints) {
          final stack = constraints.maxWidth < 640 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final supporting = Text(subtitle,
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary, height: 1.5));
          final controls = Wrap(spacing: 10, runSpacing: 10, children: [
            if (status != null) status!,
            if (action != null) action!,
          ]);
          return stack
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  supporting,
                  if (status != null || action != null) ...[
                    const SizedBox(height: DawaTokens.space3),
                    controls,
                  ],
                ])
              : Row(children: [
                  Expanded(child: supporting),
                  if (status != null || action != null) ...[
                    const SizedBox(width: DawaTokens.space4),
                    controls,
                  ],
                ]);
        }),
      );
}

/// A low-emphasis contextual status. Critical device/workflow errors should
/// use [ClinicalInlineBanner] instead so they include an explicit next action.
class ClinicalStatusChip extends StatelessWidget {
  const ClinicalStatusChip({
    super.key,
    required this.label,
    this.tone = ClinicalStatusTone.neutral,
    this.icon,
  });

  final String label;
  final ClinicalStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ClinicalStatusTone.neutral => NavigationTokens.secondary,
      ClinicalStatusTone.info => NavigationTokens.brand,
      ClinicalStatusTone.success => DawaTokens.statusSuccessText,
      ClinicalStatusTone.warning => DawaTokens.statusWarningText,
    };
    final background = switch (tone) {
      ClinicalStatusTone.neutral => DawaTokens.surfaceTertiary,
      ClinicalStatusTone.info => NavigationTokens.selected,
      ClinicalStatusTone.success => DawaTokens.statusSuccessBg,
      ClinicalStatusTone.warning => DawaTokens.statusWarningBg,
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: color.withValues(alpha: .32)),
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon ?? Icons.circle, size: icon == null ? 8 : 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: DawaTextStyles.secondary
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

enum ClinicalStatusTone { neutral, info, success, warning }

class ClinicalStatCard extends StatelessWidget {
  const ClinicalStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.width,
    this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DawaCard(
          onTap: onTap,
          padding: const EdgeInsets.all(DawaTokens.space4),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: NavigationTokens.selected,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              ),
              child: Icon(icon, color: NavigationTokens.brand, size: 20),
            ),
            const SizedBox(width: DawaTokens.space3),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style:
                            DawaTextStyles.statNumber.copyWith(fontSize: 24)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: DawaTextStyles.secondary
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DawaTextStyles.secondary.copyWith(
                            fontSize: 12, color: DawaTokens.textSecondary)),
                  ]),
            ),
          ]),
        ),
      );
}

class ClinicalEmptyState extends StatelessWidget {
  const ClinicalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.surface = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool surface;

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      liveRegion: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: NavigationTokens.brand, size: 24),
        const SizedBox(height: DawaTokens.space3),
        Text(title, style: DawaTextStyles.cardTitle),
        const SizedBox(height: 4),
        Text(message,
            style: DawaTextStyles.secondary
                .copyWith(color: DawaTokens.textSecondary)),
        const SizedBox(height: DawaTokens.space3),
        OutlinedButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(actionLabel),
        ),
      ]),
    );
    return surface ? DawaCard(child: content) : content;
  }
}

class ClinicalInlineBanner extends StatelessWidget {
  const ClinicalInlineBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));

  final ClinicalBannerTone tone;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final presentation = switch (tone) {
      ClinicalBannerTone.info => (
          NavigationTokens.brand,
          NavigationTokens.selected,
          Icons.info_outline_rounded
        ),
      ClinicalBannerTone.warning => (
          DawaTokens.statusWarningText,
          DawaTokens.statusWarningBg,
          Icons.warning_amber_rounded
        ),
      ClinicalBannerTone.error => (
          DawaTokens.statusDangerText,
          DawaTokens.statusDangerBg,
          Icons.error_outline_rounded
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DawaTokens.space3),
      decoration: BoxDecoration(
        color: presentation.$2,
        border: Border.all(color: presentation.$1.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(presentation.$3, color: presentation.$1, size: 20),
        const SizedBox(width: DawaTokens.space3),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: DawaTextStyles.cardTitle.copyWith(color: presentation.$1)),
          const SizedBox(height: 2),
          Text(message,
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textPrimary)),
          if (actionLabel != null) ...[
            const SizedBox(height: DawaTokens.space2),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ])),
      ]),
    );
  }
}

enum ClinicalBannerTone { info, warning, error }
