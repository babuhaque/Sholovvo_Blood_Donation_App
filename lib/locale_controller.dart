import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier<Locale>(const Locale('en'));
const String _localePreferenceKey = 'sholovvo_app_locale';

Future<void> loadSavedLocale() async {
  final preferences = await SharedPreferences.getInstance();
  final languageCode = preferences.getString(_localePreferenceKey) ?? 'en';
  appLocale.value = Locale(languageCode == 'bn' ? 'bn' : 'en');
}

Future<void> setAppLocale(String languageCode) async {
  final normalizedCode = languageCode == 'bn' ? 'bn' : 'en';
  appLocale.value = Locale(normalizedCode);
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_localePreferenceKey, normalizedCode);
}

bool isBangla(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'bn';

String appText(BuildContext context, String english, String bangla) =>
    isBangla(context) ? bangla : english;
