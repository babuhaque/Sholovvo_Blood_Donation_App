import 'package:flutter/material.dart';

/// App-wide theme state shared by MaterialApp and the Settings menu.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

void toggleAppTheme() {
  appThemeMode.value = appThemeMode.value == ThemeMode.light
      ? ThemeMode.dark
      : ThemeMode.light;
}
