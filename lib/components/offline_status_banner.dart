import '/services/screening_patient_repository.dart';
import '/services/clinical_offline_store.dart';
import '/application/hemonix/repository/anemia_repository.dart';
import '/application/ultrasound/repositories/ultrasound_repository.dart';
import '/application/cacx/cacx_upload_service.dart';
import '/application/cacx/cacx_scan_drafts.dart';
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
  String? _warmedUser;
  bool _warming = false;

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
    if (snapshot.supabaseReachable) {
      unawaited(_syncScanDrafts());
      unawaited(_warmClinicalCache());
    }
    if (snapshot.isOffline) _warmedUser = null;
    if (!mounted) {
      return;
    }
    if (!snapshot.isOffline && _dismissedStatusKey != null) {
      setState(() => _dismissedStatusKey = null);
    }
  }

  Future<void> _warmClinicalCache() async {
    if (_warming) return;
    try {
      final uid = ClinicalOfflineStore.userId;
      if (uid.isEmpty || uid == _warmedUser) return;
      _warming = true;
      final results = await Future.wait([
        _warm(() => const SupabaseScreeningPatientRepository().loadPatients()),
        _warm(() => const SupabaseAnemiaRepository().loadPatients()),
        _warm(() => const SupabaseAnemiaRepository().loadRecords()),
        _warm(() => const SupabaseUltrasoundRepository().loadPatients()),
        _warm(() => const SupabaseUltrasoundRepository().loadScanRecords()),
      ]);
      if (results.every((ok) => ok)) _warmedUser = uid;
    } catch (_) {
      // Startup may precede auth initialization; retry next connection check.
    } finally {
      _warming = false;
    }
  }

  Future<bool> _warm(Future<Object?> Function() load) async {
    try {
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncScanDrafts() async {
    try {
      await ClinicalOfflineStore.sync();
      await CacxScreeningResultsRepository.syncPending();
      await CacxScanDrafts.sync();
    } catch (_) {
      // Auth may not yet be initialized. The next connection check retries.
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
          // This banner sits above the Navigator, outside its Overlay.
          // Label the button without creating an Overlay-dependent Tooltip.
          Semantics(
            label: 'Dismiss offline status',
            child: IconButton(
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
          ),
        ],
      ),
    );
  }
}
