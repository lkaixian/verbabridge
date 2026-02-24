import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TextTranslateTab extends StatefulWidget {
  const TextTranslateTab({super.key});

  @override
  State<TextTranslateTab> createState() => _TextTranslateTabState();
}

class _TextTranslateTabState extends State<TextTranslateTab> {
  final TextEditingController _textController = TextEditingController();
  String _selectedStyle = "Gen Alpha";
  String _resultText = "";
  bool _isLoading = false;

  Future<void> _translateText() async {
    if (_textController.text.isEmpty) return;
    
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://api.larmkx.com/translate_style'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': _textController.text,
          'style': _selectedStyle,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _resultText = json.decode(response.body)['translated'] ?? "Success";
        });
      } else {
        setState(() => _resultText = "Server Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _resultText = "Network Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              decoration: const InputDecoration(
                labelText: "Target Vibe",
                border: OutlineInputBorder(),
              ),
              items: [
                "Gen Alpha",
                "Penang Hokkien",
                "Mak Cik Bawang",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedStyle = val!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Enter text to transform...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _translateText,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Translate Vibe", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 30),
            if (_resultText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$_selectedStyle:",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                    const SizedBox(height: 8),
                    Text(_resultText, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}