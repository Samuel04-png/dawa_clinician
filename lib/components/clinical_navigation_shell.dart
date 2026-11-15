import '/components/navigation_design_system.dart';
import '/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'appbar_nav/appbar_nav_widget.dart';
import 'small_side_nav/small_side_nav_widget.dart';

/// Clinical workspaces retain a bounded viewport for their patient-context
/// headers and actions. The sidebar shares Home's full-height geometry.
class ClinicalNavigationShell extends StatelessWidget {
  const ClinicalNavigationShell(
      {super.key, required this.child, this.deviceManager});
  final Widget child;
  final EdgeDeviceManager? deviceManager;
  @override
  Widget build(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >= NavigationTokens.desktopBreakpoint;
    return Scaffold(
      backgroundColor: NavigationTokens.canvas,
      drawer: desktop
          ? null
          : const Drawer(
              width: NavigationTokens.expandedWidth,
              child: SmallSideNavWidget()),
      body: SafeArea(
          child: Row(children: [
        if (desktop) const SmallSideNavWidget(),
        Expanded(
            child: Column(children: [
          Material(
              color: Colors.white,
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: NavigationTokens.border))),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        if (!desktop)
                          Builder(
                              builder: (context) => IconButton(
                                  tooltip: 'Open navigation',
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const NavigationIcon(
                                      NavigationSymbol.menu,
                                      color: NavigationTokens.brand))),
                        Expanded(
                            child:
                                AppbarNavWidget(deviceManager: deviceManager)),
                      ])))),
          Expanded(child: child),
        ])),
      ])),
    );
  }
}
