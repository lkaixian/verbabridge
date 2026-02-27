import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';

/// Placeholder function for local-only saving (fallback)
void saveToMyWordsLocal(String word, String analogy) {
  debugPrint('💾 Saved locally: "$word" → "$analogy"');
}

/// Shows the AnalogySwipeCards overlay with REAL data from the API.
void showAnalogyCardsFromApi(
  BuildContext context,
  String slangDetected,
  String literalTranslation,
  List<String> analogies,
  String? ambiguityWarning,
) {
  // Build card list from API response
  final List<Map<String, String>> cards = [
    {'title': 'Literal Meaning', 'body': literalTranslation, 'emoji': '📖'},
  ];

  for (int i = 0; i < analogies.length; i++) {
    cards.add({
      'title': i == 0 ? 'Cultural Analogy' : 'Generational Analogy',
      'body': analogies[i],
      'emoji': i == 0 ? '🍛' : '📺',
    });
  }

  if (ambiguityWarning != null &&
      ambiguityWarning.isNotEmpty &&
      ambiguityWarning != 'null') {
    cards.add({
      'title': '⚠️ Ambiguity Warning',
      'body': ambiguityWarning,
      'emoji': '🤔',
    });
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (context) => AnalogySwipeCards(
      word: slangDetected,
      analogies: cards,
      literalTranslation: literalTranslation,
    ),
  );
}

/// Legacy function to show cards with placeholder data (kept for backwards compatibility)
void showAnalogyCards(BuildContext context, String word) {
  showAnalogyCardsFromApi(
    context,
    word,
    '"$word" — meaning is being looked up...',
    [
      'Think of it like ordering your favourite Nasi Lemak — everyone just gets it.',
      'Like a classic P. Ramlee movie scene that everyone quotes.',
    ],
    null,
  );
}

class AnalogySwipeCards extends StatefulWidget {
  final String word;
  final List<Map<String, String>> analogies;
  final String literalTranslation;

  const AnalogySwipeCards({
    super.key,
    required this.word,
    required this.analogies,
    required this.literalTranslation,
  });

  @override
  State<AnalogySwipeCards> createState() => _AnalogySwipeCardsState();
}

class _AnalogySwipeCardsState extends State<AnalogySwipeCards> {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  bool _isDragging = false;
  bool _isSaving = false;

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragRotation = _dragOffset.dx / 300 * 0.3;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dx = _dragOffset.dx;

    if (dx > 100) {
      _handleSwipeRight();
    } else if (dx < -100) {
      _handleSwipeLeft();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragRotation = 0;
        _isDragging = false;
      });
    }
  }

  void _handleSwipeLeft() {
    if (_currentIndex < widget.analogies.length - 1) {
      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _dragRotation = 0;
        _isDragging = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSwipeRight() async {
    final analogy = widget.analogies[_currentIndex];
    setState(() => _isSaving = true);

    try {
      // Try saving to backend via API
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'guest';

      await ApiService.saveWord(
        userId: userId,
        slangWord: widget.word,
        literalTranslation: widget.literalTranslation,
        successfulAnalogy: analogy['body'] ?? '',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${widget.word}" saved to My Words!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Fallback to local save
      saveToMyWordsLocal(widget.word, analogy['body'] ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💾 "${widget.word}" saved locally (offline)'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final analogy = widget.analogies[_currentIndex];
    final isLastCard = _currentIndex == widget.analogies.length - 1;

    Color cardColor = Colors.white;
    if (_isDragging) {
      if (_dragOffset.dx > 40) {
        cardColor = Colors.green.shade50;
      } else if (_dragOffset.dx < -40) {
        cardColor = Colors.orange.shade50;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Word header
            Text(
              widget.word,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Card ${_currentIndex + 1} of ${widget.analogies.length}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),

            // Swipeable card
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                transform: Matrix4.identity()
                  ..translate(_dragOffset.dx, _dragOffset.dy)
                  ..rotateZ(_dragRotation),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 300),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        analogy['emoji'] ?? '📖',
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        analogy['title'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        analogy['body'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Swipe hint labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_back,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLastCard ? 'Close' : 'Try Another',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'I Understand!',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tap buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleSwipeLeft,
                    icon: const Icon(Icons.close, size: 20),
                    label: Text(isLastCard ? 'Close' : 'Next'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSwipeRight,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.favorite, size: 20),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
