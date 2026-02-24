import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.translate, size: 100, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              "VerbaBridge",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text("Decode Culture. Instantly."),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Sign in with Google"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              onPressed: () async {
                await AuthService().signInWithGoogle();
              },
            ),
          ],
        ),
      ),
    );
  }
}
