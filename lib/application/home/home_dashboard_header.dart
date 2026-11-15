import 'package:flutter/material.dart';
import '/components/workspace_page_header.dart';
import '/services/edge_device/edge_device_manager.dart';

class HomeDashboardHeader extends StatelessWidget {
  const HomeDashboardHeader(
      {super.key,
      required this.greeting,
      required this.date,
      required this.onOpenNavigation,
      this.deviceManager});
  final String greeting, date;
  final VoidCallback onOpenNavigation;
  final EdgeDeviceManager? deviceManager;
  @override
  Widget build(BuildContext context) => WorkspacePageHeader(
      title: greeting,
      subtitle: "Here's what needs your attention today.",
      contextLabel: date,
      onOpenNavigation: onOpenNavigation,
      deviceManager: deviceManager);
}
