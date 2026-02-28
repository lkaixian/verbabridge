import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
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

              // Inside login_screen.dart ...
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
                  final userCredential = await AuthService().signInWithGoogle();
                  // If login is successful, close the login page
                  if (userCredential != null && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  AuthService().continueAsGuest();
                  // Close the login page and go back
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Continue as Guest",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              // ... rest of the file
              const SizedBox(height: 8),
              const Text(
                "Some features like History will be unavailable",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
