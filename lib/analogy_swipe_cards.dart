import 'package:flutter/material.dart';

/// Placeholder function — will eventually save the word to Firestore
void saveToMyWords(String word, String analogy) {
  debugPrint('💾 Saved to My Words: "$word" → "$analogy"');
}

/// Shows the AnalogySwipeCards overlay as a full-screen dialog.
void showAnalogyCards(BuildContext context, String word) {
  // Placeholder analogy data for each word
  final List<Map<String, String>> analogies = [
    {
      'title': 'Literal Meaning',
      'body':
          '"$word" literally translates to its direct dictionary definition.',
      'emoji': '📖',
    },
    {
      'title': 'Cultural Analogy',
      'body':
          'It is like ordering a perfect Nasi Lemak at the Jelutong market — '
          'everyone knows exactly what you mean without needing to explain.',
      'emoji': '🍛',
    },
    {
      'title': 'Usage in Context',
      'body':
          'Imagine you are at a Kopitiam and your friend says "$word" — '
          'it carries a warmth and familiarity that only locals understand.',
      'emoji': '☕',
    },
    {
      'title': 'Pop Culture Reference',
      'body':
          'Think of it like a meme that went viral — '
          'everyone uses "$word" and instantly gets the vibe.',
      'emoji': '🎭',
    },
  ];

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (context) => AnalogySwipeCards(word: word, analogies: analogies),
  );
}

class AnalogySwipeCards extends StatefulWidget {
  final String word;
  final List<Map<String, String>> analogies;

  const AnalogySwipeCards({
    super.key,
    required this.word,
    required this.analogies,
  });

  @override
  State<AnalogySwipeCards> createState() => _AnalogySwipeCardsState();
}

class _AnalogySwipeCardsState extends State<AnalogySwipeCards>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  bool _isDragging = false;

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragRotation = _dragOffset.dx / 300 * 0.3; // Subtle tilt
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dx = _dragOffset.dx;

    if (dx > 100) {
      // Swiped RIGHT → "I Understand!"
      _handleSwipeRight();
    } else if (dx < -100) {
      // Swiped LEFT → "Try Another"
      _handleSwipeLeft();
    } else {
      // Snap back
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
      // No more cards — close
      Navigator.of(context).pop();
    }
  }

  void _handleSwipeRight() {
    final analogy = widget.analogies[_currentIndex];
    saveToMyWords(widget.word, analogy['body'] ?? '');

    // Show confirmation then close
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ "${widget.word}" saved to My Words!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final analogy = widget.analogies[_currentIndex];
    final isLastCard = _currentIndex == widget.analogies.length - 1;

    // Determine swipe hint color
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
                    // Emoji
                    Text(
                      analogy['emoji'] ?? '📖',
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 16),

                    // Title
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

                    // Body — senior-friendly large text
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
              // Left hint
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
              // Right hint
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

          // Tap buttons as alternative to swiping
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
                  onPressed: _handleSwipeRight,
                  icon: const Icon(Icons.favorite, size: 20),
                  label: const Text('Save'),
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
    );
  }
}
