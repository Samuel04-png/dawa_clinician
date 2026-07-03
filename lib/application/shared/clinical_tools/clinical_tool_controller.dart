import 'package:flutter/material.dart';

import 'clinical_tool_models.dart';

class ClinicalToolController extends ChangeNotifier {
  ClinicalToolController({
    required this.config,
    required List<ClinicalToolRecord> records,
  }) : _records = List.unmodifiable(records);

  final ClinicalToolConfig config;
  final List<ClinicalToolRecord> _records;

  ClinicalToolDashboardTab activeTab = ClinicalToolDashboardTab.overview;
  ClinicalToolResultsFilter resultsFilter = ClinicalToolResultsFilter.all;
  String searchQuery = '';
  String? selectedPatient;

  List<ClinicalToolRecord> get records => _records;

  List<ClinicalToolRecord> get filteredRecords {
    return _records.where((record) {
      if (resultsFilter == ClinicalToolResultsFilter.completed &&
          record.needsReview) {
        return false;
      }
      if (resultsFilter == ClinicalToolResultsFilter.needsReview &&
          !record.needsReview) {
        return false;
      }
      return record.matches(searchQuery);
    }).toList();
  }

  int get completedCount =>
      _records.where((record) => !record.needsReview).length;

  int get reviewCount => _records.where((record) => record.needsReview).length;

  void setTab(ClinicalToolDashboardTab tab) {
    activeTab = tab;
    notifyListeners();
  }

  void setFilter(ClinicalToolResultsFilter filter) {
    resultsFilter = filter;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void clearSearchAndFilters() {
    searchQuery = '';
    resultsFilter = ClinicalToolResultsFilter.all;
    notifyListeners();
  }

  void prepareNewRecord() {
    selectedPatient = 'New ${config.recordName.toLowerCase()}';
    activeTab = ClinicalToolDashboardTab.records;
    notifyListeners();
  }

  void openPatient(ClinicalToolRecord record) {
    selectedPatient = record.patientName;
    searchQuery = record.patientName;
    activeTab = ClinicalToolDashboardTab.records;
    resultsFilter = ClinicalToolResultsFilter.all;
    notifyListeners();
  }

  void planFollowUp(ClinicalToolRecord record) {
    selectedPatient = record.patientName;
    searchQuery = record.patientName;
    activeTab = ClinicalToolDashboardTab.results;
    resultsFilter = record.needsReview
        ? ClinicalToolResultsFilter.needsReview
        : ClinicalToolResultsFilter.completed;
    notifyListeners();
  }
}
