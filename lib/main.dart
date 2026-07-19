import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/supabase/supabase_config.dart';
import 'components/dawa_design_system.dart';
import 'components/offline_status_banner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';

// IMPORT THE NEW SPLASH SCREEN
import 'dawa_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initSupabase();

  await FlutterFlowTheme.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> {
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;

  // Track the custom splash state
  bool _showCustomSplash = true;

  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = clinicianSupabaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});

    // OLD SPLASH LOGIC REMOVED
    // Future.delayed(
    //   Duration(milliseconds: 1000),
    //   () => _appStateNotifier.stopShowingSplashImage(),
    // );
  }

  @override
  void dispose() {
    authUserSub.cancel();

    super.dispose();
  }

  void _onSplashComplete() {
    if (!_showCustomSplash || !mounted) return;
    debugPrint(
        '[Splash] Removing the splash overlay and revealing the router.');
    setState(() {
      _showCustomSplash = false;
    });
    // Notify FlutterFlow logic that splash is done (preserves original logic)
    _appStateNotifier.stopShowingSplashImage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clinician',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: DawaTokens.brandPrimary,
          secondary: DawaTokens.brandPrimaryLight,
          surface: DawaTokens.surface,
          error: DawaTokens.statusDanger,
          onPrimary: DawaTokens.textInverse,
          onSecondary: DawaTokens.textInverse,
          onSurface: DawaTokens.textPrimary,
          onError: DawaTokens.textInverse,
        ),
        scaffoldBackgroundColor: DawaTokens.surfaceSecondary,
        visualDensity: VisualDensity.standard,
        textTheme: GoogleFonts.dmSansTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: DawaTokens.surface,
          foregroundColor: DawaTokens.brandPrimary,
          elevation: 0.0,
          iconTheme: IconThemeData(color: DawaTokens.brandPrimary),
          actionsIconTheme: IconThemeData(color: DawaTokens.brandPrimary),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: DawaTokens.surface,
          selectedItemColor: DawaTokens.brandPrimary,
          unselectedItemColor: DawaTokens.textSecondary,
          selectedLabelStyle: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: DawaTokens.brandPrimary,
          foregroundColor: DawaTokens.textInverse,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: DawaTokens.surface,
          elevation: 12.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DawaTokens.radiusXl),
          ),
          alignment: Alignment.center,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: DawaTokens.brandPrimary,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DawaTokens.textInverse;
            }
            return DawaTokens.surface;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DawaTokens.brandPrimary;
            }
            return DawaTokens.borderStrong;
          }),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: DawaTokens.surface,
          headerBackgroundColor: DawaTokens.brandPrimary,
          headerForegroundColor: DawaTokens.textInverse,
          todayForegroundColor:
              WidgetStateProperty.all(DawaTokens.brandPrimary),
          todayBorder: const BorderSide(color: DawaTokens.brandPrimary),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DawaTokens.textInverse;
            }
            return DawaTokens.textPrimary;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DawaTokens.brandPrimary;
            }
            return null;
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DawaTokens.surfaceSecondary,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            borderSide: const BorderSide(color: DawaTokens.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            borderSide: const BorderSide(color: DawaTokens.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            borderSide:
                const BorderSide(color: DawaTokens.brandPrimary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0.0,
            minimumSize: const Size(48.0, 48.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            backgroundColor: DawaTokens.brandPrimary,
            foregroundColor: DawaTokens.textInverse,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48.0, 48.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            foregroundColor: DawaTokens.brandPrimary,
            side: const BorderSide(
              color: DawaTokens.brandPrimary,
              width: 1.5,
            ),
          ),
        ),
        useMaterial3: false,
      ),
      themeMode: ThemeMode.light,
      // We use the builder to stack the Splash Screen ON TOP of the Router
      builder: (context, child) {
        return OfflineStatusScope(
          child: Stack(
            children: [
              // The actual App Router
              Router(
                routerDelegate: _router.routerDelegate,
                routeInformationParser: _router.routeInformationParser,
                routeInformationProvider: _router.routeInformationProvider,
              ),
              // The Custom Splash Screen Overlay
              if (_showCustomSplash)
                Positioned.fill(
                  child: DawaSplashScreen(
                    onAnimationComplete: _onSplashComplete,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
