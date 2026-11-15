import '/features/appointments/presentation/dawa_mom_appointment_requests.dart';
import '/components/edge_device_indicator.dart';
import '/components/clinician_navigation.dart';
import '/components/navigation_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import '/services/edge_device/edge_device_manager.dart';
export 'appbar_nav_model.dart';

/// Only page context belongs here; product identity lives in the sidebar.
class AppbarNavWidget extends StatelessWidget {
  const AppbarNavWidget(
      {super.key,
      this.deviceManager,
      this.showTitle = true,
      this.notifications});
  final EdgeDeviceManager? deviceManager;
  final bool showTitle;
  final Widget? notifications;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: NavigationTokens.appBarHeight,
      child: Row(children: [
        ValueListenableBuilder<bool>(
            valueListenable: clinicianSidebarCollapsed,
            builder: (context, collapsed, _) => collapsed &&
                    MediaQuery.sizeOf(context).width >=
                        NavigationTokens.desktopBreakpoint
                ? IconButton(
                    tooltip: 'Expand navigation',
                    onPressed: () => clinicianSidebarCollapsed.value = false,
                    icon: const NavigationIcon(NavigationSymbol.sidebar,
                        color: NavigationTokens.secondary))
                : const SizedBox(width: NavigationTokens.gutter)),
        Expanded(
            child: showTitle
                ? Semantics(
                    header: true,
                    child: Text(
                        clinicianPageTitle(GoRouterState.of(context).uri.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NavigationTokens.titleStyle))
                : const SizedBox.shrink()),
        const SizedBox(width: NavigationTokens.gutter),
        notifications ?? const DawaMomNotificationButton(),
        EdgeDeviceIndicator(manager: deviceManager),
        const SizedBox(width: NavigationTokens.space),
      ]));
}
