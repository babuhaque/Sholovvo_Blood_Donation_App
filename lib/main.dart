import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme_controller.dart';
import 'locale_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the user's saved app theme before the first frame.
  await loadSavedTheme();
  await loadSavedLocale();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase with publishable key and Firebase Auth accessToken callback
  await Supabase.initialize(
    url: 'https://qiipuczhgacwrysyndij.supabase.co',
    publishableKey: 'sb_publishable_em2MznfpwKDvMk-oDWm4hg_55MCaxI3',
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken(false);
    },
  );

  runApp(const SholovvoApp());
}

class SholovvoApp extends StatelessWidget {
  const SholovvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeMode,
          builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sholovvo',
          themeMode: themeMode,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('bn')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.redAccent,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          home: const SplashScreen(),
          );
          },
        );
      },
    );
  }
}
