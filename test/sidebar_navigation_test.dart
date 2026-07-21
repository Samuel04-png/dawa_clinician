import 'package:clinician/app_state.dart';
import 'package:clinician/components/small_side_nav/small_side_nav_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sidebar groups clinical modules under Care Tools',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/care-tools',
      routes: [
        GoRoute(
          path: '/care-tools',
          builder: (context, state) => const Scaffold(
            body: SmallSideNavWidget(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FFAppState(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Care Tools'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('HemoNix'), findsNothing);
    expect(find.text('CT Scan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
