import 'package:flutter/material.dart';
import 'analogy_swipe_cards.dart';

class TranslateTab extends StatefulWidget {
  const TranslateTab({super.key});

  @override
  State<TranslateTab> createState() => _TranslateTabState();
}

class _TranslateTabState extends State<TranslateTab>
    with SingleTickerProviderStateMixin {
  bool _isLiveMode = false; // false = Lookup, true = Live
  bool _isListening = false;

  final TextEditingController _textController = TextEditingController();

  // Placeholder live transcript data with slang words marked
  final List<Map<String, dynamic>> _liveTranscript = [
    {
      'text': 'Eh boss, tapau one teh tarik',
      'slangs': ['tapau', 'teh tarik'],
    },
    {
      'text': 'This one damn shiok lah',
      'slangs': ['shiok', 'lah'],
    },
    {
      'text': 'Walao, the queue so long',
      'slangs': ['Walao'],
    },
    {
      'text': 'Can jio your friend come or not',
      'slangs': ['jio'],
    },
    {
      'text': 'Aiyo, no more nasi lemak already',
      'slangs': ['Aiyo', 'nasi lemak'],
    },
  ];

  // Pulsing animation for the Live button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
    showAnalogyCards(context, slang);
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

        const SizedBox(height: 30),

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
                      "Tap the button below to start listening...",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true, // Text flows upward
                    itemCount: _isListening ? _liveTranscript.length : 0,
                    itemBuilder: (context, index) {
                      // Show in reverse order (newest at bottom)
                      final item =
                          _liveTranscript[_liveTranscript.length - 1 - index];
                      final text = item['text'] as String;
                      final slangs = List<String>.from(item['slangs'] ?? []);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildHighlightedText(text, slangs),
                      );
                    },
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Pulsing "Start Listening" button
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

    // Build regex pattern to match slang words (case insensitive)
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
