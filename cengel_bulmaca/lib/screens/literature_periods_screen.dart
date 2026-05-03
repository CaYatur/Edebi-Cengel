import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/sound_service.dart';
import '../utils/turkish_collator.dart';

class LiteraturePeriodsScreen extends StatefulWidget {
  const LiteraturePeriodsScreen({super.key});

  @override
  State<LiteraturePeriodsScreen> createState() =>
      _LiteraturePeriodsScreenState();
}

class _LiteraturePeriodsScreenState extends State<LiteraturePeriodsScreen> {
  final _sound = SoundService.instance;
  List<Map<String, dynamic>> _periods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    try {
      final String response =
          await rootBundle.loadString('assets/data/literature_periods.json');
      final data = json.decode(response);
      _periods = List<Map<String, dynamic>>.from(data['periods'] ?? []);

      _periods.sort((a, b) {
        final titleA = (a['title'] ?? '').toString();
        final titleB = (b['title'] ?? '').toString();
        return compareTurkish(titleA, titleB);
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Edebiyat dönemleri yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentAppTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edebiyat Dönemleri',
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
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : _periods.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Henüz dönem eklenmemiş',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _periods.length,
                        itemBuilder: (context, index) {
                          return _buildPeriodCard(
                              _periods[index], index);
                        },
                      ),
      ),
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> period, int index) {
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
        
        final title = (period['title'] ?? '').toString().trim();

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
                  _showPeriodDetail(period, colorPair);
                });
              } else {
                _showPeriodDetail(period, colorPair);
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
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Başlıksız Dönem' : title,
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

  void _showPeriodDetail(Map<String, dynamic> period, List<Color> colorPair) {
    final title = (period['title'] ?? 'Edebiyat Dönemi').toString();
    final content = (period['content'] ?? 'İçerik bulunamadı.').toString();
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [colorPair[0], colorPair[1]]),
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
                        child: const Icon(Icons.menu_book_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
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
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      content,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ),
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
