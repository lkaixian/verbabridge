import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';

/// Shows the AnalogySwipeCards overlay with REAL data from the API.
void showAnalogyCardsFromApi(
  BuildContext context,
  String slangDetected,
  String literalTranslation,
  List<String> analogies,
  String? ambiguityWarning,
  String preferredLanguage,
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

Uint8List _createWavHeader(int dataLength, int sampleRate, int channels, int bitDepth) {
  final byteRate = (sampleRate * channels * bitDepth) ~/ 8;
  final blockAlign = (channels * bitDepth) ~/ 8;
  final header = ByteData(44);

  header.setUint8(0, 0x52); // R
  header.setUint8(1, 0x49); // I
  header.setUint8(2, 0x46); // F
  header.setUint8(3, 0x46); // F
  header.setUint32(4, 36 + dataLength, Endian.little);

  header.setUint8(8, 0x57); // W
  header.setUint8(9, 0x41); // A
  header.setUint8(10, 0x56); // V
  header.setUint8(11, 0x45); // E

  header.setUint8(12, 0x66); // f
  header.setUint8(13, 0x6D); // m
  header.setUint8(14, 0x74); // t
  header.setUint8(15, 0x20); // ' '
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitDepth, Endian.little);

  header.setUint8(36, 0x64); // d
  header.setUint8(37, 0x61); // a
  header.setUint8(38, 0x74); // t
  header.setUint8(39, 0x61); // a
  header.setUint32(40, dataLength, Endian.little);

  return header.buffer.asUint8List();
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
  void initState() {
    super.initState();
    // Force the audio to play even if the physical phone switch is on Silent/Vibrate
    final audioContext = AudioContextConfig(
      //forceSpeaker: true,
      respectSilence: false, // <-- This is the magic line
    ).build();
    AudioPlayer.global.setAudioContext(audioContext);

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Server returned HTTP ${response.statusCode}");
      }
      
      final pcmBytes = response.bodyBytes;
      // 24kHz, mono, 16-bit
      final wavHeader = _createWavHeader(pcmBytes.length, 24000, 1, 16);
      
      final wavBuffer = BytesBuilder();
      wavBuffer.add(wavHeader);
      wavBuffer.add(pcmBytes);

      await _audioPlayer.play(BytesSource(wavBuffer.toBytes()));
    } catch (e) {
      if (mounted) setState(() => _isPlayingAudio = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load audio: $e")));
      }
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

    // Card background shifts with drag
    Color cardColor = Colors.white;
    if (_isDragging) {
      if (_dragOffset.dx > 40) {
        cardColor = const Color(0xFFF0FFF0);
      } else if (_dragOffset.dx < -40) {
        cardColor = const Color(0xFFFFF5F0);
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Word title
          Text(
            widget.word,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Card indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.analogies.length, (i) {
              final isActive = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive
                      ? const Color(0xFFFF6B35)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              );
            }),
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
                height: MediaQuery.of(context).size.height * 0.50,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Emoji & Audio Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          analogy['emoji'] ?? '📖',
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () =>
                                _playCardAudio(analogy['body'] ?? ''),
                            icon: Icon(
                              _isPlayingAudio
                                  ? Icons.stop_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      analogy['title'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          analogy['body'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.6,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Swipe hint labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLastCard ? 'Close' : 'Try Another',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Save Word',
                      style: TextStyle(
                        color: Colors.greenAccent.shade200,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.greenAccent.shade200,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Bottom buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleSwipeLeft,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: Text(isLastCard ? 'Close' : 'Next'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF00C853).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                        : const Icon(Icons.favorite_rounded, size: 20),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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

