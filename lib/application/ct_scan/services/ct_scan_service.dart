import 'package:flutter/material.dart';

import '/application/shared/clinical_tools/clinical_tool_models.dart';
import '/components/dawa_design_system.dart';

class CtScanService {
  const CtScanService();

  ClinicalToolConfig get config {
    return ClinicalToolConfig(
      key: 'ct-scan',
      title: 'CT Scan',
      description:
          'Organize CT imaging records, radiology results, and urgent review tasks.',
      recordName: 'CT Record',
      resultsLabel: 'CT Results',
      recordLabel: 'Records',
      icon: Icons.desktop_windows_outlined,
      color: DawaTokens.brandPrimary,
      followUpColorFor: (record) => record.needsReview
          ? DawaTokens.statusWarning
          : DawaTokens.brandPrimary,
      actions: const [
        ClinicalToolAction(
          title: 'Add CT Record',
          description: 'Create a new CT scan record.',
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
          title: 'View CT Results',
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
