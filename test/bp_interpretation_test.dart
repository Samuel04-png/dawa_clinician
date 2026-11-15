import 'package:clinician/application/bp_monitor/bp_monitor_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BpInterpretation interpret(int systolic, int diastolic,
          {bool pregnant = false, bool diabetes = false, int? age}) =>
      BpInterpretation.interpret(
          systolic: systolic,
          diastolic: diastolic,
          age: age,
          hasDiabetes: diabetes,
          hasKidneyDisease: false,
          hasHeartDisease: false,
          isPregnant: pregnant);

  for (final entry in <(int, int, BpSeverity)>[
    (118, 76, BpSeverity.normal),
    (90, 60, BpSeverity.normal),
    (89, 60, BpSeverity.review),
    (100, 59, BpSeverity.review),
    (120, 79, BpSeverity.caution),
    (130, 80, BpSeverity.caution),
    (140, 90, BpSeverity.review),
    (179, 119, BpSeverity.review),
    (180, 119, BpSeverity.urgent),
    (179, 120, BpSeverity.urgent),
  ]) {
    test('BP preserves the existing category for ${entry.$1}/${entry.$2}', () {
      final result = interpret(entry.$1, entry.$2);
      expect(result.severity, entry.$3);
      expect(result.readingLabel, '${entry.$1}/${entry.$2} mmHg');
    });
  }

  test('BP preserves pregnancy and chronic-risk thresholds', () {
    expect(interpret(159, 109, pregnant: true).severity, BpSeverity.review);
    expect(interpret(160, 109, pregnant: true).severity, BpSeverity.urgent);
    expect(interpret(159, 110, pregnant: true).severity, BpSeverity.urgent);
    expect(interpret(130, 80, diabetes: true).severity, BpSeverity.review);
    expect(interpret(130, 80).severity, BpSeverity.caution);
    expect(
        interpret(118, 76, age: 65).contextNotes, contains(contains('Age 65')));
  });

  test('BP outcome text meets AA contrast on each status surface', () {
    for (final result in [
      interpret(118, 76),
      interpret(120, 79),
      interpret(145, 95),
      interpret(180, 120),
    ]) {
      final foreground = result.color.computeLuminance();
      for (final background in [1.0, result.background.computeLuminance()]) {
        final ratio = (background + .05) / (foreground + .05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: result.title);
      }
    }
  });
}
