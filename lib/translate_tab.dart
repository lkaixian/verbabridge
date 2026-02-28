import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart'; // Added for audio recording
import 'package:path_provider/path_provider.dart'; // Added for temp storage
import 'services/api_service.dart';
import 'profile_tab.dart';
import 'analogy_swipe_cards.dart';

class TranslateTab extends StatefulWidget {
  const TranslateTab({super.key});

  @override
  State<TranslateTab> createState() => _TranslateTabState();
}

class _TranslateTabState extends State<TranslateTab>
    with SingleTickerProviderStateMixin {
  bool _isLiveMode = false;
  bool _isListening = false;
  bool _isLoading = false;

  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _liveTranscript = [];
  final TextEditingController _liveInputController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Audio Recording Instances
  late final AudioRecorder _audioRecorder;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _textController.addListener(() => setState(() {}));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _liveInputController.dispose();
    _audioRecorder.dispose(); // Always dispose of the recorder!
    super.dispose();
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (error is SocketException ||
        errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('failed host lookup')) {
      return "Cannot connect to the server. It might be offline or sleeping. 😴";
    } else if (error is TimeoutException || errorStr.contains('timeout')) {
      return "The server took too long to respond. Please check your internet and try again. ⏳";
    } else if (error is FormatException || errorStr.contains('format')) {
      return "The server is confused and sent a bad response. 🛠️";
    } else if (errorStr.contains('502') || errorStr.contains('503')) {
      return "The server is currently down for maintenance. 🚧";
    } else if (errorStr.contains('500')) {
      return "The AI encountered an internal glitch. Please try another word. 🤖";
    }

    // Fallback: Clean up the standard exception text if it's an unknown error
    return error.toString().replaceAll('Exception: ', '');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── LOOKUP: Call /generate_analogy API (Text based) ──
  Future<void> _handleLookup() async {
    final typed = _textController.text.trim();
    if (typed.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.generateAnalogy(
        slangText: typed,
        userGeneration: UserProfile.generation ?? 'Boomer',
        userVibe: UserProfile.dialect ?? 'Standard English',
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final analogies = List<String>.from(result['analogies'] ?? []);
      final literal = result['literal_translation'] ?? '';
      final slangDetected = result['slang_detected'] ?? typed;
      final warning = result['ambiguity_warning'];

      showAnalogyCardsFromApi(
        context,
        slangDetected,
        literal,
        analogies,
        warning,
      );
      _textController.clear();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── LIVE TRANSLATE (Text Input) ──
  Future<void> _handleLiveTranslate(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final result = await ApiService.liveTranslate(
        text: text,
        userVibe: UserProfile.dialect ?? 'Standard English',
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _liveTranscript.insert(0, {
          'original': text,
          'text': result['translated_text'] ?? text,
          'slangs': List<String>.from(result['highlight_words'] ?? []),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liveTranscript.insert(0, {
          'original': text,
          'text': "⚠️ ${_getFriendlyErrorMessage(e)}",
          'slangs': <String>[],
        });
      });
      _showErrorSnackBar("Live translation disconnected.");
    }
  }

  // ── LIVE AUDIO RECORDING & UPLOAD TO GEMINI ──
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        _audioPath =
            '${tempDir.path}/verba_live_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Start recording in M4A format
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _audioPath!,
        );

        setState(() {
          _isListening = true;
          _pulseController.repeat(reverse: true);
        });
      } else {
        _showErrorSnackBar("Microphone permission denied.");
      }
    } catch (e) {
      _showErrorSnackBar("Failed to start recording: $e");
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    setState(() {
      _isListening = false;
      _pulseController.stop();
      _pulseController.reset();
      _isLoading = true; // Show a loading state while uploading
    });

    try {
      final String? path = await _audioRecorder.stop();
      if (path != null) {
        if (_isLiveMode) {
          // --- LIVE MODE FLOW ---
          setState(() {
            _liveTranscript.insert(0, {
              'original': '🎙️ Processing audio...',
              'text': '...',
              'slangs': <String>[],
            });
          });

          // Send the raw audio file to FastAPI -> Gemini
          final result = await ApiService.liveTranslateAudio(
            filePath: path,
            userVibe: UserProfile.dialect ?? 'Standard English',
          );

          if (!mounted) return;

          final originalTranscription =
              result['original_transcription'] ?? 'Audio recognized';
          final translatedText = result['translated_text'] ?? '';
          final slangs = List<String>.from(result['highlight_words'] ?? []);

          setState(() {
            // Replace the "processing" placeholder with the real result
            _liveTranscript[0] = {
              'original': '🎙️ $originalTranscription',
              'text': translatedText,
              'slangs': slangs,
            };
          });
        } else {
          // --- LOOKUP MODE FLOW (ONE-SHOT) ---
          final result = await ApiService.generateAnalogyAudio(
            filePath: path,
            userGeneration: UserProfile.generation ?? 'Boomer',
            userVibe: UserProfile.dialect ?? 'Standard English',
          );

          if (!mounted) return;

          final slangDetected = result['slang_detected'] ?? 'Audio Input';
          final literal = result['literal_translation'] ?? '';
          final analogies = List<String>.from(result['analogies'] ?? []);
          final warning = result['ambiguity_warning'];

          // Update the text box to show what it heard, and instantly show cards!
          _textController.text = slangDetected;
          showAnalogyCardsFromApi(
            context,
            slangDetected,
            literal,
            analogies,
            warning,
          );
        }

        // Clean up temp file
        File(path).delete().catchError(
          (e) => debugPrint("Failed to delete temp file: $e"),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
      if (_isLiveMode && _liveTranscript.isNotEmpty) {
        setState(
          () => _liveTranscript.removeAt(0),
        ); // Remove processing placeholder on error
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSlangTap(String slang) {
    _textController.text = slang;
    setState(() => _isLiveMode = false);
    _handleLookup();
  }

  Widget _buildPillToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLiveMode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isLiveMode
                      ? Colors.deepOrangeAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    "Lookup",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: !_isLiveMode ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLiveMode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isLiveMode
                      ? Colors.deepOrangeAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    "Live",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _isLiveMode ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupMode() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _textController,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleLookup(),
              decoration: InputDecoration(
                hintText: "Type slang or Hold Mic to speak...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Colors.deepOrangeAccent,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_textController.text.trim().isEmpty || _isLoading)
                    ? null
                    : _handleLookup,
                icon:
                    _isLoading &&
                        !_isListening // Don't show this spinner if mic is spinning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 22),
                label: Text(
                  _isLoading && !_isListening
                      ? "Decoding Culture..."
                      : "Translate",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Microphone (Now wired to actual recording logic)
          Column(
            children: [
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecordingAndProcess(),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.red.shade400
                              : Colors.deepOrangeAccent,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isListening
                                          ? Colors.red
                                          : Colors.deepOrangeAccent)
                                      .withValues(alpha: 0.4),
                              blurRadius: _isListening ? 30 : 15,
                              spreadRadius: _isListening ? 5 : 2,
                            ),
                          ],
                        ),
                        child: _isLoading && _isListening == false
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isListening
                    ? "Recording..."
                    : (_isLoading ? "Processing Audio..." : "Hold to Speak"),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isListening ? Colors.red.shade400 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "Translation cards will appear here",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _liveInputController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    final text = _liveInputController.text.trim();
                    if (text.isNotEmpty) {
                      _handleLiveTranslate(text);
                      _liveInputController.clear();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "Type slang to simulate live input...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepOrangeAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    final text = _liveInputController.text.trim();
                    if (text.isNotEmpty) {
                      _handleLiveTranslate(text);
                      _liveInputController.clear();
                      FocusScope.of(context).unfocus();
                    }
                  },
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _liveTranscript.isEmpty
                ? Center(
                    child: Text(
                      "Type or Hold Mic to translate live...",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _liveTranscript.length,
                    itemBuilder: (context, index) {
                      final item = _liveTranscript[index];
                      final text = item['text'] as String;
                      final slangs = List<String>.from(item['slangs'] ?? []);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['original'] != null &&
                                item['original'] != text)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  item['original'],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            _buildHighlightedText(text, slangs),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Microphone specifically for Live Mode
        GestureDetector(
          onLongPressStart: (_) => _startRecording(),
          onLongPressEnd: (_) => _stopRecordingAndProcess(),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.shade400
                        : Colors.deepOrangeAccent,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isListening
                                    ? Colors.red
                                    : Colors.deepOrangeAccent)
                                .withValues(alpha: 0.4),
                        blurRadius: _isListening ? 30 : 15,
                        spreadRadius: _isListening ? 5 : 2,
                      ),
                    ],
                  ),
                  child: _isLoading && !_isListening
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.mic, color: Colors.white, size: 32),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHighlightedText(String text, List<String> slangs) {
    if (slangs.isEmpty)
      return Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 18),
      );

    final pattern = slangs.map((s) => RegExp.escape(s)).join('|');
    final regex = RegExp('($pattern)', caseSensitive: false);
    final parts = text.split(regex);

    List<InlineSpan> spans = [];
    for (final part in parts) {
      final isSlang = slangs.any((s) => s.toLowerCase() == part.toLowerCase());
      if (isSlang) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _onSlangTap(part),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      part,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.search, size: 14, color: Colors.black87),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              height: 1.5,
            ),
          ),
        );
      }
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPillToggle(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isLiveMode ? _buildLiveMode() : _buildLookupMode(),
          ),
        ),
      ],
    );
  }
}
