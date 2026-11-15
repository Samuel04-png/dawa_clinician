import '/components/appbar_nav/appbar_nav_widget.dart';
import '/services/edge_device/edge_device_manager.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '/components/clinician_bottom_nav/clinician_bottom_nav_widget.dart';
import '/components/navigation_design_system.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';

/// Shared geometry for the Home workspace and patient registry.
class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell(
      {super.key,
      required this.currentPage,
      required this.headerBuilder,
      required this.slivers,
      required this.onRefresh,
      this.notifications,
      this.deviceManager});
  final String currentPage;
  final Widget? notifications;
  final EdgeDeviceManager? deviceManager;
  final Widget Function(VoidCallback openNavigation) headerBuilder;
  final List<Widget> slivers;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, page) {
        final desktop = page.maxWidth >= NavigationTokens.desktopBreakpoint;
        return Scaffold(
          backgroundColor: NavigationTokens.canvas,
          drawer: desktop
              ? null
              : const Drawer(
                  width: NavigationTokens.expandedWidth,
                  child: SmallSideNavWidget()),
          bottomNavigationBar: desktop
              ? null
              : ClinicianBottomNavWidget(currentPage: currentPage),
          body: SafeArea(
              child: Row(children: [
            if (desktop)
              SmallSideNavWidget(
                  key:
                      ValueKey('${currentPage.toLowerCase()}-desktop-sidebar')),
            Expanded(
                child: Column(children: [
              Material(
                  color: Colors.white,
                  child: DecoratedBox(
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: NavigationTokens.border))),
                      child: Row(children: [
                        if (!desktop)
                          Builder(
                              builder: (context) => IconButton(
                                  tooltip: 'Open navigation',
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const NavigationIcon(
                                      NavigationSymbol.menu))),
                        Expanded(
                            child: AppbarNavWidget(
                                showTitle: false,
                                notifications: notifications,
                                deviceManager: deviceManager)),
                      ]))),
              Expanded(
                  child: Builder(
                      builder: (scaffoldContext) =>
                          LayoutBuilder(builder: (context, content) {
                            final padding =
                                content.maxWidth < 700 ? 16.0 : 28.0;
                            final gutter = math.max(
                                padding, (content.maxWidth - 1200) / 2);
                            final header = Padding(
                                padding:
                                    EdgeInsets.fromLTRB(gutter, 20, gutter, 22),
                                child: headerBuilder(() =>
                                    Scaffold.of(scaffoldContext).openDrawer()));
                            final largeType =
                                MediaQuery.textScalerOf(context).scale(14) > 21;
                            final scroll = RefreshIndicator(
                                onRefresh: onRefresh,
                                child: CustomScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    slivers: [
                                      if (largeType)
                                        SliverToBoxAdapter(child: header),
                                      for (final sliver in slivers)
                                        SliverPadding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: gutter),
                                            sliver: sliver),
                                      const SliverToBoxAdapter(
                                          child: SizedBox(height: 28)),
                                    ]));
                            return largeType
                                ? scroll
                                : Column(children: [
                                    header,
                                    Expanded(child: scroll)
                                  ]);
                          }))),
            ])),
          ])),
        );
      });
}
