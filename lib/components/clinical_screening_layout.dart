import 'package:flutter/material.dart';
import 'dawa_design_system.dart';

/// Shared acquisition/review composition. Uses available content width so a
/// laptop with its navigation expanded gets the same readable stacked flow.
class ClinicalScreeningLayout extends StatelessWidget {
  const ClinicalScreeningLayout(
      {super.key, required this.image, required this.analysis});
  final Widget image, analysis;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        if (size.maxWidth < 920 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                image,
                const SizedBox(height: DawaTokens.space4),
                analysis,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: image),
          const SizedBox(width: DawaTokens.space4),
          Expanded(flex: 5, child: analysis),
        ]);
      });
}
