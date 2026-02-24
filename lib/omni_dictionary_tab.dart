import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OmniDictionaryTab extends StatefulWidget {
  const OmniDictionaryTab({super.key});

  @override
  State<OmniDictionaryTab> createState() => _OmniDictionaryTabState();
}

class _OmniDictionaryTabState extends State<OmniDictionaryTab> {
  final TextEditingController _textController = TextEditingController();

  List<dynamic> _results = [];
  bool _isAmbiguous = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _analyzeText() async {
    if (_textController.text.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
      _isAmbiguous = false;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.larmkx.com/process_text'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': _textController.text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isAmbiguous = data['is_ambiguous'] ?? false;
          _results = data['results'] ?? [];
        });
      } else {
        setState(() => _errorMessage = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Network Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDialectCard(String dialect, Map<String, dynamic> data) {
    String originalText = data['hanzi'] ?? data['script'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dialect.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                originalText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "🗣️ ${data['romanization'] ?? '-'}  |  🎵 ${data['tone'] ?? '-'}",
          ),
          const SizedBox(height: 4),
          Text(
            "📖 Literal: ${data['english_meaning'] ?? '-'}",
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Enter Slang, Phrase, or Kopitiam text...",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _analyzeText,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Deep Linguistic Analysis",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: _results.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      "Type a word like 'Mata' or 'Skibidi'\nto see the magic.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final translations =
                          result['translations'] as Map<String, dynamic>? ?? {};

                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isAmbiguous && index == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "⚠️ Multiple Contexts Detected",
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Text(
                                result['title'] ?? 'Translation',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result['description'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const Divider(height: 30, thickness: 1),
                              ...translations.entries.map((entry) {
                                return _buildDialectCard(
                                  entry.key,
                                  entry.value as Map<String, dynamic>,
                                );
                              }),
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
}
