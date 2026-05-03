import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/sound_service.dart';
import '../utils/turkish_collator.dart';

class AuthorPortraitsScreen extends StatefulWidget {
  const AuthorPortraitsScreen({super.key});

  @override
  State<AuthorPortraitsScreen> createState() => _AuthorPortraitsScreenState();
}

class _AuthorPortraitsScreenState extends State<AuthorPortraitsScreen> {
  final _sound = SoundService.instance;
  List<Map<String, dynamic>> _authors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
  }

  Future<void> _loadAuthors() async {
    try {
      final String response =
          await rootBundle.loadString('assets/data/authors.json');
      final data = json.decode(response);
      _authors = List<Map<String, dynamic>>.from(data['authors'] ?? []);

      // Alfabetik sırala (isim başharfine göre)
      _authors.sort((a, b) {
        final nameA = (a['name'] ?? '').toString();
        final nameB = (b['name'] ?? '').toString();
        return compareTurkish(nameA, nameB);
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Yazar verileri yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentAppTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yazar Portreleri',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: currentTheme.primaryColor,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: currentTheme.appBarGradient),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              currentTheme.primaryColor.withOpacity(0.05),
              Colors.white,
              const Color(0xFFFFF8E1),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  )
                : _authors.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Henüz yazar eklenmemiş',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _authors.length,
                        itemBuilder: (context, index) {
                          return _buildAuthorCard(
                              _authors[index], index);
                        },
                      ),
      ),
    );
  }

  Widget _buildAuthorCard(
      Map<String, dynamic> author, int index) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        List<Color> colorPair;
        if (themeProvider.advancedThemeEnabled) {
          // Gelişmiş tema modunda: temaya uygun renkler
          colorPair = themeProvider.currentAppTheme.getCategoryColors(
            index,
            themeProvider.colorVibrancy,
          );
        } else {
          // Normal mod: önceden tanımlı renkler
          final colors = [
            [Colors.indigo.shade600, Colors.indigo.shade800],
            [Colors.teal.shade600, Colors.teal.shade800],
            [Colors.deepOrange.shade600, Colors.deepOrange.shade800],
            [Colors.purple.shade600, Colors.purple.shade800],
            [Colors.brown.shade600, Colors.brown.shade800],
            [Colors.blue.shade600, Colors.blue.shade800],
            [Colors.red.shade600, Colors.red.shade800],
          ];
          colorPair = colors[index % colors.length];
        }
        
        final name = author['name'] ?? 'Bilinmeyen Yazar';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () {
              _sound.playButtonClick();
              // Eğer hamburger menü açıksa kapat
              if (Scaffold.of(context).hasEndDrawer) {
                Navigator.maybePop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showAuthorDetail(author, colorPair);
                });
              } else {
                _showAuthorDetail(author, colorPair);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorPair[0], colorPair[1]],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAuthorDetail(Map<String, dynamic> author, List<Color> colorPair) {
    final name = author['name'] ?? 'Bilinmeyen Yazar';
    final bio = author['bio'] ?? 'Bilgi bulunamadı.';
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width > 500 ? 500 : screenSize.width - 40,
              maxHeight: screenSize.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorPair[0], colorPair[1]],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // İçerik
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      bio,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                // Kapat
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPair[0],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Kapat'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
