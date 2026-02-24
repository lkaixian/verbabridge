import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ImageTranslateTab extends StatefulWidget {
  const ImageTranslateTab({super.key});

  @override
  State<ImageTranslateTab> createState() => _ImageTranslateTabState();
}

class _ImageTranslateTabState extends State<ImageTranslateTab> {
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _apiData;
  String _selectedStyle = "Gen Alpha";

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _apiData = null; // Reset previous data
      });
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.larmkx.com/process_image'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', _image!.path),
      );
      request.fields['style'] = _selectedStyle;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() => _apiData = json.decode(response.body));
      } else {
        _showError("Server Error", "Failed to process image.");
      }
    } catch (e) {
      _showError("Network Error", e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String title, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("$title: $message")));
  }

  // THE BOTTOM SHEET POPUP
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
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              const Text(
                "Translated Vibe",
                style: TextStyle(
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
              const SizedBox(height: 20),
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
        // Top Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStyle,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: ["Gen Alpha", "Penang Hokkien", "Mak Cik Bawang"]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStyle = val!),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, size: 30),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              IconButton(
                icon: const Icon(Icons.image, size: 30),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),

        // Interactive Image Canvas
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _apiData != null
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // Math to scale the Python coordinates to the Phone Screen
                    double imgWidth = _apiData!['width'].toDouble();
                    double imgHeight = _apiData!['height'].toDouble();

                    // Calculate scale factors (assuming BoxFit.contain)
                    double scale = constraints.maxWidth / imgWidth;
                    if (imgHeight * scale > constraints.maxHeight) {
                      scale = constraints.maxHeight / imgHeight;
                    }

                    double renderedWidth = imgWidth * scale;
                    double renderedHeight = imgHeight * scale;

                    // Center offsets
                    double offsetX = (constraints.maxWidth - renderedWidth) / 2;
                    double offsetY =
                        (constraints.maxHeight - renderedHeight) / 2;

                    List<dynamic> items = _apiData!['items'];
                    String base64Img = _apiData!['remixed_image']
                        .split(',')
                        .last;

                    return Stack(
                      children: [
                        // 1. The Base Image
                        Center(
                          child: Image.memory(
                            base64Decode(base64Img),
                            fit: BoxFit.contain,
                          ),
                        ),

                        // 2. The Interactive Hotspots
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
                                // Light highlight so users know it's tappable
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  border: Border.all(
                                    color: Colors.blueAccent,
                                    width: 2,
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
              ? Image.file(_image!)
              : const Center(
                  child: Text(
                    "Snap a menu to start!",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
        ),

        // Bottom Action Button
        if (_image != null && _apiData == null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                ),
                // FIX: Changed onTap to onPressed right here 👇
                onPressed: _processImage,
                child: const Text(
                  "Decode Image",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
