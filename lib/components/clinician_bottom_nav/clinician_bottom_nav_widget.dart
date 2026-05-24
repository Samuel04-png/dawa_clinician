import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';

class ClinicianBottomNavWidget extends StatelessWidget {
  const ClinicianBottomNavWidget({
    super.key,
    required this.currentPage,
  });

  final String currentPage;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexForPage(currentPage);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: DawaTokens.surface,
            border: Border(
              top: BorderSide(
                color: DawaTokens.border,
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64.0,
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                type: BottomNavigationBarType.fixed,
                backgroundColor: DawaTokens.surface,
                selectedItemColor: DawaTokens.brandPrimary,
                unselectedItemColor: DawaTokens.textMuted,
                selectedFontSize: 10.0,
                unselectedFontSize: 10.0,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.0,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.0,
                ),
                elevation: 0.0,
                onTap: (index) => _handleTap(context, index, currentIndex),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded, size: 22),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_alt_rounded, size: 22),
                    label: 'Patients',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_rounded, size: 22),
                    label: 'Appointments',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_rounded, size: 22),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _indexForPage(String page) {
    switch (page) {
      case 'Home':
        return 0;
      case 'Patients':
      case 'Mothers':
        return 1;
      case 'Appointments':
        return 2;
      case 'Settings':
      case 'Profile':
        return 3;
      default:
        return 0;
    }
  }

  void _handleTap(BuildContext context, int index, int currentIndex) {
    if (index == currentIndex) {
      return;
    }

    final routeName = switch (index) {
      0 => HomeWidget.routeName,
      1 => MomsWidget.routeName,
      2 => ScheduledEncountersWidget.routeName,
      3 => ProfileWidget.routeName,
      _ => HomeWidget.routeName,
    };
    final pageName = switch (index) {
      0 => 'Home',
      1 => 'Patients',
      2 => 'Appointments',
      3 => 'Settings',
      _ => 'Home',
    };

    FFAppState().selectedPage = pageName;
    FFAppState().makingFIrstEncounter = false;

    context.goNamed(
      routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration(milliseconds: 0),
        ),
      },
    );
  }
}
