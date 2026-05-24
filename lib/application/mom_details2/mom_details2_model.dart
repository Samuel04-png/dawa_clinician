import '/backend/backend.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/no_data_comp/no_data_comp_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'mom_details2_widget.dart' show MomDetails2Widget;
import 'package:flutter/material.dart';

class MomDetails2Model extends FlutterFlowModel<MomDetails2Widget> {
  ///  Local state fields for this page.

  String navigateTo = '';

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for Marital widget.
  String? maritalValue;
  FormFieldController<String>? maritalValueController;
  // State field(s) for height widget.
  FocusNode? heightFocusNode;
  TextEditingController? heightTextController;
  String? Function(BuildContext, String?)? heightTextControllerValidator;
  // State field(s) for weight widget.
  FocusNode? weightFocusNode;
  TextEditingController? weightTextController;
  String? Function(BuildContext, String?)? weightTextControllerValidator;
  // State field(s) for momEducation widget.
  String? momEducationValue;
  FormFieldController<String>? momEducationValueController;
  // State field(s) for fathersage widget.
  FocusNode? fathersageFocusNode;
  TextEditingController? fathersageTextController;
  String? Function(BuildContext, String?)? fathersageTextControllerValidator;
  String? _fathersageTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for dadEducation widget.
  String? dadEducationValue;
  FormFieldController<String>? dadEducationValueController;
  // State field(s) for alive widget.
  FocusNode? aliveFocusNode;
  TextEditingController? aliveTextController;
  String? Function(BuildContext, String?)? aliveTextControllerValidator;
  String? _aliveTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // Stores action output result for [Backend Call - Create Document] action in alive widget.
  ParityRecord? createdParity;
  // State field(s) for dead widget.
  FocusNode? deadFocusNode;
  TextEditingController? deadTextController;
  String? Function(BuildContext, String?)? deadTextControllerValidator;
  // State field(s) for miscarriages widget.
  FocusNode? miscarriagesFocusNode;
  TextEditingController? miscarriagesTextController;
  String? Function(BuildContext, String?)? miscarriagesTextControllerValidator;
  // State field(s) for kids widget.
  FocusNode? kidsFocusNode;
  TextEditingController? kidsTextController;
  String? Function(BuildContext, String?)? kidsTextControllerValidator;
  // State field(s) for care widget.
  FocusNode? careFocusNode;
  TextEditingController? careTextController;
  String? Function(BuildContext, String?)? careTextControllerValidator;
  // State field(s) for frequency widget.
  FocusNode? frequencyFocusNode;
  TextEditingController? frequencyTextController;
  String? Function(BuildContext, String?)? frequencyTextControllerValidator;
  // State field(s) for cig widget.
  FocusNode? cigFocusNode;
  TextEditingController? cigTextController;
  String? Function(BuildContext, String?)? cigTextControllerValidator;
  // State field(s) for cig1 widget.
  FocusNode? cig1FocusNode;
  TextEditingController? cig1TextController;
  String? Function(BuildContext, String?)? cig1TextControllerValidator;
  // State field(s) for cig2 widget.
  FocusNode? cig2FocusNode;
  TextEditingController? cig2TextController;
  String? Function(BuildContext, String?)? cig2TextControllerValidator;
  // State field(s) for cig3 widget.
  FocusNode? cig3FocusNode;
  TextEditingController? cig3TextController;
  String? Function(BuildContext, String?)? cig3TextControllerValidator;
  // State field(s) for risk widget.
  FocusNode? riskFocusNode;
  TextEditingController? riskTextController;
  String? Function(BuildContext, String?)? riskTextControllerValidator;
  // State field(s) for csection widget.
  FocusNode? csectionFocusNode;
  TextEditingController? csectionTextController;
  String? Function(BuildContext, String?)? csectionTextControllerValidator;
  // State field(s) for RiskFactors widget.
  String? riskFactorsValue;
  FormFieldController<String>? riskFactorsValueController;
  // State field(s) for labor widget.
  String? laborValue;
  FormFieldController<String>? laborValueController;
  // State field(s) for inducedlabor widget.
  String? inducedlaborValue;
  FormFieldController<String>? inducedlaborValueController;
  // State field(s) for augmentaedlabor widget.
  List<String>? augmentaedlaborValue;
  FormFieldController<List<String>>? augmentaedlaborValueController;
  // State field(s) for antibiotics widget.
  List<String>? antibioticsValue;
  FormFieldController<List<String>>? antibioticsValueController;
  // State field(s) for method widget.
  List<String>? methodValue;
  FormFieldController<List<String>>? methodValueController;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  FirstEncounterRecord? firstEncounterCreatedWithAnc;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  FirstEncounterRecord? firstEncounterCreated;
  // Snapshot for encounter list change detection.
  List<EncounterRecord>? listViewPreviousSnapshot;
  // Model for NoDataComp component.
  late NoDataCompModel noDataCompModel;
  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;

  @override
  void initState(BuildContext context) {
    fathersageTextControllerValidator = _fathersageTextControllerValidator;
    aliveTextControllerValidator = _aliveTextControllerValidator;
    noDataCompModel = createModel(context, () => NoDataCompModel());
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    heightFocusNode?.dispose();
    heightTextController?.dispose();

    weightFocusNode?.dispose();
    weightTextController?.dispose();

    fathersageFocusNode?.dispose();
    fathersageTextController?.dispose();

    aliveFocusNode?.dispose();
    aliveTextController?.dispose();

    deadFocusNode?.dispose();
    deadTextController?.dispose();

    miscarriagesFocusNode?.dispose();
    miscarriagesTextController?.dispose();

    kidsFocusNode?.dispose();
    kidsTextController?.dispose();

    careFocusNode?.dispose();
    careTextController?.dispose();

    frequencyFocusNode?.dispose();
    frequencyTextController?.dispose();

    cigFocusNode?.dispose();
    cigTextController?.dispose();

    cig1FocusNode?.dispose();
    cig1TextController?.dispose();

    cig2FocusNode?.dispose();
    cig2TextController?.dispose();

    cig3FocusNode?.dispose();
    cig3TextController?.dispose();

    riskFocusNode?.dispose();
    riskTextController?.dispose();

    csectionFocusNode?.dispose();
    csectionTextController?.dispose();

    noDataCompModel.dispose();
    appbarNavModel.dispose();
    smallSideNavModel.dispose();
  }
}