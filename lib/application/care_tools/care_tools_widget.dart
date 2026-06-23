import '/application/cacx/cacx_widget.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

class CareToolsWidget extends StatefulWidget {
  const CareToolsWidget({super.key});

  static String routeName = 'CareTools';
  static String routePath = '/care-tools';

  @override
  State<CareToolsWidget> createState() => _CareToolsWidgetState();
}

class _CareToolsWidgetState extends State<CareToolsWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  static const _urgentBannerHiddenKey = 'care_tools_urgent_banner_hidden_v1';
  bool _hideUrgentBanner = false;

  @override
  void initState() {
    super.initState();
    FFAppState().selectedPage = 'Care Tools';
    _loadUrgentBannerPreference();
  }

  Future<void> _loadUrgentBannerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hideUrgentBanner = prefs.getBool(_urgentBannerHiddenKey) ?? false;
    });
  }

  Future<void> _hideUrgentBannerPersistently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_urgentBannerHiddenKey, true);
    if (!mounted) return;
    setState(() {
      _hideUrgentBanner = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final showDesktopSidebar = pageConstraints.maxWidth >= 768.0;

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: showDesktopSidebar ? null : _buildMobileDrawer(),
          appBar: showDesktopSidebar ? null : _buildMobileAppBar(),
          body: SafeArea(
            top: true,
            child: Row(
              children: [
                if (showDesktopSidebar) _buildDesktopSidebar(),
                Expanded(child: _buildContent(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: DawaTokens.surface,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Open navigation',
        icon: const Icon(Icons.menu_rounded, color: DawaTokens.brandPrimary),
        onPressed: () => scaffoldKey.currentState?.openDrawer(),
      ),
      title: AppbarNavWidget(),
      elevation: 0,
      titleSpacing: 0,
    );
  }

  Widget _buildMobileDrawer() {
    return const SizedBox(
      width: 280,
      child: Drawer(
        elevation: 16,
        child: SmallSideNavWidget(),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      key: const ValueKey('care-tools-desktop-sidebar'),
      width: 240,
      decoration: const BoxDecoration(
        color: DawaTokens.surface,
        border: Border(
          right: BorderSide(color: DawaTokens.border, width: 1),
        ),
      ),
      child: const SmallSideNavWidget(),
    );
  }

  Widget _buildContent(BuildContext context) {
    final tools = getQuickAccessToolSummaries();
    final urgentTotal =
        tools.fold<int>(0, (sum, tool) => sum + tool.needsReview);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 560 ? 16.0 : 24.0;
        final contentWidth =
            constraints.maxWidth > 1200.0 ? 1200.0 : constraints.maxWidth;
        final columns = contentWidth >= 900.0 ? 2 : 1;
        final toolCardWidth =
            columns == 1 ? contentWidth : (contentWidth - 16.0) / 2;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Care Tools', style: DawaTextStyles.pageTitle),
                  const SizedBox(height: 6),
                  Text(
                    'Clinical modules - tap any tool to open its workspace.',
                    style: DawaTextStyles.secondary,
                  ),
                  const SizedBox(height: 20),
                  if (urgentTotal > 0 && !_hideUrgentBanner)
                    _UrgentBanner(
                      urgentTotal: urgentTotal,
                      onDismiss: _hideUrgentBannerPersistently,
                    ),
                  if (urgentTotal > 0 && !_hideUrgentBanner)
                    const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: tools
                        .map(
                          (tool) => SizedBox(
                            width: toolCardWidth,
                            child: _ToolStatusCard(
                              summary: tool,
                              onOpen: () => _openTool(context, tool),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openTool(BuildContext context, QuickAccessToolSummary summary) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => quickAccessServiceWidget(summary.type),
      ),
    );
  }
}

class _UrgentBanner extends StatefulWidget {
  const _UrgentBanner({
    required this.urgentTotal,
    required this.onDismiss,
  });

  final int urgentTotal;
  final VoidCallback onDismiss;

  @override
  State<_UrgentBanner> createState() => _UrgentBannerState();
}

class _UrgentBannerState extends State<_UrgentBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DawaTokens.statusWarningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DawaTokens.statusWarning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: DawaTokens.statusWarning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.urgentTotal} items need your attention - review flagged tool results and overdue follow-ups.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusWarningText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _hidden = true);
              widget.onDismiss();
            },
            child: const Text('Hide for now'),
          ),
        ],
      ),
    );
  }
}

class _ToolStatusCard extends StatelessWidget {
  const _ToolStatusCard({
    required this.summary,
    required this.onOpen,
  });

  final QuickAccessToolSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final badge = _badgeSpec(summary);

    return DawaCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: summary.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(summary.icon, color: summary.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.title, style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      summary.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DawaTextStyles.secondary.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge.label,
                  style: GoogleFonts.dmSans(
                    color: badge.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: DawaTokens.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _ToolStat(
                    value: summary.records.toString(),
                    label: summary.recordLabel,
                  ),
                  _ToolStat(
                    value: summary.completed.toString(),
                    label: 'Completed',
                    addDivider: true,
                  ),
                  _ToolStat(
                    value: summary.needsReview.toString(),
                    label: 'Needs review',
                    addDivider: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DawaTokens.surfaceTertiary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOST RECENT',
                  style: DawaTextStyles.label.copyWith(
                    color: DawaTokens.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${summary.recentPatient} - ${summary.recentResult} - ${quickAccessFormatDate(summary.recentDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: DawaTokens.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Open ${summary.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: DawaTokens.brandPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                color: DawaTokens.brandPrimary,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  _ToolBadgeSpec _badgeSpec(QuickAccessToolSummary summary) {
    if (summary.needsReview == 0) {
      return const _ToolBadgeSpec(
        label: 'All reviewed',
        background: DawaTokens.statusSuccessBg,
        foreground: DawaTokens.statusSuccessText,
      );
    }
    if (summary.type == QuickAccessServiceType.cervicalCancer) {
      return _ToolBadgeSpec(
        label: '${summary.needsReview} urgent',
        background: DawaTokens.statusDangerBg,
        foreground: DawaTokens.statusDanger,
      );
    }
    return _ToolBadgeSpec(
      label: '${summary.needsReview} flagged',
      background: DawaTokens.statusWarningBg,
      foreground: DawaTokens.statusWarning,
    );
  }
}

class _ToolStat extends StatelessWidget {
  const _ToolStat({
    required this.value,
    required this.label,
    this.addDivider = false,
  });

  final String value;
  final String label;
  final bool addDivider;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: addDivider
              ? const Border(left: BorderSide(color: DawaTokens.border))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: DawaTextStyles.statNumber.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBadgeSpec {
  const _ToolBadgeSpec({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
