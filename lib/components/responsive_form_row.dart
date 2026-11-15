import 'package:flutter/material.dart';

/// Reflows legacy form labels and actions when their row cannot remain legible.
/// Flexible fields retain the full available width in the stacked layout.
class ResponsiveFormRow extends StatelessWidget {
  const ResponsiveFormRow(
      {super.key,
      required this.children,
      this.mainAxisSize = MainAxisSize.max,
      this.mainAxisAlignment = MainAxisAlignment.start,
      this.crossAxisAlignment = CrossAxisAlignment.center});

  final List<Widget> children;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        if (!size.hasBoundedWidth ||
            size.maxWidth >= 600 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21) {
          return Row(
              mainAxisSize: mainAxisSize,
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              children: children);
        }
        return Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: mainAxisAlignment == MainAxisAlignment.end
                ? WrapAlignment.end
                : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children
                .map((child) => child is Flexible
                    ? SizedBox(width: size.maxWidth, child: child.child)
                    : child)
                .toList());
      });
}
