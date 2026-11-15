import 'package:flutter/material.dart';
import 'navigation_design_system.dart';
import 'clinician_navigation.dart';

/// Uses the authentic, high-resolution Dawa mark. The larger image canvas
/// compensates only for the original white margins; no brand artwork is redrawn.
class DawaBrandMark extends StatelessWidget {
  const DawaBrandMark({super.key, this.size = 46});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Dawa Health',
      image: true,
      child: SizedBox.square(
          dimension: size,
          child: ClipRect(
              child: OverflowBox(
            minWidth: size * 1.38,
            maxWidth: size * 1.38,
            minHeight: size * 1.38,
            maxHeight: size * 1.38,
            child: Image.asset('assets/images/dawa_cross.png',
                excludeFromSemantics: true,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high),
          ))));
}

class NavigationBrandHeader extends StatelessWidget {
  const NavigationBrandHeader(
      {super.key, required this.collapsed, required this.drawer});
  final bool collapsed, drawer;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: NavigationTokens.headerHeight,
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 11 : 12),
          child: Row(children: [
            DawaBrandMark(size: collapsed ? 42 : 46),
            if (!collapsed) ...[
              const SizedBox(width: NavigationTokens.iconGap),
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Dawa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NavigationTokens.brandStyle
                            .copyWith(color: NavigationTokens.brand)),
                    const Text('Clinician',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NavigationTokens.secondaryStyle),
                  ])),
              IconButton(
                  tooltip: drawer ? 'Close navigation' : 'Collapse navigation',
                  onPressed: drawer
                      ? () => Navigator.of(context).pop()
                      : () => clinicianSidebarCollapsed.value = true,
                  icon: NavigationIcon(
                      drawer
                          ? NavigationSymbol.close
                          : NavigationSymbol.sidebar,
                      color: NavigationTokens.secondary)),
            ],
          ])));
}
