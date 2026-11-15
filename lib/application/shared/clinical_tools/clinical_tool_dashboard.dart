import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '/components/clinical_page_intro.dart';
import '/components/clinical_tab_bar.dart';
import '/components/clinical_workspace_components.dart' as workspace;
import '/components/dawa_design_system.dart';
import '/components/navigation_design_system.dart';
import 'clinical_tool_controller.dart';
import 'clinical_tool_models.dart';

class ClinicalToolDashboard extends StatefulWidget {
  const ClinicalToolDashboard({
    super.key,
    required this.controller,
    this.demonstrationMode = false,
  });

  final ClinicalToolController controller;
  final bool demonstrationMode;

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
    if (widget.demonstrationMode) return _buildSampleWorkspace();
    return Scaffold(
      backgroundColor: NavigationTokens.canvas,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final scrollingIntro = constraints.maxHeight < 520;
          return Column(
            children: [
              SizedBox(
                  child: scrollingIntro
                      ? const SizedBox.shrink()
                      : _buildPageIntro()),
              _buildTabBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _transitionDuration(context),
                  child: KeyedSubtree(
                    key: ValueKey(controller.activeTab),
                    child: _buildContent(scrollingIntro: scrollingIntro),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSampleWorkspace() {
    final overview = controller.activeTab == ClinicalToolDashboardTab.overview;
    final recordsTab = controller.activeTab == ClinicalToolDashboardTab.records;
    final records = overview ? controller.records : controller.filteredRecords;
    return Material(
      color: NavigationTokens.canvas,
      child: Column(children: [
        _buildTabBar(),
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('ct-scan-results'),
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: DawaTokens.workspaceMaxWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      workspace.ClinicalPageHeader(
                        subtitle: 'Review CT records and radiology reports.',
                        action: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NavigationTokens.brand,
                            side: const BorderSide(
                                color: DawaTokens.borderStrong),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            controller.clearSearchAndFilters();
                            controller.setTab(ClinicalToolDashboardTab.records);
                          },
                          icon:
                              const Icon(Icons.folder_open_outlined, size: 18),
                          label: const Text('View sample records'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DawaCard(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const workspace.ClinicalStatusChip(
                                  label: 'Sample data'),
                              Text(
                                  'Clinical record creation and saving are not connected.',
                                  style: DawaTextStyles.secondary),
                            ]),
                      ),
                      const SizedBox(height: 16),
                      _sampleSummary(),
                      const SizedBox(height: 24),
                      Text(
                          overview
                              ? 'Recent CT records'
                              : recordsTab
                                  ? 'Patient records'
                                  : config.resultsLabel,
                          style: DawaTextStyles.cardTitle),
                      const SizedBox(height: 12),
                      if (!overview) ...[
                        TextField(
                          key: ValueKey(recordsTab
                              ? 'ct-scan-records-search'
                              : 'ct-scan-results-search'),
                          controller: _searchController,
                          autofocus: controller.activeTab ==
                              ClinicalToolDashboardTab.search,
                          onChanged: controller.setSearch,
                          decoration: InputDecoration(
                            labelText: 'Search records',
                            hintText: 'Patient, reference or report',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: controller.searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear record search',
                                    onPressed: controller.clearSearchAndFilters,
                                    icon: const Icon(Icons.close, size: 18)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _filterChip(
                              'All results', ClinicalToolResultsFilter.all),
                          _filterChip(
                              'Completed', ClinicalToolResultsFilter.completed),
                          _filterChip('Needs review',
                              ClinicalToolResultsFilter.needsReview),
                        ]),
                        const SizedBox(height: 16),
                        Text(
                            '${records.length} of ${controller.records.length} records',
                            style: DawaTextStyles.secondary),
                        const SizedBox(height: 8),
                      ],
                      if (records.isEmpty)
                        _emptyResults(controller.records.isEmpty)
                      else
                        DawaCard(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            for (var i = 0; i < records.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, color: DawaTokens.border),
                              _sampleRecordRow(records[i]),
                            ],
                          ]),
                        ),
                    ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sampleSummary() => LayoutBuilder(builder: (context, constraints) {
        final stack = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final items = [
          _sampleMetric('Total records', controller.records.length,
              'Sample records', ClinicalToolResultsFilter.all),
          _sampleMetric(
              'Completed',
              controller.completedCount,
              'of ${controller.records.length} records',
              ClinicalToolResultsFilter.completed),
          _sampleMetric(
              'Needs review',
              controller.reviewCount,
              'of ${controller.records.length} records',
              ClinicalToolResultsFilter.needsReview),
        ];
        return DawaCard(
            padding: EdgeInsets.zero,
            child: stack
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        items.map((item) => Expanded(child: item)).toList()));
      });

  Widget _sampleMetric(String label, int value, String contextLabel,
          ClinicalToolResultsFilter filter) =>
      InkWell(
        onTap: () {
          controller.clearSearchAndFilters();
          controller.setFilter(filter);
          controller.setTab(ClinicalToolDashboardTab.results);
        },
        child: Semantics(
            button: true,
            label: 'View $label',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: DawaTextStyles.secondary),
                    const SizedBox(height: 4),
                    Text('$value', style: DawaTextStyles.pageTitle),
                    Text(contextLabel, style: DawaTextStyles.secondary),
                  ]),
            )),
      );

  Widget _sampleRecordRow(ClinicalToolRecord record) =>
      LayoutBuilder(builder: (context, constraints) {
        final stack = constraints.maxWidth < 660 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final identity =
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DawaAvatarCircle(
              name: record.patientName, moduleColor: config.color, size: 36),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(record.patientName, style: DawaTextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(
                    '${clinicalToolFormatDate(record.date)} • ${record.recordId}',
                    style: DawaTextStyles.secondary),
              ])),
        ]);
        final outcome =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          workspace.ClinicalStatusChip(
              label: record.needsReview ? 'Needs review' : 'Completed',
              tone: record.needsReview
                  ? workspace.ClinicalStatusTone.warning
                  : workspace.ClinicalStatusTone.neutral),
          const SizedBox(height: 6),
          Text(record.result, style: DawaTextStyles.secondary),
        ]);
        final action = TextButton.icon(
          onPressed: () => _showRecordDetail(record),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('View sample record'),
        );
        return InkWell(
          onTap: () => _showRecordDetail(record),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: stack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          identity,
                          const SizedBox(height: 12),
                          outcome,
                          const SizedBox(height: 8),
                          action
                        ])
                  : Row(children: [
                      Expanded(flex: 3, child: identity),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: outcome),
                      const SizedBox(width: 12),
                      action
                    ])),
        );
      });

  Duration _transitionDuration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150);

  Widget _buildPageIntro() {
    final primary = config.actions.isNotEmpty ? config.actions.first : null;
    return ClinicalPageIntro(
      subtitle: widget.demonstrationMode
          ? 'Demonstration data. Clinical record creation and saving are not connected.'
          : config.description,
      status: widget.demonstrationMode
          ? const ClinicalStatusChip(
              label: 'Sample data', color: NavigationTokens.warning)
          : null,
      action: primary == null
          ? null
          : FilledButton.icon(
              onPressed: widget.demonstrationMode
                  ? () {
                      controller.clearSearchAndFilters();
                      controller.setTab(ClinicalToolDashboardTab.records);
                    }
                  : controller.prepareNewRecord,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(widget.demonstrationMode
                  ? 'View sample records'
                  : primary.title),
              style: FilledButton.styleFrom(
                  backgroundColor: NavigationTokens.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
    );
  }

  Widget _buildTabBar() {
    return ClinicalTabBar(
      tabs: [
        ClinicalTab('Overview', icon: PhosphorIconsRegular.squaresFour),
        ClinicalTab('Records', icon: PhosphorIconsRegular.usersThree),
        ClinicalTab(config.resultsLabel, icon: PhosphorIconsRegular.listChecks),
        ClinicalTab('Search', icon: PhosphorIconsRegular.magnifyingGlass),
      ],
      activeIndex: controller.activeTab.index,
      onSelected: (i) => controller.setTab(ClinicalToolDashboardTab.values[i]),
    );
  }

  Widget _buildContent({bool scrollingIntro = false}) {
    return switch (controller.activeTab) {
      ClinicalToolDashboardTab.overview =>
        _buildOverview(scrollingIntro: scrollingIntro),
      ClinicalToolDashboardTab.records =>
        _buildRecords(scrollingIntro: scrollingIntro),
      ClinicalToolDashboardTab.results =>
        _buildResults(scrollingIntro: scrollingIntro),
      ClinicalToolDashboardTab.search =>
        _buildResults(focusSearch: true, scrollingIntro: scrollingIntro),
    };
  }

  Widget _buildOverview({bool scrollingIntro = false}) {
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
              SizedBox(
                  child: scrollingIntro
                      ? _buildPageIntro()
                      : const SizedBox.shrink()),
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
                      if (!widget.demonstrationMode)
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
              Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Recent activity', style: DawaTextStyles.cardTitle),
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

  Widget _buildRecords({bool scrollingIntro = false}) {
    final records = controller.filteredRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  child: scrollingIntro
                      ? _buildPageIntro()
                      : const SizedBox.shrink()),
              Text(
                widget.demonstrationMode
                    ? 'Sample patient records'
                    : '${config.title} Patient Records',
                style: DawaTextStyles.pageTitle,
              ),
              const SizedBox(height: 8),
              Text(
                controller.searchQuery.trim().isEmpty
                    ? (widget.demonstrationMode
                        ? 'Explore sample records. No clinical changes are saved.'
                        : 'Patient-linked ${config.recordName.toLowerCase()} entries are ready for review.')
                    : 'Showing matching records. Clear the search to see all records.',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                  key: ValueKey('${config.key}-records-search'),
                  controller: _searchController,
                  onChanged: controller.setSearch,
                  decoration: InputDecoration(
                      labelText: 'Search records',
                      hintText: 'Patient, ID or record',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear record search',
                              onPressed: controller.clearSearchAndFilters,
                              icon: const Icon(Icons.clear)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              if (controller.resultsFilter != ClinicalToolResultsFilter.all)
                TextButton(
                    onPressed: controller.clearSearchAndFilters,
                    child: const Text('Clear filters')),
              const SizedBox(height: 20),
              if (records.isEmpty)
                _emptyResults(controller.records.isEmpty)
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

  Widget _buildResults(
      {bool focusSearch = false, bool scrollingIntro = false}) {
    final records = controller.filteredRecords;
    final allRecords = controller.records;

    return CustomScrollView(
      key: PageStorageKey('${config.key}-results'),
      slivers: [
        if (scrollingIntro)
          SliverToBoxAdapter(
              key: const ValueKey('scrolling-intro'), child: _buildPageIntro()),
        SliverToBoxAdapter(
            key: const ValueKey('results-controls'),
            child: Container(
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
                      _filterChip(
                          'Completed', ClinicalToolResultsFilter.completed),
                      _filterChip(
                        'Needs review',
                        ClinicalToolResultsFilter.needsReview,
                      ),
                    ],
                  ),
                ],
              ),
            )),
        if (records.isEmpty)
          SliverFillRemaining(
              hasScrollBody: false, child: _emptyResults(allRecords.isEmpty))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _resultCard(records[index])))),
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
        color: selected ? config.color : DawaTokens.textSecondary,
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
            ],
          ),
          const SizedBox(height: 8),
          DawaStatusBadge(
              status: record.needsReview ? 'needs_review' : 'completed',
              label: record.needsReview ? 'Needs review' : 'Completed'),
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
          if (config.showAnalysis)
            DawaAIConfidenceBar(analysis: record.analysis)
          else
            _recordField(
                Icons.info_outline, 'Sample workflow note', record.analysis),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: widget.demonstrationMode
                    ? () => _showRecordDetail(record)
                    : () => controller.openPatient(record),
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(widget.demonstrationMode
                    ? 'View sample record'
                    : 'Open patient'),
              ),
              ElevatedButton.icon(
                onPressed: widget.demonstrationMode
                    ? () => _showRecordDetail(record)
                    : () => controller.planFollowUp(record),
                icon: Icon(
                  record.needsReview
                      ? Icons.event_available
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(
                  widget.demonstrationMode
                      ? 'Open sample result'
                      : record.needsReview
                          ? 'Plan follow-up'
                          : 'Routine follow-up',
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

  Future<void> _showRecordDetail(ClinicalToolRecord record) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Sample CT record ${record.recordId}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DawaStatusBadge(
                        status: 'active', label: 'Sample data'),
                    const SizedBox(height: 14),
                    Text(record.patientName, style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                        'Patient reference ${record.patientId} • ${clinicalToolFormatDate(record.date)}',
                        style: DawaTextStyles.secondary),
                    const SizedBox(height: 16),
                    Text('Study result', style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(record.result),
                    const SizedBox(height: 14),
                    Text('Radiology report', style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(record.notes),
                    const SizedBox(height: 14),
                    Text('Workflow information',
                        style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(record.analysis),
                    const SizedBox(height: 16),
                    Text(
                        'Demonstration data only. Clinical saving and radiology review actions are not connected.',
                        style: DawaTextStyles.secondary),
                  ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );

  Widget _recordField(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        children: [
          Icon(icon, size: 15, color: DawaTokens.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$label: $value',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.textPrimary,
              ),
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
}
