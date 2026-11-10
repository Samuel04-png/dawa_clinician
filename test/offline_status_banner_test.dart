import 'package:clinician/components/offline_status_banner.dart';
import 'package:clinician/services/offline_connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline banner above Navigator renders and dismisses on login',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => OfflineConnectivityService.statusNotifier.value = null);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => OfflineStatusScope(child: child!),
      home: const Scaffold(body: Text('Login')),
    ));
    // Let the initial connectivity check finish in the test HTTP sandbox.
    await tester.pumpAndSettle();
    OfflineConnectivityService.statusNotifier.value =
        OfflineConnectivitySnapshot(
      internetAvailable: false,
      supabaseReachable: false,
      deviceReachable: false,
      checkedAt: DateTime.now(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    expect(find.textContaining('Offline mode:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline mode:'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
