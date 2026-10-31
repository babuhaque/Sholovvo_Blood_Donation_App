import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sholovvo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
