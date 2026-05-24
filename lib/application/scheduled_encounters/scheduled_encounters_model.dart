import '/backend/backend.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'scheduled_encounters_widget.dart' show ScheduledEncountersWidget;
import 'package:flutter/material.dart';

class ScheduledEncountersModel
    extends FlutterFlowModel<ScheduledEncountersWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Stores action output result for [Backend Call - Read Document] action in Row widget.
  MotherRecord? momSelected;

  @override
  void initState(BuildContext context) {
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    appbarNavModel.dispose();
    smallSideNavModel.dispose();
    tabBarController?.dispose();
  }
}
