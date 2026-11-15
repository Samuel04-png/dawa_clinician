import 'package:flutter/material.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'navigation_design_system.dart';

class ClinicianAccountMenu extends StatelessWidget {
  const ClinicianAccountMenu(
      {super.key,
      required this.collapsed,
      required this.onProfile,
      required this.onSignOut,
      this.touch = false});
  final bool collapsed, touch;
  final VoidCallback onProfile, onSignOut;
  @override
  Widget build(BuildContext context) {
    final name = currentUserDisplayName.trim();
    return MenuAnchor(
      style: MenuStyle(
          backgroundColor:
              const WidgetStatePropertyAll(NavigationTokens.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NavigationTokens.radius),
              side: const BorderSide(color: NavigationTokens.border)))),
      menuChildren: [
        MenuItemButton(
            onPressed: onProfile,
            leadingIcon: const NavigationIcon(NavigationSymbol.account),
            child: const Text('Profile')),
        MenuItemButton(
            onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                        title: const Text('Account information'),
                        content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.isEmpty ? 'Clinician' : name,
                                  style: NavigationTokens.itemStyle),
                              if (currentUserEmail.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SelectableText(currentUserEmail),
                              ],
                            ]),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'))
                        ])),
            leadingIcon: const NavigationIcon(NavigationSymbol.info),
            child: const Text('Account information')),
        const Divider(height: 1, color: NavigationTokens.border),
        MenuItemButton(
            onPressed: onSignOut,
            leadingIcon: const NavigationIcon(NavigationSymbol.signOut),
            child: const Text('Sign out')),
      ],
      builder: (context, controller, _) => NavigationItem(
          label: name.isEmpty ? 'Clinician account' : name,
          subtitle: name.isEmpty ? null : 'Clinician account',
          tooltip: 'Clinician account',
          symbol: NavigationSymbol.account,
          collapsed: collapsed,
          touch: touch,
          trailing: const NavigationIcon(NavigationSymbol.chevron, size: 16),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open()),
    );
  }
}
