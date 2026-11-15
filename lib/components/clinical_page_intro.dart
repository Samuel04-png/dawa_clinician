import 'package:flutter/material.dart';
import 'navigation_design_system.dart';

/// Compact page introduction shown at the top of a clinical module's content.
///
/// The page title itself lives in the shared app bar, so this component only
/// carries the subtitle, an optional module status chip, and an optional
/// primary action. This avoids repeating the same heading several times.
class ClinicalPageIntro extends StatelessWidget {
  const ClinicalPageIntro({
    super.key,
    required this.subtitle,
    this.status,
    this.action,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 22, 24, 16),
  });

  final String subtitle;
  final Widget? status;
  final Widget? action;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final description = Text(subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: NavigationTokens.secondary, fontSize: 13, height: 1.5));
    return Padding(
      padding: contentPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasStatusOrAction = status != null || action != null;
          final stack = hasStatusOrAction &&
              (constraints.maxWidth < 640 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21);
          final trailing = <Widget>[
            if (status != null) status!,
            if (action != null) ...[
              if (status != null) const SizedBox(width: 10),
              action!,
            ],
          ];
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                if (hasStatusOrAction) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: trailing),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: description),
              if (hasStatusOrAction) ...[
                const SizedBox(width: 16),
                ...trailing,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Small inline chip used to surface a module's model/device status at the top
/// of the page, without duplicating the global hub indicator in the app bar.
class ClinicalStatusChip extends StatelessWidget {
  const ClinicalStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NavigationTokens.radius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
              child: Text(label,
                  style: NavigationTokens.secondaryStyle
                      .copyWith(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NavigationTokens.radius),
      child: chip,
    );
  }
}
