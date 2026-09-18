import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/no_data_comp/no_data_comp_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'edit_encounter_widget.dart' show EditEncounterWidget;
import 'package:flutter/material.dart';

class EditEncounterModel extends FlutterFlowModel<EditEncounterWidget> {
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
  String? _estimatedbabysizeTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for foetalHemo widget.
  FocusNode? foetalHemoFocusNode;
  TextEditingController? foetalHemoTextController;
  String? Function(BuildContext, String?)? foetalHemoTextControllerValidator;
  String? _foetalHemoTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for heartbeat widget.
  FocusNode? heartbeatFocusNode;
  TextEditingController? heartbeatTextController;
  String? Function(BuildContext, String?)? heartbeatTextControllerValidator;
  String? _heartbeatTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

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
  String? _bpTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for pulse widget.
  FocusNode? pulseFocusNode;
  TextEditingController? pulseTextController;
  String? Function(BuildContext, String?)? pulseTextControllerValidator;
  String? _pulseTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for referAnemia widget.
  String? referAnemiaValue;
  FormFieldController<String>? referAnemiaValueController;
  // State field(s) for hemocheck widget.
  FocusNode? hemocheckFocusNode;
  TextEditingController? hemocheckTextController;
  String? Function(BuildContext, String?)? hemocheckTextControllerValidator;
  String? _hemocheckTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  DateTime? datePicked;
  // State field(s) for comment widget.
  FocusNode? commentFocusNode;
  TextEditingController? commentTextController;
  String? Function(BuildContext, String?)? commentTextControllerValidator;
  String? _commentTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;

  @override
  void initState(BuildContext context) {
    noDataCompModel = createModel(context, () => NoDataCompModel());
    estimatedbabysizeTextControllerValidator =
        _estimatedbabysizeTextControllerValidator;
    foetalHemoTextControllerValidator = _foetalHemoTextControllerValidator;
    heartbeatTextControllerValidator = _heartbeatTextControllerValidator;
    bpTextControllerValidator = _bpTextControllerValidator;
    pulseTextControllerValidator = _pulseTextControllerValidator;
    hemocheckTextControllerValidator = _hemocheckTextControllerValidator;
    commentTextControllerValidator = _commentTextControllerValidator;
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    noDataCompModel.dispose();
    estimatedbabysizeFocusNode?.dispose();
    estimatedbabysizeTextController?.dispose();

    foetalHemoFocusNode?.dispose();
    foetalHemoTextController?.dispose();

    heartbeatFocusNode?.dispose();
    heartbeatTextController?.dispose();

    bpFocusNode?.dispose();
    bpTextController?.dispose();

    pulseFocusNode?.dispose();
    pulseTextController?.dispose();

    hemocheckFocusNode?.dispose();
    hemocheckTextController?.dispose();

    commentFocusNode?.dispose();
    commentTextController?.dispose();

    appbarNavModel.dispose();
    smallSideNavModel.dispose();
  }
}
