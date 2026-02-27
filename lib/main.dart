import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_options.dart';
import 'services/auth_service.dart';
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
      // Force Light Mode so text stays black on your white UI cards
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.grey.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrangeAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // Auto-route based on Auth State OR Guest Mode
      home: ValueListenableBuilder<bool>(
        valueListenable: AuthService.isGuest,
        builder: (context, isGuest, _) {
          // Guest mode — skip auth entirely
          if (isGuest) {
            return const HomeScreen();
          }

          // Normal auth-gate
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
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
          );
        },
      ),
    );
  }
}
