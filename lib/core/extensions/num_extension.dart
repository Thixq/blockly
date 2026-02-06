import 'package:flutter/material.dart';

/// Extension for [double] to get the width or height of the screen.
extension PercentSize on num {
  /// Get the width or height of the screen.
  double w(BuildContext context) =>
      (toDouble() / 100) * MediaQuery.of(context).size.width;

  /// Get the width or height of the screen.
  double h(BuildContext context) =>
      (toDouble() / 100) * MediaQuery.of(context).size.height;
}
