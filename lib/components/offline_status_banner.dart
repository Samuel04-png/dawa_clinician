import 'dart:async';

import 'package:flutter/material.dart';

import '/components/dawa_design_system.dart';
import '/services/offline_connectivity_service.dart';

class OfflineStatusScope extends StatefulWidget {
  const OfflineStatusScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OfflineStatusScope> createState() => _OfflineStatusScopeState();
}

class _OfflineStatusScopeState extends State<OfflineStatusScope> {
  Timer? _timer;
  String? _dismissedStatusKey;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final snapshot = await OfflineConnectivityService.refreshStatus();
    if (!mounted) {
      return;
    }
    if (!snapshot.isOffline && _dismissedStatusKey != null) {
      setState(() => _dismissedStatusKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineConnectivitySnapshot?>(
      valueListenable: OfflineConnectivityService.statusNotifier,
      builder: (context, snapshot, child) {
        final statusKey = snapshot == null ? null : _statusKeyFor(snapshot);
        final showBanner =
            snapshot?.isOffline == true && statusKey != _dismissedStatusKey;
        return Stack(
          children: [
            child!,
            if (showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Material(
                    color: Colors.transparent,
                    child: _OfflineBanner(
                      message: snapshot!.message,
                      onDismiss: () {
                        if (statusKey == null) {
                          return;
                        }
                        setState(() => _dismissedStatusKey = statusKey);
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }

  String _statusKeyFor(OfflineConnectivitySnapshot snapshot) {
    return [
      snapshot.internetAvailable,
      snapshot.supabaseReachable,
      snapshot.message,
    ].join('|');
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DawaTokens.statusWarningBg,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: DawaTokens.statusWarning),
        boxShadow: DawaTokens.shadowSm,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: DawaTokens.statusWarningText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusWarningText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Dismiss offline status',
            onPressed: onDismiss,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: DawaTokens.statusWarningText,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }
}
