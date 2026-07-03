import 'package:flutter/material.dart';

import '/application/shared/clinical_tools/clinical_tool_models.dart';
import '/components/dawa_design_system.dart';

class HemonixService {
  const HemonixService();

  ClinicalToolConfig get config {
    return ClinicalToolConfig(
      key: 'hemonix',
      title: 'HemoNix',
      description:
          'Monitor haemoglobin results, anaemia risk, and treatment follow-up.',
      recordName: 'Hb Record',
      resultsLabel: 'Hb Results',
      recordLabel: 'Records',
      icon: Icons.bloodtype_outlined,
      color: DawaTokens.brandPrimary,
      recordBadgeFor: (record) => ClinicalToolBadge(
        status: record.needsReview ? 'missing_data' : 'normal',
        label: record.result,
      ),
      followUpColorFor: (record) => record.needsReview
          ? DawaTokens.statusDanger
          : DawaTokens.brandPrimary,
      actions: const [
        ClinicalToolAction(
          title: 'Add Hb Record',
          description: 'Create a new haemoglobin record.',
          icon: Icons.add_circle_outline,
          color: DawaTokens.brandPrimary,
        ),
        ClinicalToolAction(
          title: 'View Patient Records',
          description: 'Review patient-linked records and recent activity.',
          icon: Icons.people_outline,
          color: DawaTokens.brandPrimary,
        ),
        ClinicalToolAction(
          title: 'View Hb Results',
          description: 'Open searchable and filterable result cards.',
          icon: Icons.fact_check_outlined,
          color: DawaTokens.brandPrimary,
        ),
        ClinicalToolAction(
          title: 'Search Results',
          description:
              'Search matching patients, IDs, record IDs, notes, and AI text.',
          icon: Icons.search,
          color: DawaTokens.brandPrimary,
        ),
      ],
    );
  }
}
