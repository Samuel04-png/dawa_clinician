import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/components/dawa_design_system.dart';
import 'clinical_tool_controller.dart';
import 'clinical_tool_models.dart';

class ClinicalToolDashboard extends StatefulWidget {
  const ClinicalToolDashboard({
    super.key,
    required this.controller,
  });

  final ClinicalToolController controller;

  @override
  State<ClinicalToolDashboard> createState() => _ClinicalToolDashboardState();
}

class _ClinicalToolDashboardState extends State<ClinicalToolDashboard> {
  final TextEditingController _searchController = TextEditingController();

  ClinicalToolController get controller => widget.controller;
  ClinicalToolConfig get config => controller.config;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_searchController.text != controller.searchQuery) {
      _searchController.text = controller.searchQuery;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: isMobile
            ? Column(
                children: [
                  _buildMobileHeader(),
                  Expanded(child: _buildContent()),
                  _buildMobileNav(),
                ],
              )
            : Row(
                children: [
                  _buildSidebar(),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildContent()),
                ],
              ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      color: DawaTokens.surface,
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to tools',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: config.color,
          ),
          _moduleIcon(size: 36, iconSize: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Clinical tool',
                  style: DawaTextStyles.secondary.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      key: ValueKey('${config.key}-sidebar'),
      width: 240,
      color: DawaTokens.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                _moduleIcon(size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DawaTextStyles.cardTitle.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Clinical tool',
                        style: DawaTextStyles.secondary.copyWith(
                          color: DawaTokens.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to tools'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: config.color,
                  side: BorderSide(color: config.color.withOpacity(0.28)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: DawaTokens.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _sideNavItem(
                  Icons.dashboard_outlined,
                  'Dashboard',
                  ClinicalToolDashboardTab.overview,
                ),
                _sideNavItem(
                  Icons.people_outline,
                  'Patient Records',
                  ClinicalToolDashboardTab.records,
                ),
                _sideNavItem(
                  Icons.fact_check_outlined,
                  config.resultsLabel,
                  ClinicalToolDashboardTab.results,
                ),
                _sideNavItem(
                  Icons.search,
                  'Search Results',
                  ClinicalToolDashboardTab.search,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleIcon({required double size, double iconSize = 22}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
      ),
      child: Icon(config.icon, color: config.color, size: iconSize),
    );
  }

  Widget _sideNavItem(
    IconData icon,
    String label,
    ClinicalToolDashboardTab tab,
  ) {
    final selected = controller.activeTab == tab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          onTap: () => controller.setTab(tab),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: selected ? DawaTokens.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            child: Row(
              children: [
                const SizedBox(width: 15),
                Icon(
                  icon,
                  color:
                      selected ? DawaTokens.textInverse : DawaTokens.textMuted,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? DawaTokens.textInverse
                          : DawaTokens.textSecondary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNav() {
    final items = [
      (Icons.dashboard_outlined, 'Home', ClinicalToolDashboardTab.overview),
      (Icons.people_outline, 'Records', ClinicalToolDashboardTab.records),
      (Icons.fact_check_outlined, 'Results', ClinicalToolDashboardTab.results),
      (Icons.search, 'Search', ClinicalToolDashboardTab.search),
    ];

    return Container(
      key: ValueKey('${config.key}-mobile-nav'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => controller.setTab(item.$3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$1,
                      color: controller.activeTab == item.$3
                          ? DawaTokens.brandPrimary
                          : Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: controller.activeTab == item.$3
                            ? DawaTokens.brandPrimary
                            : Colors.grey,
                        fontSize: 11,
                        fontWeight: controller.activeTab == item.$3
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (controller.activeTab) {
      ClinicalToolDashboardTab.overview => _buildOverview(),
      ClinicalToolDashboardTab.records => _buildRecords(),
      ClinicalToolDashboardTab.results => _buildResults(),
      ClinicalToolDashboardTab.search => _buildResults(focusSearch: true),
    };
  }

  Widget _buildOverview() {
    final records = controller.records;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${config.title} Dashboard',
                style: DawaTextStyles.pageTitle.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, ${_clinicianName()}. ${config.description}',
                style: DawaTextStyles.secondary.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildActionGrid(),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 640;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summaryTile(
                        'Total records',
                        records.length.toString(),
                        Icons.folder_outlined,
                        config.color,
                        narrow,
                      ),
                      _summaryTile(
                        'Completed',
                        controller.completedCount.toString(),
                        Icons.check_circle_outline,
                        DawaTokens.statusSuccess,
                        narrow,
                      ),
                      _summaryTile(
                        'Needs review',
                        controller.reviewCount.toString(),
                        Icons.priority_high,
                        DawaTokens.statusWarning,
                        narrow,
                      ),
                      _summaryTile(
                        'Follow-ups',
                        controller.reviewCount.toString(),
                        Icons.event_available,
                        DawaTokens.brandPrimary,
                        narrow,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Recent activity', style: DawaTextStyles.cardTitle),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        controller.setTab(ClinicalToolDashboardTab.results),
                    child: const Text('View results'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                _emptyPanel(
                  icon: Icons.assignment_outlined,
                  title: 'No results yet',
                  message:
                      '${config.recordName} entries will appear here after the first record is added.',
                )
              else
                Column(
                  children: records
                      .take(3)
                      .map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _resultCard(record),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final itemWidth =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;
        final actions = config.actions;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (actions.isNotEmpty)
              _quickAction(
                actions[0],
                itemWidth,
                controller.prepareNewRecord,
              ),
            if (actions.length > 1)
              _quickAction(
                actions[1],
                itemWidth,
                () => controller.setTab(ClinicalToolDashboardTab.records),
              ),
            if (actions.length > 2)
              _quickAction(
                actions[2],
                itemWidth,
                () => controller.setTab(ClinicalToolDashboardTab.results),
              ),
            if (actions.length > 3)
              _quickAction(
                actions[3],
                itemWidth,
                () => controller.setTab(ClinicalToolDashboardTab.search),
              ),
          ],
        );
      },
    );
  }

  Widget _quickAction(
    ClinicalToolAction action,
    double width,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 148),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: action.color.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(action.icon, color: action.color, size: 28),
                const SizedBox(height: 14),
                Text(action.title, style: DawaTextStyles.cardTitle),
                const SizedBox(height: 8),
                Text(
                  action.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(
    String label,
    String value,
    IconData icon,
    Color color,
    bool narrow,
  ) {
    return DawaStatCard(
      width: narrow ? double.infinity : 190,
      label: label,
      value: value,
      icon: icon,
      color: color,
      accentBorder: true,
    );
  }

  Widget _buildRecords() {
    final records = controller.records;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${config.title} Patient Records',
                style: DawaTextStyles.pageTitle,
              ),
              const SizedBox(height: 8),
              Text(
                controller.selectedPatient == null
                    ? 'Patient-linked ${config.recordName.toLowerCase()} entries are ready for review.'
                    : 'Ready to add ${config.recordName.toLowerCase()} for ${controller.selectedPatient}.',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              if (records.isEmpty)
                _emptyPanel(
                  icon: Icons.assignment_outlined,
                  title: 'No results yet',
                  message:
                      '${config.recordName} entries will appear here after the first record is added.',
                )
              else
                Column(
                  children: records
                      .map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _resultCard(record),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults({bool focusSearch = false}) {
    final records = controller.filteredRecords;
    final allRecords = controller.records;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(config.resultsLabel, style: DawaTextStyles.pageTitle),
              const SizedBox(height: 6),
              Text(
                'Overview of ${config.recordName.toLowerCase()} results for ${config.title}.',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 640;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summaryTile(
                        'All results',
                        allRecords.length.toString(),
                        Icons.assignment,
                        config.color,
                        narrow,
                      ),
                      _summaryTile(
                        'Completed',
                        controller.completedCount.toString(),
                        Icons.check_circle,
                        DawaTokens.statusSuccess,
                        narrow,
                      ),
                      _summaryTile(
                        'Needs review',
                        controller.reviewCount.toString(),
                        Icons.priority_high,
                        DawaTokens.statusWarning,
                        narrow,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              TextField(
                key: ValueKey('${config.key}-results-search'),
                autofocus: focusSearch,
                controller: _searchController,
                onChanged: controller.setSearch,
                decoration: InputDecoration(
                  hintText:
                      'Search patient, ID, record, result, notes, analysis, or confidence',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controller.searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: controller.clearSearchAndFilters,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('All results', ClinicalToolResultsFilter.all),
                  _filterChip('Completed', ClinicalToolResultsFilter.completed),
                  _filterChip(
                    'Needs review',
                    ClinicalToolResultsFilter.needsReview,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? _emptyResults(allRecords.isEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _resultCard(records[index]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, ClinicalToolResultsFilter filter) {
    final selected = controller.resultsFilter == filter;
    return ChoiceChip(
      key: ValueKey('${config.key}-filter-${filter.name}'),
      label: Text(label),
      selected: selected,
      selectedColor: config.color.withOpacity(0.12),
      labelStyle: TextStyle(
        color: selected ? config.color : Colors.grey,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => controller.setFilter(filter),
    );
  }

  Widget _resultCard(ClinicalToolRecord record) {
    final followUpColor =
        config.followUpColorFor?.call(record) ?? _defaultActionColor(record);

    return DawaCard(
      urgent: record.needsReview,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DawaAvatarCircle(
                name: record.patientName,
                moduleColor: config.color,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(record.patientName,
                            style: DawaTextStyles.cardTitle),
                        _recordBadge(record),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient ${record.patientId} - Record ${record.recordId}',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DawaStatusBadge(
                status: record.needsReview ? 'needs_review' : 'completed',
                label: record.needsReview ? 'Needs review' : 'Completed',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _recordField(
                Icons.calendar_today_outlined,
                'Date',
                clinicalToolFormatDate(record.date),
              ),
              _recordField(Icons.assignment_outlined, 'Result', record.result),
              _recordField(Icons.notes_outlined, 'Notes', record.notes),
            ],
          ),
          const SizedBox(height: 10),
          DawaAIConfidenceBar(analysis: record.analysis),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.openPatient(record),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Open patient'),
              ),
              ElevatedButton.icon(
                onPressed: () => controller.planFollowUp(record),
                icon: Icon(
                  record.needsReview
                      ? Icons.event_available
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(
                  record.needsReview ? 'Plan follow-up' : 'Routine follow-up',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: followUpColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recordBadge(ClinicalToolRecord record) {
    final badge = config.recordBadgeFor?.call(record);
    if (badge == null) return const SizedBox.shrink();
    return DawaStatusBadge(status: badge.status, label: badge.label);
  }

  Widget _recordField(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: DawaTokens.textMuted),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DawaTextStyles.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyResults(bool noRecords) {
    final hasFilters = controller.searchQuery.trim().isNotEmpty ||
        controller.resultsFilter != ClinicalToolResultsFilter.all;
    return Center(
      child: _emptyPanel(
        icon: hasFilters ? Icons.search_off : Icons.assignment_outlined,
        title: noRecords ? 'No results yet' : 'No matching results',
        message: hasFilters
            ? 'Clear filters/search or try a different patient, record ID, result, note, or analysis term.'
            : '${config.recordName} results will appear here once records are available.',
        action: hasFilters
            ? TextButton.icon(
                onPressed: controller.clearSearchAndFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters/search'),
              )
            : null,
      ),
    );
  }

  Widget _emptyPanel({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: config.color),
          const SizedBox(height: 14),
          Text(
            title,
            style: DawaTextStyles.cardTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textMuted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }

  Color _defaultActionColor(ClinicalToolRecord record) {
    return record.needsReview ? DawaTokens.statusWarning : config.color;
  }

  String _clinicianName() {
    final displayName = currentUserDisplayName.trim();
    if (displayName.isNotEmpty) return displayName;

    final email = currentUserEmail.trim();
    if (email.isNotEmpty) return email;

    return 'Clinician';
  }
}
