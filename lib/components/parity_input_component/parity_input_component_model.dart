import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'parity_input_component_widget.dart' show ParityInputComponentWidget;
import 'package:flutter/material.dart';

class ParityInputComponentModel
    extends FlutterFlowModel<ParityInputComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for birthyear widget.
  FocusNode? birthyearFocusNode;
  TextEditingController? birthyearTextController;
  String? Function(BuildContext, String?)? birthyearTextControllerValidator;
  // State field(s) for birthWeight widget.
  FocusNode? birthWeightFocusNode;
  TextEditingController? birthWeightTextController;
  String? Function(BuildContext, String?)? birthWeightTextControllerValidator;
  // State field(s) for modeOfDeli widget.
  String? modeOfDeliValue;
  FormFieldController<String>? modeOfDeliValueController;
  // State field(s) for birthState widget.
  String? birthStateValue;
  FormFieldController<String>? birthStateValueController;
  // State field(s) for complications widget.
  List<String>? complicationsValue;
  FormFieldController<List<String>>? complicationsValueController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    birthyearFocusNode?.dispose();
    birthyearTextController?.dispose();

    birthWeightFocusNode?.dispose();
    birthWeightTextController?.dispose();
  }
}
