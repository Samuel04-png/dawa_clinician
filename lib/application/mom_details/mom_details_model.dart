import '/backend/backend.dart';
import '/components/anc_component/anc_component_widget.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/no_data_comp/no_data_comp_widget.dart';
import '/components/parity_input_component/parity_input_component_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'mom_details_widget.dart' show MomDetailsWidget;
import 'package:flutter/material.dart';

class MomDetailsModel extends FlutterFlowModel<MomDetailsWidget> {
  ///  Local state fields for this page.

  String navigateTo = '';

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for HIV widget.
  String? hivValue;
  FormFieldController<String>? hivValueController;
  // State field(s) for lastvl widget.
  FocusNode? lastvlFocusNode;
  TextEditingController? lastvlTextController;
  String? Function(BuildContext, String?)? lastvlTextControllerValidator;
  // State field(s) for cd4 widget.
  FocusNode? cd4FocusNode;
  TextEditingController? cd4TextController;
  String? Function(BuildContext, String?)? cd4TextControllerValidator;
  // State field(s) for DIABE widget.
  String? diabeValue;
  FormFieldController<String>? diabeValueController;
  // State field(s) for epilepsy widget.
  bool? epilepsyValue;
  // State field(s) for asthma widget.
  bool? asthmaValue;
  // State field(s) for tb widget.
  bool? tbValue;
  // State field(s) for bp widget.
  bool? bpValue;
  // State field(s) for sicklecell widget.
  bool? sicklecellValue;
  // State field(s) for menarcheage widget.
  FocusNode? menarcheageFocusNode;
  TextEditingController? menarcheageTextController;
  String? Function(BuildContext, String?)? menarcheageTextControllerValidator;
  String? _menarcheageTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // State field(s) for regular_men widget.
  String? regularMenValue;
  FormFieldController<String>? regularMenValueController;
  // State field(s) for cyclesduration widget.
  String? cyclesdurationValue;
  FormFieldController<String>? cyclesdurationValueController;
  // State field(s) for stis widget.
  List<String>? stisValue;
  FormFieldController<List<String>>? stisValueController;
  DateTime? datePicked1;
  // State field(s) for deliverydate widget.
  FocusNode? deliverydateFocusNode;
  TextEditingController? deliverydateTextController;
  String? Function(BuildContext, String?)? deliverydateTextControllerValidator;
  // State field(s) for cacx widget.
  String? cacxValue;
  FormFieldController<String>? cacxValueController;
  DateTime? datePicked2;
  // State field(s) for parity widget.
  FocusNode? parityFocusNode;
  TextEditingController? parityTextController;
  String? Function(BuildContext, String?)? parityTextControllerValidator;
  String? _parityTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Field is required';
    }

    return null;
  }

  // Stores action output result for [Backend Call - Create Document] action in parity widget.
  ParityRecord? createdParity;
  // State field(s) for gravidity widget.
  FocusNode? gravidityFocusNode;
  TextEditingController? gravidityTextController;
  String? Function(BuildContext, String?)? gravidityTextControllerValidator;
  // Models for parityInputComponent dynamic component.
  late FlutterFlowDynamicModels<ParityInputComponentModel>
      parityInputComponentModels;
  // State field(s) for CardiacDisease widget.
  String? cardiacDiseaseValue;
  FormFieldController<String>? cardiacDiseaseValueController;
  // State field(s) for foetalmovements widget.
  String? foetalmovementsValue;
  FormFieldController<String>? foetalmovementsValueController;
  // State field(s) for drainingliquor widget.
  String? drainingliquorValue;
  FormFieldController<String>? drainingliquorValueController;
  // State field(s) for eclampsia widget.
  List<String>? eclampsiaValue;
  FormFieldController<List<String>>? eclampsiaValueController;
  // State field(s) for anamia widget.
  List<String>? anamiaValue;
  FormFieldController<List<String>>? anamiaValueController;
  // State field(s) for uti widget.
  List<String>? utiValue;
  FormFieldController<List<String>>? utiValueController;
  // State field(s) for anc widget.
  String? ancValue;
  FormFieldController<String>? ancValueController;
  DateTime? datePicked3;
  // Models for ancComponent dynamic component.
  late FlutterFlowDynamicModels<AncComponentModel> ancComponentModels;
  // State field(s) for drugstaken widget.
  List<String>? drugstakenValue;
  FormFieldController<List<String>>? drugstakenValueController;
  // State field(s) for herbsTaken widget.
  String? herbsTakenValue;
  FormFieldController<String>? herbsTakenValueController;
  // State field(s) for allergies widget.
  String? allergiesValue;
  FormFieldController<String>? allergiesValueController;
  // State field(s) for sideEffects widget.
  String? sideEffectsValue;
  FormFieldController<String>? sideEffectsValueController;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  FirstEncounterRecord? firstEncounterCreatedWithAnc;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  FirstEncounterRecord? firstEncounterCreated;
  // Model for NoDataComp component.
  late NoDataCompModel noDataCompModel;
  List<EncounterRecord>? listViewPreviousSnapshot;
  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;

  @override
  void initState(BuildContext context) {
    menarcheageTextControllerValidator = _menarcheageTextControllerValidator;
    parityTextControllerValidator = _parityTextControllerValidator;
    parityInputComponentModels =
        FlutterFlowDynamicModels(() => ParityInputComponentModel());
    ancComponentModels = FlutterFlowDynamicModels(() => AncComponentModel());
    noDataCompModel = createModel(context, () => NoDataCompModel());
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    lastvlFocusNode?.dispose();
    lastvlTextController?.dispose();

    cd4FocusNode?.dispose();
    cd4TextController?.dispose();

    menarcheageFocusNode?.dispose();
    menarcheageTextController?.dispose();

    deliverydateFocusNode?.dispose();
    deliverydateTextController?.dispose();

    parityFocusNode?.dispose();
    parityTextController?.dispose();

    gravidityFocusNode?.dispose();
    gravidityTextController?.dispose();

    parityInputComponentModels.dispose();
    ancComponentModels.dispose();
    noDataCompModel.dispose();
    appbarNavModel.dispose();
    smallSideNavModel.dispose();
  }
}
