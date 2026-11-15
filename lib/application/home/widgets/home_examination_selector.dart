import 'package:flutter/material.dart';
import '/components/navigation_design_system.dart';
import '/components/clinical_features.dart';
import 'home_dashboard_content.dart';

class HomeExaminationSelector extends StatelessWidget {
  const HomeExaminationSelector({super.key, required this.onSelected});
  final ValueChanged<String> onSelected;
  static const tools = [
    (
      'Cervical Cancer',
      'CervicalCancer',
      'VIA screening',
      NavigationSymbol.cervical
    ),
    ('Ultrasound', 'Ultrasound', 'Scan workflows', NavigationSymbol.ultrasound),
    ('Anemia', 'HemoNix', 'HemoNix screening', NavigationSymbol.anemia),
    if (ClinicalFeatures.ctScan)
      ('CT Scan', 'CtScan', 'Imaging records and results', NavigationSymbol.ct),
    (
      'BP Monitor',
      'BpMonitor',
      'Blood pressure recording',
      NavigationSymbol.bloodPressure
    ),
  ];
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New examination'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text(
                      'Choose a tool, then confirm the patient in its workflow before beginning.',
                      style: DashboardStyles.secondary),
                  const SizedBox(height: 12),
                  for (final tool in tools)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: NavigationIcon(tool.$4,
                          color: NavigationTokens.brand),
                      title: Text(tool.$1, style: DashboardStyles.body),
                      subtitle: Text(tool.$3, style: DashboardStyles.secondary),
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(tool.$2);
                      },
                    ),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      );
}
