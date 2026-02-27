import 'package:flutter/material.dart';

/// Simple in-memory profile storage — accessible across the app.
/// Can be migrated to SharedPreferences or Firestore later.
class UserProfile {
  static String? generation;
  static String? dialect;
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _selectedGeneration = UserProfile.generation;
  String? _selectedDialect = UserProfile.dialect;
  bool _saved = false;

  final List<Map<String, String>> _generations = [
    {'label': 'Boomer', 'emoji': '📻', 'years': '1946–1964'},
    {'label': 'Gen X', 'emoji': '📼', 'years': '1965–1980'},
    {'label': 'Gen Y', 'emoji': '💿', 'years': '1981–1996'},
    {'label': 'Gen Z', 'emoji': '📱', 'years': '1997–2012'},
  ];

  final List<Map<String, String>> _dialects = [
    {'label': 'Standard English', 'emoji': '🇬🇧'},
    {'label': 'Manglish', 'emoji': '🇲🇾'},
    {'label': 'Penang Hokkien', 'emoji': '🏝️'},
    {'label': 'Cantonese', 'emoji': '🀄'},
    {'label': 'Malay', 'emoji': '🌺'},
  ];

  void _saveProfile() {
    if (_selectedGeneration == null || _selectedDialect == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both your generation and dialect'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Save to static app state
    UserProfile.generation = _selectedGeneration;
    UserProfile.dialect = _selectedDialect;

    setState(() => _saved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Profile saved! $_selectedGeneration • $_selectedDialect',
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Reset saved indicator after a moment
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            "My Profile",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Help our AI understand you better",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          // ── Section 1: My Generation ──
          Text(
            "MY GENERATION",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _generations.map((gen) {
              final isSelected = _selectedGeneration == gen['label'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedGeneration = gen['label']);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepOrangeAccent : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepOrangeAccent
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.deepOrangeAccent.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Text(
                        gen['emoji'] ?? '',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        gen['label'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        gen['years'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // ── Section 2: My Vibe / Dialect ──
          Text(
            "MY VIBE / DIALECT",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _dialects.map((dialect) {
              final isSelected = _selectedDialect == dialect['label'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDialect = dialect['label']);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurple : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepPurple
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.deepPurple.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dialect['emoji'] ?? '',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dialect['label'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 40),

          // ── Save Button ──
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: Icon(_saved ? Icons.check : Icons.save, size: 22),
              label: Text(
                _saved ? "Saved!" : "Save Profile",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved
                    ? Colors.green
                    : Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
