import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VerbaBridgeApp());
}

class VerbaBridgeApp extends StatelessWidget {
  const VerbaBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerbaBridge',
      debugShowCheckedModeBanner:
          false, // Hides the "DEBUG" banner for a clean pitch
      // 🌟 THE FIX: Force Light Mode so text stays black on your white UI cards
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light, // Changed from dark to light
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor:
            Colors.grey.shade100, // Matches your tab backgrounds
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrangeAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // Auto-route based on Auth State
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Add a quick loading state so the screen doesn't flicker on app launch
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Colors.deepOrangeAccent,
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            return const HomeScreen(); // Logged in
          }
          return const LoginScreen(); // Needs to log in
        },
      ),
    );
  }
}
