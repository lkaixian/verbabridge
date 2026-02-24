import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class QRBridgeTab extends StatefulWidget {
  const QRBridgeTab({super.key});

  @override
  State<QRBridgeTab> createState() => _QRBridgeTabState();
}

class _QRBridgeTabState extends State<QRBridgeTab> {
  // Scanner & Firestore State
  bool _isScanning = true;
  bool _isLoading = false;
  Map<String, dynamic>? _stallData;
  String _statusMessage = "Scan a Kopitiam QR Code";

  // Translation State
  String _selectedStyle = "Gen Alpha";
  String? _translatedMenu;
  bool _isTranslating = false;

  final MobileScannerController _scannerController = MobileScannerController();

  // 1. Fetch from Firestore
  Future<void> _fetchStallMenu(String stallId) async {
    setState(() {
      _isLoading = true;
      _isScanning = false;
      _translatedMenu = null; // Reset translation on new scan
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

  // 2. Translate via FastAPI
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
          // Assuming your core.style returns {"translated": "..."}
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
        // --- 1. SCANNER SECTION ---
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

              // Scanning Overlay
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

        // --- 2. MENU & TRANSLATION SECTION ---
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
                // Header
                Text(
                  _stallData?['name'] ?? "Stall Scanner",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(_statusMessage, style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 24),

                // Data Area (Original vs Translated)
                Expanded(
                  child: _stallData != null
                      ? ListView(
                          children: [
                            // Original Menu Header
                            const Text(
                              "ORIGINAL MENU",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Split Original Menu into Beautiful Cards
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _stallData!['menu_items']
                                  .toString()
                                  .split('\n')
                                  .where((item) => item.trim().isNotEmpty)
                                  .map(
                                    (item) => Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      elevation: 1,
                                      color: Colors.orange.shade50,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: Colors.orange.shade100,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          item.trim(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 20),

                            // Translation Controls
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedStyle,
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

                            // Translated Output
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
                                    const SizedBox(height: 12),

                                    // 🌟 FIX: Split Translated Menu into Beautiful Cards
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: _translatedMenu!
                                          .split('\n')
                                          .where(
                                            (item) => item.trim().isNotEmpty,
                                          )
                                          .map(
                                            (item) => Card(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              elevation: 1,
                                              color: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                side: BorderSide(
                                                  color: Colors
                                                      .deepPurple
                                                      .shade100,
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12.0,
                                                ),
                                                child: Text(
                                                  item.trim(),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
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

                // Reset Button
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

// Simple Custom Painter for the QR Overlay
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
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

    // Background with hole
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

    // Drawing the corners
    final linePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final halfCut = cutOutSize / 2;
    final center = Offset(width / 2, height / 2);

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfCut, center.dy - halfCut + borderLength)
        ..lineTo(center.dx - halfCut, center.dy - halfCut)
        ..lineTo(center.dx - halfCut + borderLength, center.dy - halfCut),
      linePaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfCut - borderLength, center.dy - halfCut)
        ..lineTo(center.dx + halfCut, center.dy - halfCut)
        ..lineTo(center.dx + halfCut, center.dy - halfCut + borderLength),
      linePaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfCut, center.dy + halfCut - borderLength)
        ..lineTo(center.dx - halfCut, center.dy + halfCut)
        ..lineTo(center.dx - halfCut + borderLength, center.dy + halfCut),
      linePaint,
    );

    // Bottom Right
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
