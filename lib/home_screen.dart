import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'translate_tab.dart';
import 'my_words_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [TranslateTab(), MyWordsTab(), ProfileTab()];

  @override
  Widget build(BuildContext context) {
    final bool isGuest = AuthService.isGuest.value;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          "VerbaBridge",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrangeAccent,
        foregroundColor: Colors.white,
        actions: isGuest
            ? [
                TextButton.icon(
                  onPressed: () async {
                    await AuthService().signInWithGoogle();
                  },
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text(
                    "Sign In",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => AuthService().signOut(),
                ),
              ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepOrangeAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: "Translate"),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: "My Words",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "My Profile",
          ),
        ],
      ),
    );
  }
}
