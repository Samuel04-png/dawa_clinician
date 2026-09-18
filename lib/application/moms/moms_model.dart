import '/backend/backend.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/create_mother_button/create_mother_button_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/request_manager.dart';

import '/index.dart';
import 'moms_widget.dart' show MomsWidget;
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class MomsModel extends FlutterFlowModel<MomsWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for createMotherButton component.
  late CreateMotherButtonModel createMotherButtonModel;
  // State field(s) for ListView widget.

  PagingController<DocumentSnapshot?, MotherRecord>? listViewPagingController;
  Query? listViewPagingQuery;
  List<StreamSubscription?> listViewStreamSubscriptions = [];

  // Model for AppbarNav component.
  late AppbarNavModel appbarNavModel;
  // Model for SmallSideNav component.
  late SmallSideNavModel smallSideNavModel;

  /// Query cache managers for this widget.

  final _mothersManager = StreamRequestManager<List<DoctorRecord>>();
  Stream<List<DoctorRecord>> mothers({
    String? uniqueQueryKey,
    bool? overrideCache,
    required Stream<List<DoctorRecord>> Function() requestFn,
  }) =>
      _mothersManager.performRequest(
        uniqueQueryKey: uniqueQueryKey,
        overrideCache: overrideCache,
        requestFn: requestFn,
      );
  void clearMothersCache() => _mothersManager.clear();
  void clearMothersCacheKey(String? uniqueKey) =>
      _mothersManager.clearRequest(uniqueKey);

  @override
  void initState(BuildContext context) {
    createMotherButtonModel =
        createModel(context, () => CreateMotherButtonModel());
    appbarNavModel = createModel(context, () => AppbarNavModel());
    smallSideNavModel = createModel(context, () => SmallSideNavModel());
  }

  @override
  void dispose() {
    createMotherButtonModel.dispose();
    listViewStreamSubscriptions.forEach((s) => s?.cancel());
    listViewPagingController?.dispose();

    appbarNavModel.dispose();
    smallSideNavModel.dispose();

    /// Dispose query cache managers for this widget.

    clearMothersCache();
  }

  /// Additional helper methods.
  PagingController<DocumentSnapshot?, MotherRecord> setListViewController(
    Query query, {
    DocumentReference<Object?>? parent,
  }) {
    listViewPagingController ??= _createListViewController(query, parent);
    if (listViewPagingQuery != query) {
      listViewPagingQuery = query;
      listViewPagingController?.refresh();
    }
    return listViewPagingController!;
  }

  PagingController<DocumentSnapshot?, MotherRecord> _createListViewController(
    Query query,
    DocumentReference<Object?>? parent,
  ) {
    final controller =
        PagingController<DocumentSnapshot?, MotherRecord>(firstPageKey: null);
    return controller
      ..addPageRequestListener(
        (nextPageMarker) => queryMotherRecordPage(
          queryBuilder: (_) => listViewPagingQuery ??= query,
          nextPageMarker: nextPageMarker,
          streamSubscriptions: listViewStreamSubscriptions,
          controller: controller,
          pageSize: 8,
          isStream: true,
        ),
      );
  }
}
