import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Scoped to navigation: clinical page themes and brand artwork stay intact.
abstract final class NavigationTokens {
  static const brand = Color(0xFF223F91);
  static const selected = Color(0xFFEAF0FF);
  static const selectedText = Color(0xFF1F397E);
  static const canvas = Color(0xFFF8FAFD);
  static const surface = Colors.white;
  static const text = Color(0xFF1F2937);
  static const secondary = Color(0xFF64748B);
  static const itemText = Color(0xFF475569);
  static const border = Color(0xFFE4EAF3);
  static const hover = Color(0xFFF1F5FA);
  static const pressed = Color(0xFFE0E9FB);
  static const connected = Color(0xFF16A34A);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFDC2626);
  static const desktopBreakpoint = 1024.0;
  static const expandedWidth = 256.0;
  static const collapsedWidth = 64.0;
  static const rowHeight = 44.0;
  static const touchHeight = 48.0;
  static const appBarHeight = 64.0;
  static const headerHeight = 80.0;
  static const iconSize = 20.0;
  static const radius = 8.0;
  static const space = 4.0;
  static const gutter = space * 3;
  static const iconGap = space * 3;
  static const sectionGap = space;
  static const disclosureIndent = space * 4;
  static const stateDuration = Duration(milliseconds: 100);
  static const layoutDuration = Duration(milliseconds: 180);
  static const deviceDuration = Duration(milliseconds: 900);
  static Duration duration(BuildContext context, {bool layout = false}) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : layout
              ? layoutDuration
              : stateDuration;
  // Inherit DM Sans from the application; do not start another font loader.
  static const brandStyle =
      TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w600);
  static const titleStyle = TextStyle(
      fontSize: 19, height: 1.25, fontWeight: FontWeight.w600, color: text);
  static const itemStyle =
      TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w500);
  static const sectionStyle = TextStyle(
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w500,
      letterSpacing: .6,
      color: secondary);
  static const secondaryStyle =
      TextStyle(fontSize: 12, height: 1.4, color: secondary);
  static const detailStyle = TextStyle(fontSize: 13, height: 1.4, color: text);
}

enum NavigationSymbol {
  back,
  home,
  patients,
  appointments,
  screenings,
  cervical,
  ultrasound,
  anemia,
  ct,
  bloodPressure,
  settings,
  account,
  sidebar,
  device,
  chevron,
  close,
  menu,
  retry,
  info,
  signOut,
  check,
  warning,
}

/// Phosphor regular/bold plus two clinical drawings on the same 24-unit grid.
class NavigationIcon extends StatelessWidget {
  const NavigationIcon(this.symbol,
      {super.key,
      this.color,
      this.strong = false,
      this.size = NavigationTokens.iconSize});
  final NavigationSymbol symbol;
  final Color? color;
  final bool strong;
  final double size;
  static IconData data(NavigationSymbol symbol, bool strong) =>
      switch (symbol) {
        NavigationSymbol.back => PhosphorIconsRegular.arrowLeft,
        NavigationSymbol.home =>
          strong ? PhosphorIconsBold.house : PhosphorIconsRegular.house,
        NavigationSymbol.patients =>
          strong ? PhosphorIconsBold.users : PhosphorIconsRegular.users,
        NavigationSymbol.appointments => strong
            ? PhosphorIconsBold.calendarBlank
            : PhosphorIconsRegular.calendarBlank,
        NavigationSymbol.screenings => strong
            ? PhosphorIconsBold.clipboardText
            : PhosphorIconsRegular.clipboardText,
        NavigationSymbol.cervical => strong
            ? PhosphorIconsBold.microscope
            : PhosphorIconsRegular.microscope,
        NavigationSymbol.anemia =>
          strong ? PhosphorIconsBold.drop : PhosphorIconsRegular.drop,
        NavigationSymbol.bloodPressure =>
          strong ? PhosphorIconsBold.heartbeat : PhosphorIconsRegular.heartbeat,
        NavigationSymbol.settings =>
          strong ? PhosphorIconsBold.gearSix : PhosphorIconsRegular.gearSix,
        NavigationSymbol.account => PhosphorIconsRegular.userCircle,
        NavigationSymbol.sidebar => PhosphorIconsRegular.sidebarSimple,
        NavigationSymbol.device => PhosphorIconsRegular.cpu,
        NavigationSymbol.chevron => PhosphorIconsRegular.caretDown,
        NavigationSymbol.close => PhosphorIconsRegular.x,
        NavigationSymbol.menu => PhosphorIconsRegular.list,
        NavigationSymbol.retry => PhosphorIconsRegular.arrowClockwise,
        NavigationSymbol.info => PhosphorIconsRegular.info,
        NavigationSymbol.signOut => PhosphorIconsRegular.signOut,
        NavigationSymbol.check => PhosphorIconsRegular.checkCircle,
        NavigationSymbol.warning => PhosphorIconsRegular.warningCircle,
        NavigationSymbol.ultrasound ||
        NavigationSymbol.ct =>
          PhosphorIconsRegular.clipboardText,
      };
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child:
          symbol == NavigationSymbol.ultrasound || symbol == NavigationSymbol.ct
              ? CustomPaint(
                  painter: _ClinicalIconPainter(
                      symbol,
                      color ??
                          IconTheme.of(context).color ??
                          NavigationTokens.secondary,
                      strong))
              : Icon(data(symbol, strong), size: size, color: color));
}

class _ClinicalIconPainter extends CustomPainter {
  const _ClinicalIconPainter(this.symbol, this.color, this.strong);
  final NavigationSymbol symbol;
  final Color color;
  final bool strong;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 2.1 : 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (symbol == NavigationSymbol.ct) {
      // CT gantry, bore and patient table, rather than a desktop monitor.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(3, 3, 18, 17), const Radius.circular(5)),
          pen);
      canvas.drawCircle(const Offset(12, 10), 4, pen);
      canvas.drawPath(
          Path()
            ..moveTo(8, 21)
            ..lineTo(9, 14)
            ..lineTo(15, 14)
            ..lineTo(16, 21),
          pen);
      canvas.drawLine(const Offset(6, 21), const Offset(18, 21), pen);
    } else {
      // Curved ultrasound transducer and a fan-shaped imaging field.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(9, 2, 6, 6), const Radius.circular(2)),
          pen);
      canvas.drawPath(
          Path()
            ..moveTo(8, 8)
            ..quadraticBezierTo(12, 11, 16, 8),
          pen);
      canvas.drawPath(
          Path()
            ..moveTo(9, 11)
            ..lineTo(5, 20)
            ..quadraticBezierTo(12, 24, 19, 20)
            ..lineTo(15, 11),
          pen);
      canvas.drawArc(
          const Rect.fromLTWH(8, 13, 8, 6), .15, math.pi - .3, false, pen);
    }
  }

  @override
  bool shouldRepaint(_ClinicalIconPainter old) =>
      old.symbol != symbol || old.color != color || old.strong != strong;
}

@immutable
class NavigationItemColors {
  const NavigationItemColors(this.background, this.foreground);
  final Color background, foreground;
  static NavigationItemColors resolve(
      {required bool selected,
      bool hovered = false,
      bool pressed = false,
      bool disabled = false}) {
    if (disabled)
      return NavigationItemColors(Colors.transparent,
          NavigationTokens.secondary.withValues(alpha: .55));
    return NavigationItemColors(
        pressed
            ? NavigationTokens.pressed
            : selected
                ? NavigationTokens.selected
                : hovered
                    ? NavigationTokens.hover
                    : Colors.transparent,
        selected ? NavigationTokens.selectedText : NavigationTokens.itemText);
  }
}

/// A single focus target with explicit semantic selection and focus outline.
class NavigationItem extends StatefulWidget {
  const NavigationItem(
      {super.key,
      required this.label,
      required this.symbol,
      required this.onTap,
      this.selected = false,
      this.collapsed = false,
      this.nested = false,
      this.trailing,
      this.subtitle,
      this.expanded,
      this.tooltip,
      this.touch = false,
      this.indicateGroup = false});
  final String label;
  final NavigationSymbol symbol;
  final VoidCallback? onTap;
  final bool selected, collapsed, nested, touch, indicateGroup;
  final Widget? trailing;
  final String? subtitle, tooltip;
  final bool? expanded;
  @override
  State<NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<NavigationItem> {
  bool hovered = false, focused = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = NavigationItemColors.resolve(
        selected: widget.selected,
        hovered: hovered,
        pressed: pressed,
        disabled: widget.onTap == null);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = math.max(
        widget.touch
            ? NavigationTokens.touchHeight
            : NavigationTokens.rowHeight,
        widget.subtitle == null
            ? textScale * (textScale > 1.3 && !widget.collapsed ? 37 : 22) + 16
            : textScale * 46 + 16);
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      enabled: widget.onTap != null,
      expanded: widget.expanded,
      child: TooltipVisibility(
        visible: widget.collapsed,
        child: Tooltip(
          message: widget.tooltip ?? widget.label,
          waitDuration: const Duration(milliseconds: 600),
          exitDuration: const Duration(milliseconds: 80),
          excludeFromSemantics: true,
          child: AnimatedContainer(
            duration: NavigationTokens.duration(context),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(
                left: widget.nested && !widget.collapsed
                    ? NavigationTokens.disclosureIndent
                    : 0),
            decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(NavigationTokens.radius),
                border: Border.all(
                    color:
                        focused ? NavigationTokens.brand : Colors.transparent,
                    width: 2)),
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onHover: (value) => setState(() => hovered = value),
                  onFocusChange: (value) => setState(() => focused = value),
                  onHighlightChanged: (value) =>
                      setState(() => pressed = value),
                  borderRadius: BorderRadius.circular(NavigationTokens.radius),
                  overlayColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  child: SizedBox(
                      height: height - 4,
                      child: ExcludeSemantics(
                        child: Row(children: [
                          SizedBox(width: widget.collapsed ? 8 : 10),
                          NavigationIcon(widget.symbol,
                              color: colors.foreground,
                              strong: widget.selected),
                          if (!widget.collapsed) ...[
                            const SizedBox(width: NavigationTokens.iconGap),
                            Expanded(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(widget.label,
                                      maxLines: textScale > 1.3 ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: NavigationTokens.itemStyle
                                          .copyWith(
                                              color: colors.foreground,
                                              fontWeight: widget.selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500)),
                                  if (widget.subtitle != null)
                                    Text(widget.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: NavigationTokens.secondaryStyle),
                                ])),
                            if (widget.trailing != null) widget.trailing!,
                            const SizedBox(width: 8),
                          ] else if (widget.indicateGroup)
                            Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: NavigationTokens.brand)),
                        ]),
                      )),
                )),
          ),
        ),
      ),
    );
  }
}

class NavigationSectionLabel extends StatelessWidget {
  const NavigationSectionLabel(this.label, {super.key, this.collapsed = false});
  final String label;
  final bool collapsed;
  @override
  Widget build(BuildContext context) => collapsed
      ? const SizedBox(height: 8)
      : Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 6),
          child:
              Text(label.toUpperCase(), style: NavigationTokens.sectionStyle));
}
