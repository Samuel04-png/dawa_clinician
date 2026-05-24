import '/backend/backend.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/create_mother_button/create_mother_button_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_calendar.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'home_widget.dart' show HomeWidget;
import 'package:flutter/material.dart';


class HomeModel extends FlutterFlowModel<HomeWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Firestore Query - Query a collection] action in Home widget.
  DoctorRecord? docFound;
  // State field(s) for Calendar widget.
  DateTimeRange? calendarSelectedDay;
  // Model for createMotherButton component.
  late CreateMotherButtonModel createMotherButtonModel;
  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;

  @override
  void initState(BuildContext context) {
    calendarSelectedDay = DateTimeRange(
      start: DateTime.now().startOfDay,
      end: DateTime.now().endOfDay,
    );
    createMotherButtonModel =
        createModel(context, () => CreateMotherButtonModel());
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    createMotherButtonModel.dispose();
    appbarNavModel.dispose();
    smallSideNavModel.dispose();
  }
}
