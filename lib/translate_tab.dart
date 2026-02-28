import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'services/api_service.dart';
import 'profile_tab.dart';
import 'analogy_swipe_cards.dart';

class TranslateTab extends StatefulWidget {
  const TranslateTab({super.key});

  @override
  State<TranslateTab> createState() => _TranslateTabState();
}

class _TranslateTabState extends State<TranslateTab>
    with TickerProviderStateMixin {
  bool _isLiveMode = false;
  bool _isListening = false;
  bool _isLoading = false;

  // Last lookup result
  Map<String, dynamic>? _lastResult;

  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _liveTranscript = [];
  final TextEditingController _liveInputController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Audio Recording Instances
  late final AudioRecorder _audioRecorder;
  String? _audioPath;

  String _preferredLanguage = 'en';

  @override
  void initState() {
    super.initState();
    final String defaultLocale = Platform.localeName.split('_')[0];
    if (defaultLocale == 'zh') {
      _preferredLanguage = 'ch';
    } else if (defaultLocale == 'ms') {
      _preferredLanguage = 'ms';
    } else {
      _preferredLanguage = 'en';
    }
    _audioRecorder = AudioRecorder();
    _textController.addListener(() => setState(() {}));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _liveInputController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ── Gradient helpers ──
  static const _primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _warmGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFE84393)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
        preferredLanguage: _preferredLanguage,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final analogies = List<String>.from(result['analogies'] ?? []);
      final literal = result['literal_translation'] ?? '';
      final slangDetected = result['slang_detected'] ?? typed;
      final warning = result['ambiguity_warning'];

      setState(() {
        _lastResult = {
          'slang': slangDetected,
          'literal': literal,
          'analogies': analogies,
          'warning': warning,
        };
      });

      showAnalogyCardsFromApi(
        context,
        slangDetected,
        literal,
        analogies,
        warning,
        _preferredLanguage,
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
        preferredLanguage: _preferredLanguage,
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
      _isLoading = true;
    });

    try {
      final String? path = await _audioRecorder.stop();
      if (path != null) {
        if (_isLiveMode) {
          setState(() {
            _liveTranscript.insert(0, {
              'original': '🎙️ Processing audio...',
              'text': '...',
              'slangs': <String>[],
            });
          });

          final result = await ApiService.liveTranslateAudio(
            filePath: path,
            userVibe: UserProfile.dialect ?? 'Standard English',
            preferredLanguage: _preferredLanguage,
          );

          if (!mounted) return;

          final originalTranscription =
              result['original_transcription'] ?? 'Audio recognized';
          final translatedText = result['translated_text'] ?? '';
          final slangs = List<String>.from(result['highlight_words'] ?? []);

          setState(() {
            _liveTranscript[0] = {
              'original': '🎙️ $originalTranscription',
              'text': translatedText,
              'slangs': slangs,
            };
          });
        } else {
          final result = await ApiService.generateAnalogyAudio(
            filePath: path,
            userGeneration: UserProfile.generation ?? 'Boomer',
            userVibe: UserProfile.dialect ?? 'Standard English',
            preferredLanguage: _preferredLanguage,
          );

          if (!mounted) return;

          final slangDetected = result['slang_detected'] ?? 'Audio Input';
          final literal = result['literal_translation'] ?? '';
          final analogies = List<String>.from(result['analogies'] ?? []);
          final warning = result['ambiguity_warning'];

          _textController.text = slangDetected;
          showAnalogyCardsFromApi(
            context,
            slangDetected,
            literal,
            analogies,
            warning,
            _preferredLanguage,
          );
        }

        try {
          await File(path).delete();
        } catch (e) {
          debugPrint("Failed to delete temp file: $e");
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
      if (_isLiveMode && _liveTranscript.isNotEmpty) {
        setState(() => _liveTranscript.removeAt(0));
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

  // ═══════════════════════════════════════════
  //  REDESIGNED WIDGETS
  // ═══════════════════════════════════════════

  Widget _buildLanguageSelector() {
    final languages = [
      {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
      {'code': 'ch', 'label': 'Chinese', 'flag': '🇨🇳'},
      {'code': 'ms', 'label': 'Malay', 'flag': '🇲🇾'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: languages.map((lang) {
                final isSelected = _preferredLanguage == lang['code'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _preferredLanguage = lang['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected ? _primaryGradient : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(lang['flag']!, style: const TextStyle(fontSize: 16)),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            lang['label']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildToggleItem(
            label: "Lookup",
            icon: Icons.search_rounded,
            isActive: !_isLiveMode,
            onTap: () => setState(() => _isLiveMode = false),
          ),
          _buildToggleItem(
            label: "Live",
            icon: Icons.bolt_rounded,
            isActive: _isLiveMode,
            onTap: () => setState(() => _isLiveMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isActive ? _primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isActive ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton({double size = 90}) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecordingAndProcess(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isListening
                    ? const LinearGradient(
                        colors: [Color(0xFFE84393), Color(0xFFFF6B6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : _primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening
                            ? const Color(0xFFE84393)
                            : const Color(0xFFFF6B35))
                        .withValues(
                            alpha: _isListening
                                ? _glowAnimation.value
                                : 0.25),
                    blurRadius: _isListening ? 35 : 20,
                    spreadRadius: _isListening ? 8 : 2,
                  ),
                ],
              ),
              child: _isLoading && !_isListening
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: size * 0.42,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLookupMode() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          _buildLanguageSelector(),

          // ── Text Input ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLookup(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "Type slang or hold mic to speak...",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF6B35),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(22),
                  suffixIcon: _textController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () => _textController.clear(),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Translate Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: (_textController.text.trim().isEmpty || _isLoading)
                      ? LinearGradient(
                          colors: [
                            Colors.grey.shade300,
                            Colors.grey.shade300,
                          ],
                        )
                      : _warmGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (_textController.text.trim().isNotEmpty &&
                          !_isLoading)
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed:
                      (_textController.text.trim().isEmpty || _isLoading)
                          ? null
                          : _handleLookup,
                  icon: _isLoading && !_isListening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 22),
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
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white60,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // ── Microphone ──
          Column(
            children: [
              _buildMicButton(size: 90),
              const SizedBox(height: 14),
              Text(
                _isListening
                    ? "Recording..."
                    : (_isLoading ? "Processing Audio..." : "Hold to Speak"),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isListening
                      ? const Color(0xFFE84393)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // ── Last Result / Empty State ──
          _lastResult != null
              ? GestureDetector(
                  onTap: () {
                    final r = _lastResult!;
                    showAnalogyCardsFromApi(
                      context,
                      r['slang'],
                      r['literal'],
                      List<String>.from(r['analogies']),
                      r['warning'],
                      _preferredLanguage,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF3E0), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LAST SEARCH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _lastResult!['slang'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastResult!['literal'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((_lastResult!['analogies'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            (_lastResult!['analogies'] as List).first,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Container(
                  height: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade50,
                        Colors.white,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe_rounded,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Translation cards will appear here",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Type a word or speak to get started",
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 12,
                          ),
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
        _buildLanguageSelector(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
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
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: _primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: _liveTranscript.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 40,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Type or hold mic to translate live...",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.6),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['original'] != null &&
                                item['original'] != text)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  item['original'],
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
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
        const SizedBox(height: 14),

        // Microphone for Live Mode
        _buildMicButton(size: 70),
        const SizedBox(height: 14),
      ],
    );
  }

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
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _onSlangTap(part),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF9A825), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFF9A825).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      part,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.search, size: 14, color: Colors.white70),
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
