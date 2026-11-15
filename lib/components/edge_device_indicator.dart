import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import 'navigation_design_system.dart';

class EdgeDeviceIndicator extends StatefulWidget {
  const EdgeDeviceIndicator({super.key, this.manager});
  final EdgeDeviceManager? manager;
  @override
  State<EdgeDeviceIndicator> createState() => _EdgeDeviceIndicatorState();
}

class _EdgeDeviceIndicatorState extends State<EdgeDeviceIndicator>
    with SingleTickerProviderStateMixin {
  late final manager = widget.manager ?? EdgeDeviceManager.shared;
  late final motion = AnimationController(
      vsync: this, duration: NavigationTokens.deviceDuration);
  final menuController = MenuController();
  bool wasInitializing = false;
  @override
  void initState() {
    super.initState();
    manager.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(manager.checkHubConnection());
    });
  }

  void _changed() {
    if (!mounted) return;
    if (initializing &&
        !wasInitializing &&
        !MediaQuery.disableAnimationsOf(context)) {
      motion.forward(from: 0);
    } else if (!initializing) {
      motion.reset();
    }
    wasInitializing = initializing;
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) motion.reset();
  }

  @override
  void dispose() {
    manager.removeListener(_changed);
    motion.dispose();
    super.dispose();
  }

  String get connection => manager.hubConnected == true
      ? 'Connected'
      : manager.hubConnected == false
          ? 'Offline'
          : 'Not verified';
  bool get initializing =>
      manager.hubConnected == true &&
      (manager.hubStatus?.state == EdgeHubModuleState.starting ||
          manager.state == EdgeDeviceState.loadingModel);
  bool get confirmedError =>
      manager.hubConnected == true &&
      manager.hubStatus?.state == EdgeHubModuleState.error;
  String get readiness {
    if (manager.hubConnected != true) return 'Not verified';
    if (confirmedError) return 'Device reported an error';
    if (initializing) return 'Initializing';
    final hub = manager.hubStatus;
    if (hub?.active == null) return 'No active model';
    return hub!.isReadyFor(hub.active!) ? 'Ready (hub confirmed)' : 'Not ready';
  }

  String get activeModel => switch (manager.hubStatus?.active) {
        'cervitriage' => 'Cervical Cancer',
        'ultrasound' => 'Ultrasound',
        'anemia' => 'Anemia',
        final String value => value,
        _ => 'None confirmed',
      };
  Color get statusColor => confirmedError
      ? NavigationTokens.error
      : initializing
          ? NavigationTokens.brand
          : manager.hubConnected == true
              ? NavigationTokens.connected
              : NavigationTokens.secondary;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: menuController,
      style: MenuStyle(
          backgroundColor:
              const WidgetStatePropertyAll(NavigationTokens.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NavigationTokens.radius),
              side: const BorderSide(color: NavigationTokens.border)))),
      onOpen: () => unawaited(manager.checkHubConnection()),
      menuChildren: [
        _DeviceStatusPanel(
            manager: manager,
            connection: () => connection,
            readiness: () => readiness,
            activeModel: () => activeModel,
            onDiagnostics: () {
              menuController.close();
              _diagnostics();
            })
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Edge device: $connection · $readiness',
        excludeFromSemantics: true,
        child: Semantics(
          label: 'Edge device: $connection. Model: $readiness',
          button: true,
          expanded: controller.isOpen,
          child: TextButton(
            key: const ValueKey('edge-device-control'),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            style: TextButton.styleFrom(
                foregroundColor: NavigationTokens.text,
                minimumSize: const Size(40, 40),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(NavigationTokens.radius))),
            child: ExcludeSemantics(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                  animation: motion,
                  builder: (_, __) => Opacity(
                        opacity: initializing && motion.isAnimating
                            ? .82 + .18 * math.cos(motion.value * math.pi * 6)
                            : 1,
                        child: SizedBox.square(
                            dimension: 28,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              const NavigationIcon(NavigationSymbol.device,
                                  size: 22, color: NavigationTokens.secondary),
                              Positioned(
                                  right: 0,
                                  bottom: 1,
                                  child: AnimatedContainer(
                                      key: const ValueKey(
                                          'edge-device-status-dot'),
                                      duration:
                                          NavigationTokens.duration(context),
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: confirmedError
                                              ? BoxShape.rectangle
                                              : BoxShape.circle,
                                          border: Border.all(
                                              color: NavigationTokens.surface,
                                              width: 1.5),
                                          boxShadow:
                                              manager.hubConnected == true &&
                                                      !confirmedError &&
                                                      !initializing
                                                  ? [
                                                      BoxShadow(
                                                          color: statusColor
                                                              .withValues(
                                                                  alpha: .15),
                                                          blurRadius: 5)
                                                    ]
                                                  : null))),
                            ])),
                      )),
            ])),
          ),
        ),
      ),
    );
  }

  void _diagnostics() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Device diagnostics'),
              content: SingleChildScrollView(
                  primary: false,
                  child: SelectableText(
                      '${manager.client.config.diagnosticSummary()}\n\n'
                      'Connection: $connection\nModel: $readiness\n'
                      'Workflow: ${manager.state.name}\n'
                      '${manager.statusCheckMessage ?? 'No additional status message.'}')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ]));
}

/// Real focusable actions in an anchored panel, rather than a disabled menu item.
class _DeviceStatusPanel extends StatelessWidget {
  const _DeviceStatusPanel(
      {required this.manager,
      required this.connection,
      required this.readiness,
      required this.activeModel,
      required this.onDiagnostics});
  final EdgeDeviceManager manager;
  final String Function() connection, readiness, activeModel;
  final VoidCallback onDiagnostics;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: manager,
      builder: (context, _) => SizedBox(
            width: math.min(320, MediaQuery.sizeOf(context).width - 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .8),
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle.merge(
                  style: NavigationTokens.detailStyle,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                            header: true,
                            child: Text('Edge device',
                                style: NavigationTokens.itemStyle)),
                        const SizedBox(height: 16),
                        _detail('Connection status', connection()),
                        _detail('Active model', activeModel()),
                        _detail('Model readiness', readiness()),
                        _detail(
                            'Last successful check',
                            manager.lastSuccessfulCheck == null
                                ? 'No successful check'
                                : manager.lastSuccessfulCheck!
                                    .toLocal()
                                    .toString()
                                    .split('.')
                                    .first),
                        if (!manager.canCheckHub)
                          const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                  'Checks deferred while an examination or model preparation is active.',
                                  style: NavigationTokens.secondaryStyle)),
                        TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: NavigationTokens.brand),
                            onPressed:
                                manager.canCheckHub && !manager.checkingHub
                                    ? () => unawaited(
                                        manager.checkHubConnection(retry: true))
                                    : null,
                            icon: const NavigationIcon(NavigationSymbol.retry,
                                size: 18),
                            label: Text(manager.checkingHub
                                ? 'Checking…'
                                : 'Retry Connection')),
                        TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: NavigationTokens.brand),
                            onPressed: onDiagnostics,
                            icon: const NavigationIcon(NavigationSymbol.info,
                                size: 18),
                            label: const Text('View Diagnostics')),
                      ]),
                ),
              ),
            ),
          ));
  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: NavigationTokens.secondaryStyle),
        const SizedBox(height: 2),
        Text(value),
      ]));
}
