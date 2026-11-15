import 'package:flutter/foundation.dart';

/// CT has no production record integration. Keep legacy deep links available
/// while preventing its development workspace from being exposed in release.
abstract final class ClinicalFeatures {
  static const ctScan = !kReleaseMode;
}
