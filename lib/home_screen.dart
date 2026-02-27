import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Added for QR Scanner
import 'services/auth_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // The 4 Main Features of VerbaBridge
  final List<Widget> _tabs = [
    const ARScannerTab(),
    const OmniDictionaryTab(), // NEW: Deep Analysis
    const VibeTextTab(),
    const QRBridgeTab(), // NEW: Real QR Scanner
  ];

  @override
  Widget build(BuildContext context) {
    final bool isGuest = AuthService.isGuest.value;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Fixes keyboard overflow globally
      appBar: AppBar(
        title: const Text(
          "VerbaBridge",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrangeAccent,
        foregroundColor: Colors.white,
        actions: isGuest
            ? [
                // Guest: show Sign In button
                TextButton.icon(
                  onPressed: () async {
                    await AuthService().signInWithGoogle();
                  },
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text(
                    "Sign In",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : [
                // Signed-in: show History + Logout
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => AuthService().signOut(),
                ),
              ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepOrangeAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // CRITICAL for 4+ items
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: "AR Canvas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Omni-Dict",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: "Vibe Text",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "QR Menu",
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: THE INTERACTIVE AR CANVAS (Image Processing)
// ============================================================================
class ARScannerTab extends StatefulWidget {
  const ARScannerTab({super.key});

  @override
  State<ARScannerTab> createState() => _ARScannerTabState();
}

class _ARScannerTabState extends State<ARScannerTab> {
  File? _image;
  String _selectedStyle = "Gen Alpha";
  bool _isLoading = false;
  Map<String, dynamic>? _apiData;

  final String apiUrl = "https://api.larmkx.com/process_image";
  final List<String> _styles = [
    "Gen Alpha",
    "Penang Hokkien",
    "Mak Cik Bawang",
  ];

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _apiData = null; // Reset canvas on new image
      });
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', _image!.path),
      );
      request.fields['style'] = _selectedStyle;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _apiData = data);
        _saveToHistory(data); // Silently save to Firebase
      } else {
        _showError("Server Error ${response.statusCode}", response.body);
      }
    } catch (e) {
      _showError("Network Error", e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> data) async {
    // Skip history saving for guest users
    if (AuthService.isGuest.value) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || data['item_count'] == 0) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .add({
          'original': data['original_text'] ?? 'Interactive Image',
          'translated': data['translated_text'] ?? 'Viewed AR Canvas',
          'style': _selectedStyle,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  void _showError(String title, String details) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: SingleChildScrollView(child: Text(details)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  void _showTranslationDetails(String original, String translated) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Original Text",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                original,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),
              Text(
                "Translated ($_selectedStyle)",
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                translated,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. TOP CONTROLS
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStyle,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items: _styles
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStyle = val!),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, size: 28),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              IconButton(
                icon: const Icon(Icons.image, size: 28),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),

        // 2. INTERACTIVE CANVAS DISPLAY
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.grey[900],
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrangeAccent,
                    ),
                  )
                : _apiData != null
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      double imgWidth = _apiData!['width'].toDouble();
                      double imgHeight = _apiData!['height'].toDouble();

                      double scaleX = constraints.maxWidth / imgWidth;
                      double scaleY = constraints.maxHeight / imgHeight;
                      double scale = min(scaleX, scaleY);

                      double renderedWidth = imgWidth * scale;
                      double renderedHeight = imgHeight * scale;

                      double offsetX =
                          (constraints.maxWidth - renderedWidth) / 2;
                      double offsetY =
                          (constraints.maxHeight - renderedHeight) / 2;

                      List<dynamic> items = _apiData!['items'] ?? [];
                      String base64Img = _apiData!['remixed_image']
                          .toString()
                          .split(',')
                          .last;

                      return Stack(
                        children: [
                          Center(
                            child: Image.memory(
                              base64Decode(base64Img),
                              fit: BoxFit.contain,
                            ),
                          ),
                          ...items.map((item) {
                            var box = item['box'];
                            double left = offsetX + (box['xmin'] * scale);
                            double top = offsetY + (box['ymin'] * scale);
                            double width = (box['xmax'] - box['xmin']) * scale;
                            double height = (box['ymax'] - box['ymin']) * scale;

                            return Positioned(
                              left: left,
                              top: top,
                              width: width,
                              height: height,
                              child: GestureDetector(
                                onTap: () => _showTranslationDetails(
                                  item['original'],
                                  item['translated'],
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  )
                : _image != null
                ? Image.file(_image!, fit: BoxFit.contain)
                : const Center(
                    child: Text(
                      "Snap a Kopitiam menu to begin!",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
          ),
        ),

        // 3. ACTION BUTTON
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
              ),
              onPressed: _image == null || _isLoading ? null : _processImage,
              child: const Text(
                "Decode Image",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 2: OMNI DICTIONARY (Deep Linguistic Analysis)
// ============================================================================
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

// ============================================================================
// TAB 3: VIBE TEXT ENGINE (For direct text translation without camera)
// ============================================================================
class VibeTextTab extends StatefulWidget {
  const VibeTextTab({super.key});

  @override
  State<VibeTextTab> createState() => _VibeTextTabState();
}

class _VibeTextTabState extends State<VibeTextTab> {
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
        setState(
          () => _resultText =
              json.decode(response.body)['translated'] ?? "Success",
        );
      } else {
        setState(
          () => _resultText = "Error: Server returned ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() => _resultText = "Network Error: Check Tunnel");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Wrapped with SingleChildScrollView to prevent Keyboard overflow
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedStyle,
              decoration: const InputDecoration(
                labelText: "Target Culture/Vibe",
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
                hintText: "Type Kopitiam slang or menu items here...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _translateText,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.deepOrangeAccent,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text(
                      "Translate Vibe",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            const SizedBox(height: 30),
            if (_resultText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  _resultText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 4: QR MENU BRIDGE (Mobile Scanner)
// ============================================================================
class QRBridgeTab extends StatefulWidget {
  const QRBridgeTab({super.key});

  @override
  State<QRBridgeTab> createState() => _QRBridgeTabState();
}

class _QRBridgeTabState extends State<QRBridgeTab> {
  bool _isScanning = true;
  bool _isLoading = false;
  Map<String, dynamic>? _stallData;
  String _statusMessage = "Scan a Kopitiam QR Code";

  String _selectedStyle = "Gen Alpha";
  String? _translatedMenu;
  bool _isTranslating = false;

  final MobileScannerController _scannerController = MobileScannerController();

  Future<void> _fetchStallMenu(String stallId) async {
    setState(() {
      _isLoading = true;
      _isScanning = false;
      _translatedMenu = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stalls')
          .doc(stallId)
          .get();

      if (snapshot.exists) {
        setState(() {
          _stallData = snapshot.data();
          _statusMessage = "Menu Loaded";
        });
      } else {
        setState(() => _statusMessage = "Stall '$stallId' not found.");
      }
    } catch (e) {
      setState(() => _statusMessage = "Network Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _translateMenuText(String rawMenu) async {
    setState(() => _isTranslating = true);

    try {
      final response = await http.post(
        Uri.parse('https://api.larmkx.com/translate_style'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': rawMenu, 'style': _selectedStyle}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _translatedMenu =
              json.decode(response.body)['translated'] ?? "Translation failed.";
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Network Error: $e")));
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
      _stallData = null;
      _translatedMenu = null;
      _statusMessage = "Scan a Kopitiam QR Code";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              if (_isScanning)
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final barcode = capture.barcodes.first;
                    if (barcode.rawValue != null) {
                      _fetchStallMenu(barcode.rawValue!);
                    }
                  },
                )
              else
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.orange)
                        : const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 80,
                          ),
                  ),
                ),
              if (_isScanning)
                Container(
                  decoration: ShapeDecoration(
                    shape: QrScannerOverlayShape(
                      borderColor: Colors.orange,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 250,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _stallData?['name'] ?? "Stall Scanner",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(_statusMessage, style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 24),
                Expanded(
                  child: _stallData != null
                      ? ListView(
                          children: [
                            const Text(
                              "ORIGINAL MENU",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _stallData!['menu_items'].toString(),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedStyle,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      labelText: "Translate Vibe To",
                                    ),
                                    items:
                                        [
                                              "Gen Alpha",
                                              "Penang Hokkien",
                                              "Mak Cik Bawang",
                                            ]
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(s),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedStyle = val!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 20,
                                    ),
                                  ),
                                  onPressed: _isTranslating
                                      ? null
                                      : () => _translateMenuText(
                                          _stallData!['menu_items'].toString(),
                                        ),
                                  child: _isTranslating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome),
                                ),
                              ],
                            ),
                            if (_translatedMenu != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.deepPurple.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$_selectedStyle Translation:",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _translatedMenu!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        )
                      : Center(
                          child: Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                        ),
                ),
                if (!_isScanning && !_isLoading) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _resetScanner,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      "Scan Another Stall",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// UI HELPER: Custom Painter for the QR Overlay
// ============================================================================
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 10,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;

    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(width / 2, height / 2),
              width: cutOutSize,
              height: cutOutSize,
            ),
            Radius.circular(borderRadius),
          ),
        ),
      ),
      paint,
    );

    final linePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final halfCut = cutOutSize / 2;
    final center = Offset(width / 2, height / 2);

    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfCut, center.dy - halfCut + borderLength)
        ..lineTo(center.dx - halfCut, center.dy - halfCut)
        ..lineTo(center.dx - halfCut + borderLength, center.dy - halfCut),
      linePaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfCut - borderLength, center.dy - halfCut)
        ..lineTo(center.dx + halfCut, center.dy - halfCut)
        ..lineTo(center.dx + halfCut, center.dy - halfCut + borderLength),
      linePaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfCut, center.dy + halfCut - borderLength)
        ..lineTo(center.dx - halfCut, center.dy + halfCut)
        ..lineTo(center.dx - halfCut + borderLength, center.dy + halfCut),
      linePaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfCut - borderLength, center.dy + halfCut)
        ..lineTo(center.dx + halfCut, center.dy + halfCut)
        ..lineTo(center.dx + halfCut, center.dy + halfCut - borderLength),
      linePaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
