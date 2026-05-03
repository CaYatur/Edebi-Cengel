import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/crossword_provider.dart';
import 'providers/multiplayer_provider.dart';
import 'providers/classroom_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/crossword_home_screen.dart';
import 'services/local_storage_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.instance.initialize();
  await AuthService.instance.initialize();
  await SettingsService.instance.initialize();

  // Ses ayarını uygula
  SoundService.instance.enabled = SettingsService.instance.soundEnabled;

  // Tema sağlayıcısını başlat
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Bekleyen senkronizasyon varsa dene
  AuthService.instance.trySyncIfNeeded();

  runApp(CengelBulmacaApp(themeProvider: themeProvider));
}

class CengelBulmacaApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const CengelBulmacaApp({required this.themeProvider, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => CrosswordProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => MultiplayerProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final p = ClassroomProvider();
            p.initialize();
            return p;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Edebi Çengel',
            theme: theme.currentThemeData.copyWith(
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: const CardTheme(
                elevation: 4,
                margin: EdgeInsets.zero,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            home: const _SyncWrapper(child: CrosswordHomeScreen()),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

/// Periyodik olarak bekleyen senkronizasyonu kontrol eden wrapper
class _SyncWrapper extends StatefulWidget {
  final Widget child;
  const _SyncWrapper({required this.child});

  @override
  State<_SyncWrapper> createState() => _SyncWrapperState();
}

class _SyncWrapperState extends State<_SyncWrapper> with WidgetsBindingObserver {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Her 2 dakikada bir bekleyen senkronizasyonu dene
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      AuthService.instance.trySyncIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama tekrar ön plana geldiğinde senkronize et
    if (state == AppLifecycleState.resumed) {
      AuthService.instance.trySyncIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
