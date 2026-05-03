import 'package:flutter/material.dart';
import '../models/crossword_word.dart';
import '../services/settings_service.dart';

class CluesListWidget extends StatelessWidget {
  final List<CrosswordWord> acrossWords;
  final List<CrosswordWord> downWords;
  final CrosswordWord? selectedWord;
  final Set<String> completedWordIds;
  final Function(CrosswordWord)? onClueTap;

  const CluesListWidget({
    super.key,
    required this.acrossWords,
    required this.downWords,
    this.selectedWord,
    this.completedWordIds = const {},
    this.onClueTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            child: TabBar(
              labelColor: Colors.blue.shade800,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue.shade800,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 4),
                      Text('Yatay (${acrossWords.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_downward, size: 16),
                      const SizedBox(width: 4),
                      Text('Dikey (${downWords.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCluesList(acrossWords, settings),
                _buildCluesList(downWords, settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCluesList(List<CrosswordWord> words, SettingsService settings) {
    if (words.isEmpty) {
      return Center(
        child: Text(
          'Bu yönde ipucu yok',
          style: TextStyle(color: Colors.grey, fontSize: 14 * settings.fontSize),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        bool isSelected = selectedWord?.id == word.id;
        bool isCompleted = completedWordIds.contains(word.id);

        return Card(
          color: isSelected
              ? Colors.blue.shade100
              : isCompleted
                  ? Colors.green.shade50
                  : null,
          elevation: isSelected ? 4 : 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () => onClueTap?.call(word),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green
                          : isSelected
                              ? Colors.blue
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        word.number.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12 * settings.fontSize,
                          color: isCompleted || isSelected
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.question,
                          style: TextStyle(
                            fontSize: 14 * settings.fontSize,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted ? Colors.grey : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${word.length} harf',
                          style: TextStyle(
                            fontSize: 12 * settings.fontSize,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
