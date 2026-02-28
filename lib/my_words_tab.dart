import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Needed for TimeoutException
import 'services/api_service.dart';
import 'services/auth_service.dart';

class MyWordsTab extends StatefulWidget {
  const MyWordsTab({super.key});

  @override
  State<MyWordsTab> createState() => _MyWordsTabState();
}

class _MyWordsTabState extends State<MyWordsTab> {
  List<Map<String, dynamic>> _savedWords = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWords();
  }

  Future<void> _fetchWords() async {
    // Prevent calling setState if the widget is already closed
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Strict Auth Check: Only fetch if a real user is logged in
      if (user == null || AuthService.isGuest.value) {
        setState(() {
          _savedWords = [];
          _isLoading = false;
        });
        return;
      }

      // 2. The Fix: Add a strict 10-second timeout to the API call
      // If the server doesn't respond in 10 seconds, it throws an error instead of spinning forever.
      final words = await ApiService.getWords(user.uid).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
            "Connection timed out. The server might be asleep or unreachable.",
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _savedWords = words;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ── GUEST / LOGGED OUT UI ──
    if (user == null || AuthService.isGuest.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "Sign in to save words",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your vocabulary book is stored in the cloud.\nSign in to start saving words!",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => AuthService().signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: const Text("Sign in with Google"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── LOADING UI ──
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepOrangeAccent),
            SizedBox(height: 16),
            Text(
              "Syncing your vocabulary...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // ── ERROR UI ──
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                "Failed to load words",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // Clean up the Exception text for the user
                _error!.replaceAll('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchWords,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // ── EMPTY UI ──
    if (_savedWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "No saved words yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Swipe right on an analogy card to save it here!",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchWords,
              icon: const Icon(Icons.refresh, color: Colors.deepOrangeAccent),
              label: const Text(
                "Refresh",
                style: TextStyle(color: Colors.deepOrangeAccent),
              ),
            ),
          ],
        ),
      );
    }

    // ── DATA UI (List of Words) ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Vocabulary Book",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              IconButton(
                onPressed: _fetchWords,
                icon: const Icon(Icons.refresh, color: Colors.deepOrangeAccent),
                tooltip: "Refresh Words",
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "${_savedWords.length} words saved",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 12),

        // Word list with Pull-to-Refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchWords, // <-- Swipe down to refresh!
            color: Colors.deepOrangeAccent,
            child: ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Ensures it can be pulled even if the list is small
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _savedWords.length,
              itemBuilder: (context, index) {
                final item = _savedWords[index];
                return _WordAccordionCard(
                  word: item['slang_word'] ?? 'Unknown Word',
                  analogy: item['successful_analogy'] ?? 'No analogy saved.',
                  literal:
                      item['literal_translation'] ?? 'No literal translation.',
                  savedDate: item['saved_at'] ?? '',
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WordAccordionCard extends StatefulWidget {
  final String word;
  final String analogy;
  final String literal;
  final String savedDate;

  const _WordAccordionCard({
    required this.word,
    required this.analogy,
    required this.literal,
    required this.savedDate,
  });

  @override
  State<_WordAccordionCard> createState() => _WordAccordionCardState();
}

class _WordAccordionCardState extends State<_WordAccordionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: _isExpanded ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isExpanded
              ? Colors.deepOrangeAccent.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('📖', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.word,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.literal,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                // Expanded content
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Analogy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.analogy,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
