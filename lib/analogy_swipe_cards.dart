import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';

/// Shows the AnalogySwipeCards overlay with REAL data from the API.
void showAnalogyCardsFromApi(
  BuildContext context,
  String slangDetected,
  String literalTranslation,
  List<String> analogies,
  String? ambiguityWarning,
  String preferredLanguage, // <--- ADDED THIS
) {
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
      preferredLanguage: preferredLanguage, // <--- PASSED IT DOWN
    ),
  );
}

class AnalogySwipeCards extends StatefulWidget {
  final String word;
  final List<Map<String, String>> analogies;
  final String literalTranslation;
  final String preferredLanguage;

  const AnalogySwipeCards({
    super.key,
    required this.word,
    required this.analogies,
    required this.literalTranslation,
    this.preferredLanguage = 'en',
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

  // --- AUDIO PLAYER STATE ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void dispose() {
    _audioPlayer.dispose(); // Always clean up the audio player!
    super.dispose();
  }

  // --- PLAY GEMINI TTS ---
  Future<void> _playCardAudio(String text) async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }

    setState(() => _isPlayingAudio = true);
    try {
      // NOTE: Make sure 'baseUrl' in your ApiService is accessible (e.g. static const String baseUrl = ...)
      final url =
          '${ApiService.baseUrl}/api/tts?text=${Uri.encodeComponent(text)}&language=${widget.preferredLanguage}';

      await _audioPlayer.play(UrlSource(url));

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => _isPlayingAudio = false);
      });
    } catch (e) {
      if (mounted) setState(() => _isPlayingAudio = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load audio: $e")));
    }
  }

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
    // Stop audio if they swipe away while it's playing
    if (_isPlayingAudio) {
      _audioPlayer.stop();
      _isPlayingAudio = false;
    }

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
    // Stop audio if they swipe away while it's playing
    if (_isPlayingAudio) {
      _audioPlayer.stop();
      _isPlayingAudio = false;
    }

    final analogy = widget.analogies[_currentIndex];
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("GuestMode");
      }

      await ApiService.saveWord(
        userId: user.uid,
        slangWord: widget.word,
        literalTranslation: widget.literalTranslation,
        successfulAnalogy: analogy['body'] ?? '',
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${widget.word}" saved to My Words!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String errMessage = "Failed to save.";
      if (e.toString().contains("GuestMode")) {
        errMessage = "Sign in from your profile to save words!";
      } else if (e.toString().contains("Timeout")) {
        errMessage = "Network timeout. Could not save.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $errMessage'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(); // Close dialog after swipe
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.word,
            textAlign: TextAlign.center,
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
                height: MediaQuery.of(context).size.height * 0.55,
                padding: const EdgeInsets.all(28),
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
                  children: [
                    // --- EMOJI & AUDIO BUTTON ROW ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          analogy['emoji'] ?? '📖',
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () =>
                              _playCardAudio(analogy['body'] ?? ''),
                          icon: Icon(
                            _isPlayingAudio
                                ? Icons.stop_circle
                                : Icons.volume_up,
                            color: Colors.deepOrangeAccent,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      analogy['title'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          analogy['body'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
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
                    'Save Word',
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
    );
  }
}
