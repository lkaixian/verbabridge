import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_options.dart';
import 'services/auth_service.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // If no existing login session, silently enter guest mode
  if (FirebaseAuth.instance.currentUser == null) {
    AuthService.isGuest.value = true;
  }

  runApp(const VerbaBridgeApp());
}

class VerbaBridgeApp extends StatelessWidget {
  const VerbaBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerbaBridge',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.orange,
        primaryColor: const Color(0xFFFF6B35),
        scaffoldBackgroundColor: const Color(0xFFF8F7F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF2D2D2D)),
          bodyMedium: TextStyle(color: Color(0xFF2D2D2D)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
