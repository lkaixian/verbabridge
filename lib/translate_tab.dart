import 'package:flutter/material.dart';
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

  // Live transcript entries from API
  final List<Map<String, dynamic>> _liveTranscript = [];

  // Simulated live input text for demo (will be replaced by speech-to-text)
  final TextEditingController _liveInputController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  // ── LOOKUP: Call /generate_analogy API ──
  Future<void> _handleLookup() async {
    final typed = _textController.text.trim();
    if (typed.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.generateAnalogy(
        slangText: typed,
        userGeneration: UserProfile.generation ?? 'Boomer',
        userVibe: UserProfile.dialect ?? 'Standard English',
      );

      if (!mounted) return;

      // Show analogy cards with REAL data from API
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── LIVE: Call /live_translate API ──
  Future<void> _handleLiveTranslate(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final result = await ApiService.liveTranslate(
        text: text,
        userVibe: UserProfile.dialect ?? 'Standard English',
      );

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
          'text': text,
          'slangs': <String>[],
        });
      });
    }
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  void _onSlangTap(String slang) {
    // When tapping a highlighted slang in Live mode, do a lookup via API
    _textController.text = slang;
    _handleLookup();
  }

  // ============================================================
  // BUILD: Pill Toggle
  // ============================================================
  Widget _buildPillToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
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

  // ============================================================
  // BUILD: Lookup Mode UI
  // ============================================================
  Widget _buildLookupMode() {
    return Column(
      children: [
        // Text input field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Type or speak a word / phrase...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
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

        // Translate button — calls API
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_textController.text.trim().isEmpty || _isLoading)
                  ? null
                  : _handleLookup,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
              label: Text(
                _isLoading ? "Translating..." : "Translate",
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
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Hold to Speak microphone button
        Column(
          children: [
            GestureDetector(
              onLongPressStart: (_) {
                setState(() => _isListening = true);
                _pulseController.repeat(reverse: true);
              },
              onLongPressEnd: (_) {
                setState(() => _isListening = false);
                _pulseController.stop();
                _pulseController.reset();
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 100,
                      height: 100,
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
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening ? "Listening..." : "Hold to Speak",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isListening ? Colors.red.shade400 : Colors.grey,
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // Swipe cards placeholder
        Expanded(
          child: Container(
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
                  Icon(Icons.swipe, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "Translation cards will appear here",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ============================================================
  // BUILD: Live Mode UI
  // ============================================================
  Widget _buildLiveMode() {
    return Column(
      children: [
        // Live text input bar (simulates speech input for now)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _liveInputController,
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
              IconButton(
                onPressed: () {
                  final text = _liveInputController.text.trim();
                  if (text.isNotEmpty) {
                    _handleLiveTranslate(text);
                    _liveInputController.clear();
                  }
                },
                icon: const Icon(Icons.send, color: Colors.deepOrangeAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Chat / subtitle transcript area
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
                      "Type a sentence above to see live translation...",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _liveTranscript.length,
                    itemBuilder: (context, index) {
                      final item = _liveTranscript[index];
                      final text = item['text'] as String;
                      final slangs = List<String>.from(item['slangs'] ?? []);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Original text (small, dimmed)
                            if (item['original'] != null &&
                                item['original'] != text)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '💬 ${item['original']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            // Translated text with highlights
                            _buildHighlightedText(text, slangs),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Pulsing button
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.red.shade500
                          : Colors.deepOrangeAccent,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isListening
                                      ? Colors.red
                                      : Colors.deepOrangeAccent)
                                  .withValues(alpha: 0.5),
                          blurRadius: _isListening ? 40 : 20,
                          spreadRadius: _isListening ? 8 : 3,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isListening ? "Stop" : "Listen",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Build text with highlighted slang words
  Widget _buildHighlightedText(String text, List<String> slangs) {
    if (slangs.isEmpty) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 18),
      );
    }

    final pattern = slangs.map((s) => RegExp.escape(s)).join('|');
    final regex = RegExp('($pattern)', caseSensitive: false);
    final parts = text.split(regex);

    List<InlineSpan> spans = [];
    for (final part in parts) {
      final isSlang = slangs.any((s) => s.toLowerCase() == part.toLowerCase());
      if (isSlang) {
        spans.add(
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _onSlangTap(part),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  part,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================
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
