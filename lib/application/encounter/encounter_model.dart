import '/backend/backend.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/no_data_comp/no_data_comp_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'encounter_widget.dart' show EncounterWidget;
import 'package:flutter/material.dart';

class EncounterModel extends FlutterFlowModel<EncounterWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // Model for NoDataComp component.
  late NoDataCompModel noDataCompModel;
  // State field(s) for heartbeatquality widget.
  String? heartbeatqualityValue;
  FormFieldController<String>? heartbeatqualityValueController;
  // State field(s) for womb widget.
  String? wombValue;
  FormFieldController<String>? wombValueController;
  // State field(s) for estimatedbabysize widget.
  FocusNode? estimatedbabysizeFocusNode;
  TextEditingController? estimatedbabysizeTextController;
  String? Function(BuildContext, String?)?
      estimatedbabysizeTextControllerValidator;
  // State field(s) for hemocheck widget.
  FocusNode? hemocheckFocusNode1;
  TextEditingController? hemocheckTextController1;
  String? Function(BuildContext, String?)? hemocheckTextController1Validator;
  // State field(s) for heartbeat widget.
  FocusNode? heartbeatFocusNode;
  TextEditingController? heartbeatTextController;
  String? Function(BuildContext, String?)? heartbeatTextControllerValidator;
  // State field(s) for luecocytes widget.
  String? luecocytesValue;
  FormFieldController<String>? luecocytesValueController;
  // State field(s) for nitrates widget.
  String? nitratesValue;
  FormFieldController<String>? nitratesValueController;
  // State field(s) for urologobulin widget.
  String? urologobulinValue;
  FormFieldController<String>? urologobulinValueController;
  // State field(s) for protein widget.
  String? proteinValue;
  FormFieldController<String>? proteinValueController;
  // State field(s) for ph widget.
  String? phValue;
  FormFieldController<String>? phValueController;
  // State field(s) for blood widget.
  String? bloodValue;
  FormFieldController<String>? bloodValueController;
  // State field(s) for gravity widget.
  String? gravityValue;
  FormFieldController<String>? gravityValueController;
  // State field(s) for color widget.
  String? colorValue;
  FormFieldController<String>? colorValueController;
  // State field(s) for ketones widget.
  String? ketonesValue;
  FormFieldController<String>? ketonesValueController;
  // State field(s) for bilrubin widget.
  String? bilrubinValue;
  FormFieldController<String>? bilrubinValueController;
  // State field(s) for glucose widget.
  String? glucoseValue;
  FormFieldController<String>? glucoseValueController;
  // State field(s) for clarity widget.
  String? clarityValue;
  FormFieldController<String>? clarityValueController;
  // State field(s) for odor widget.
  String? odorValue;
  FormFieldController<String>? odorValueController;
  // State field(s) for Cast widget.
  String? castValue;
  FormFieldController<String>? castValueController;
  // State field(s) for bp widget.
  FocusNode? bpFocusNode;
  TextEditingController? bpTextController;
  String? Function(BuildContext, String?)? bpTextControllerValidator;
  // State field(s) for pulse widget.
  FocusNode? pulseFocusNode;
  TextEditingController? pulseTextController;
  String? Function(BuildContext, String?)? pulseTextControllerValidator;
  // State field(s) for referAnemia widget.
  String? referAnemiaValue;
  FormFieldController<String>? referAnemiaValueController;
  // State field(s) for hemocheck widget.
  FocusNode? hemocheckFocusNode2;
  TextEditingController? hemocheckTextController2;
  String? Function(BuildContext, String?)? hemocheckTextController2Validator;
  DateTime? datePicked;
  // State field(s) for comment widget.
  FocusNode? commentFocusNode;
  TextEditingController? commentTextController;
  String? Function(BuildContext, String?)? commentTextControllerValidator;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  EncounterRecord? createdEncounter;
  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;

  @override
  void initState(BuildContext context) {
    noDataCompModel = createModel(context, () => NoDataCompModel());
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    noDataCompModel.dispose();
    estimatedbabysizeFocusNode?.dispose();
    estimatedbabysizeTextController?.dispose();

    hemocheckFocusNode1?.dispose();
    hemocheckTextController1?.dispose();

    heartbeatFocusNode?.dispose();
    heartbeatTextController?.dispose();

    bpFocusNode?.dispose();
    bpTextController?.dispose();

    pulseFocusNode?.dispose();
    pulseTextController?.dispose();

    hemocheckFocusNode2?.dispose();
    hemocheckTextController2?.dispose();

    commentFocusNode?.dispose();
    commentTextController?.dispose();

    appbarNavModel.dispose();
    smallSideNavModel.dispose();
  }
}
