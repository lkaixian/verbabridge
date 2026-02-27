import 'package:flutter/material.dart';

class MyWordsTab extends StatefulWidget {
  const MyWordsTab({super.key});

  @override
  State<MyWordsTab> createState() => _MyWordsTabState();
}

class _MyWordsTabState extends State<MyWordsTab> {
  // Dummy saved words — will eventually come from Firestore
  final List<Map<String, String>> _savedWords = [
    {
      'word': 'Tapau',
      'analogy':
          'It is like ordering takeaway — imagine pointing at your '
          'favourite Char Kuey Teow and saying "pack it up, I am '
          'bringing this home to enjoy later!"',
      'emoji': '🥡',
      'savedDate': '28 Feb 2026',
    },
    {
      'word': 'Shiok',
      'analogy':
          'Think of biting into a perfectly crispy Roti Canai dipped '
          'in warm dhal on a rainy morning — that feeling of pure '
          'satisfaction is "shiok".',
      'emoji': '😋',
      'savedDate': '27 Feb 2026',
    },
    {
      'word': 'Jio',
      'analogy':
          'It is like when your neighbour knocks on your door and '
          'says "Come lah, we go makan!" — a friendly invitation '
          'to join in on something fun.',
      'emoji': '🤝',
      'savedDate': '26 Feb 2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_savedWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "No saved words yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Swipe right on an analogy card to save it here!",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            "My Vocabulary Book",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "${_savedWords.length} words saved",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 12),

        // Word list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _savedWords.length,
            itemBuilder: (context, index) {
              final item = _savedWords[index];
              return _WordAccordionCard(
                word: item['word'] ?? '',
                analogy: item['analogy'] ?? '',
                emoji: item['emoji'] ?? '📖',
                savedDate: item['savedDate'] ?? '',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WordAccordionCard extends StatefulWidget {
  final String word;
  final String analogy;
  final String emoji;
  final String savedDate;

  const _WordAccordionCard({
    required this.word,
    required this.analogy,
    required this.emoji,
    required this.savedDate,
  });

  @override
  State<_WordAccordionCard> createState() => _WordAccordionCardState();
}

class _WordAccordionCardState extends State<_WordAccordionCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: _isExpanded ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isExpanded
              ? Colors.deepOrangeAccent.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row — always visible
                Row(
                  children: [
                    // Emoji badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Word + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.word,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Saved ${widget.savedDate}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expand/collapse icon
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                // Expanded content — analogy
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cultural Analogy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.analogy,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
