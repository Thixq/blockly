import 'package:flutter/material.dart';

/// Extensions for [BuildContext] to easily access theme.
///
/// Provides [colorScheme], [textTheme], and [theme] properties.
extension ThemeExtension on BuildContext {
  /// Get the [ColorScheme] of the current theme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get the [TextTheme] of the current theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get the [ThemeData] of the current theme.
  ThemeData get theme => Theme.of(this);
}
