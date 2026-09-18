import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _doctor = prefs.getString('ff_doctor')?.ref ?? _doctor;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  DocumentReference? _doctor;
  DocumentReference? get doctor => _doctor;
  set doctor(DocumentReference? value) {
    _doctor = value;
    value != null
        ? prefs.setString('ff_doctor', value.path)
        : prefs.remove('ff_doctor');
  }

  DateTime? _motherCreatedTime;
  DateTime? get motherCreatedTime => _motherCreatedTime;
  set motherCreatedTime(DateTime? value) {
    _motherCreatedTime = value;
  }

  String _selectedPage = 'Home';
  String get selectedPage => _selectedPage;
  set selectedPage(String value) {
    _selectedPage = value;
  }

  String _randomPasswordGenerated = '';
  String get randomPasswordGenerated => _randomPasswordGenerated;
  set randomPasswordGenerated(String value) {
    _randomPasswordGenerated = value;
  }

  bool _makingFIrstEncounter = false;
  bool get makingFIrstEncounter => _makingFIrstEncounter;
  set makingFIrstEncounter(bool value) {
    _makingFIrstEncounter = value;
  }

  List<DocumentReference> _parity = [];
  List<DocumentReference> get parity => _parity;
  set parity(List<DocumentReference> value) {
    _parity = value;
  }

  void addToParity(DocumentReference value) {
    parity.add(value);
  }

  void removeFromParity(DocumentReference value) {
    parity.remove(value);
  }

  void removeAtIndexFromParity(int index) {
    parity.removeAt(index);
  }

  void updateParityAtIndex(
    int index,
    DocumentReference Function(DocumentReference) updateFn,
  ) {
    parity[index] = updateFn(_parity[index]);
  }

  void insertAtIndexInParity(int index, DocumentReference value) {
    parity.insert(index, value);
  }

  List<DateTime> _ancDates = [];
  List<DateTime> get ancDates => _ancDates;
  set ancDates(List<DateTime> value) {
    _ancDates = value;
  }

  void addToAncDates(DateTime value) {
    ancDates.add(value);
  }

  void removeFromAncDates(DateTime value) {
    ancDates.remove(value);
  }

  void removeAtIndexFromAncDates(int index) {
    ancDates.removeAt(index);
  }

  void updateAncDatesAtIndex(
    int index,
    DateTime Function(DateTime) updateFn,
  ) {
    ancDates[index] = updateFn(_ancDates[index]);
  }

  void insertAtIndexInAncDates(int index, DateTime value) {
    ancDates.insert(index, value);
  }

  int _stiIndex = 0;
  int get stiIndex => _stiIndex;
  set stiIndex(int value) {
    _stiIndex = value;
  }

  String _adminPin = '';
  String get adminPin => _adminPin;
  set adminPin(String value) {
    _adminPin = value;
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
