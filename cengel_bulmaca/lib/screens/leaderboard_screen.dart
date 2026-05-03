import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';

/// Sıralama Tablosu Ekranı
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  List<dynamic> _leaderboard = [];
  int _totalPlayers = 0;
  bool _isLoading = true;
  String? _error;
  final _sound = SoundService.instance;
  late AnimationController _listAnimCtrl;
  String _selectedPeriod = 'all'; // 'all', 'monthly', 'weekly'
  int? _expandedIndex; // Genişletilmiş oyuncu kartı

  @override
  void initState() {
    super.initState();
    _listAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    if (SettingsService.instance.animationsEnabled) {
      // forward() will be called later when data loads
    } else {
      _listAnimCtrl.value = 1.0;
    }
    _loadLeaderboard();
    _sound.playNavigation();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.instance.getLeaderboard(limit: 50, period: _selectedPeriod);

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      setState(() {
        _leaderboard = response.data!['leaderboard'] ?? [];
        _totalPlayers = response.data!['totalPlayers'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.errorMessage ?? 'Sıralama yüklenemedi';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _listAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;
        
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Sıralama Tablosu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: currentTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: currentTheme.appBarGradient,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLeaderboard,
                tooltip: 'Yenile',
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sıralama yükleniyor...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLeaderboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Henüz sıralama verisi yok',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk çözen sen ol!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final currentUserId = AuthService.instance.userId;

    return Column(
      children: [
        // Dönem filtresi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: primaryColor.withOpacity(0.05),
          child: Row(
            children: [
              _buildPeriodChip('all', 'Tüm Zamanlar', Icons.all_inclusive, primaryColor),
              const SizedBox(width: 8),
              _buildPeriodChip('monthly', 'Bu Ay', Icons.calendar_month, primaryColor),
              const SizedBox(width: 8),
              _buildPeriodChip('weekly', 'Bu Hafta', Icons.date_range, primaryColor),
            ],
          ),
        ),
        // Toplam oyuncu sayısı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.amber.shade50,
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'Toplam $_totalPlayers oyuncu',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _getPeriodLabel(),
                style: TextStyle(color: Colors.amber.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
        // Sıralama listesi
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadLeaderboard,
            child: ListView.builder(
              itemCount: _leaderboard.length,
              padding: const EdgeInsets.only(bottom: 16),
              itemBuilder: (context, index) {
                final entry = _leaderboard[index];
                final isCurrentUser = currentUserId != null && entry['id'] == currentUserId;
                return _buildAnimatedLeaderboardItem(entry, index, isCurrentUser);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String period, String label, IconData icon, Color primaryColor) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedPeriod != period) {
            _sound.playButtonClick();
            setState(() {
              _selectedPeriod = period;
              _expandedIndex = null;
            });
            _loadLeaderboard();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'monthly': return 'Aylık sıralama';
      case 'weekly': return 'Haftalık sıralama';
      default: return 'Tüm zamanlar';
    }
  }

  IconData _getMedalIcon(int position) {
    switch (position) {
      case 1:
      case 2:
      case 3:
        return Icons.emoji_events;
      default:
        return Icons.circle;
    }
  }

  Color _getMedalColor(int position) {
    switch (position) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRankIconForLeaderboard(String rankStr) {
    switch (rankStr) {
      case 'crown':
        return Icons.grade;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'target':
        return Icons.gps_fixed;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'library_books':
        return Icons.library_books;
      case 'edit':
        return Icons.edit_note;
      case 'sprout':
        return Icons.nature;
      default:
        return Icons.nature;
    }
  }


  Widget _buildAnimatedLeaderboardItem(Map<String, dynamic> entry, int index, bool isCurrentUser) {
    if (!SettingsService.instance.animationsEnabled) {
      return _buildLeaderboardItem(entry, index, isCurrentUser);
    }
    final delay = index * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(40 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: _buildLeaderboardItem(entry, index, isCurrentUser),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> entry, int index, bool isCurrentUser) {
    final position = entry['position'] ?? (index + 1);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isExpanded = _expandedIndex == index;
    
    // İlk 3 için özel renk
    Color? bgColor;
    
    if (position == 1) {
      bgColor = Colors.amber.shade50;
    } else if (position == 2) {
      bgColor = Colors.grey.shade100;
    } else if (position == 3) {
      bgColor = Colors.orange.shade50;
    }

    return GestureDetector(
      onTap: () {
        _sound.playButtonClick();
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isCurrentUser ? primaryColor.withOpacity(0.08) : bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isCurrentUser
              ? Border.all(color: primaryColor, width: 2)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: position <= 3
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: SizedBox(
                width: 40,
                child: Center(
                  child: position <= 3
                      ? Icon(_getMedalIcon(position), size: 32, color: _getMedalColor(position))
                      : Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '$position',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    _getRankIconForLeaderboard(entry['rankIcon'] ?? 'sprout'),
                    size: 24,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry['displayName'] ?? entry['username'] ?? '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isCurrentUser ? primaryColor : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          entry['rank'] ?? 'Yeni Başlayan',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 2),
                      Text(
                        '${entry['totalScore'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry['totalPuzzlesCompleted'] ?? 0} bulmaca',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Genişletilmiş detay bölümü
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedDetails(entry, primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> entry, Color primaryColor) {
    final totalScore = entry['totalScore'] ?? 0;
    final puzzlesCompleted = entry['totalPuzzlesCompleted'] ?? 0;
    final avgScore = puzzlesCompleted > 0 ? (totalScore / puzzlesCompleted).round() : 0;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildStatDetail(Icons.star, 'Toplam Puan', '$totalScore', Colors.amber),
              _buildStatDetail(Icons.extension, 'Bulmaca', '$puzzlesCompleted', primaryColor),
              _buildStatDetail(Icons.analytics, 'Ort. Puan', '$avgScore', Colors.blue),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatDetail(
                _getRankIconForLeaderboard(entry['rankIcon'] ?? 'sprout'),
                'Rütbe',
                entry['rank'] ?? 'Yeni',
                Colors.purple,
              ),
              _buildStatDetail(Icons.military_tech, 'Seviye', '${entry['level'] ?? 1}', Colors.orange),
              _buildStatDetail(Icons.workspace_premium, 'Rozet', '${entry['earnedBadgeCount'] ?? 0}', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDetail(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
