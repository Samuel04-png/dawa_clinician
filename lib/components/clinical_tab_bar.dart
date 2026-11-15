import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'navigation_design_system.dart';

/// A single tab definition for the compact horizontal [ClinicalTabBar].
class ClinicalTab {
  const ClinicalTab(this.label, {this.icon, this.trailing});
  final String label;
  final IconData? icon;
  final Widget? trailing;
}

/// Compact horizontal secondary navigation inside a clinical module.
///
/// Replaces the older nested module sidebars while preserving the same set of
/// destinations. Styling mirrors the shared Dawa navigation design system so
/// the tool feels like part of one application.
class ClinicalTabBar extends StatelessWidget {
  const ClinicalTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelected,
    this.fill = false,
    this.enabled = true,
  });

  final List<ClinicalTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final bool fill, enabled;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();
    final content = fill
        ? Row(children: [
            for (var i = 0; i < tabs.length; i++) ...[
              Expanded(
                  child: _ClinicalTabItem(
                      tab: tabs[i],
                      selected: i == activeIndex,
                      onTap: enabled ? () => onSelected(i) : null)),
            ],
          ])
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++) ...[
                _ClinicalTabItem(
                    tab: tabs[i],
                    selected: i == activeIndex,
                    onTap: enabled ? () => onSelected(i) : null),
                if (i != tabs.length - 1) const SizedBox(width: 4),
              ],
            ]));
    return SizedBox(
        width: double.infinity,
        child: Material(
          color: NavigationTokens.surface,
          child: Container(
            decoration: const BoxDecoration(
              color: NavigationTokens.surface,
              border: Border(
                bottom: BorderSide(color: NavigationTokens.border, width: 1),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ));
  }
}

class _ClinicalTabItem extends StatefulWidget {
  const _ClinicalTabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final ClinicalTab tab;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ClinicalTabItem> createState() => _ClinicalTabItemState();
}

class _ClinicalTabItemState extends State<_ClinicalTabItem> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final token = NavigationTokens.duration(context);
    final foreground =
        widget.selected ? NavigationTokens.brand : NavigationTokens.secondary;
    final background = widget.selected
        ? NavigationTokens.selected.withValues(alpha: .55)
        : _hovered
            ? NavigationTokens.hover
            : Colors.transparent;
    return Semantics(
      selected: widget.selected,
      enabled: widget.onTap != null,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        borderRadius: BorderRadius.circular(NavigationTokens.radius),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: AnimatedContainer(
          duration: token,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(NavigationTokens.radius),
            border: Border.all(
              color: _focused
                  ? NavigationTokens.brand
                  : widget.selected
                      ? NavigationTokens.selected
                      : Colors.transparent,
            ),
            boxShadow: _pressed
                ? const [
                    BoxShadow(
                        color: Color(0x0F223F91),
                        blurRadius: 4,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tab.icon != null) ...[
                Icon(
                  widget.tab.icon,
                  size: 17,
                  color: _focused ? NavigationTokens.brand : foreground,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                widget.tab.label,
                style: NavigationTokens.itemStyle.copyWith(
                  color: _focused ? NavigationTokens.brand : foreground,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (widget.tab.trailing != null) ...[
                const SizedBox(width: 6),
                widget.tab.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Phosphor-symbol mapping shared by clinical module headers, keeping tab
/// icons consistent with the navigation icon set.
IconData clinicalModuleIcon(ClinicalTabHost host) => switch (host) {
      ClinicalTabHost.cervical => PhosphorIconsRegular.microscope,
      ClinicalTabHost.ultrasound => PhosphorIconsRegular.clipboardText,
      ClinicalTabHost.anemia => PhosphorIconsRegular.drop,
      ClinicalTabHost.ct => PhosphorIconsRegular.clipboardText,
      ClinicalTabHost.bloodPressure => PhosphorIconsRegular.heartbeat,
    };

enum ClinicalTabHost { cervical, ultrasound, anemia, ct, bloodPressure }
