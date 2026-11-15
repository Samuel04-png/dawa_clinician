import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dawa_design_system.dart';
import 'navigation_design_system.dart';

/// Recovery for old bookmarks and incomplete patient/encounter deep links.
class MissingPatientContext extends StatelessWidget {
  const MissingPatientContext({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: NavigationTokens.canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_search_outlined,
                      size: 32, color: NavigationTokens.brand),
                  const SizedBox(height: 16),
                  Text('Choose a patient to continue',
                      style: DawaTextStyles.pageTitle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                      'This link is missing the patient or encounter reference. Open the patient record from Patients.',
                      style: DawaTextStyles.body,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.goNamed('Moms'),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Open Patients'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
