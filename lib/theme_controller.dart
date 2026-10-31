import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme state shared by MaterialApp and the Settings menu.
final ValueNotifier<ThemeMode> appThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.light);

const String _themePreferenceKey = 'sholovvo_theme_mode';

Future<void> loadSavedTheme() async {
  final preferences = await SharedPreferences.getInstance();
  final savedMode = preferences.getString(_themePreferenceKey);
  appThemeMode.value =
      savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
}

Future<void> toggleAppTheme() async {
  final nextMode = appThemeMode.value == ThemeMode.light
      ? ThemeMode.dark
      : ThemeMode.light;

  appThemeMode.value = nextMode;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    _themePreferenceKey,
    nextMode == ThemeMode.dark ? 'dark' : 'light',
  );
}
