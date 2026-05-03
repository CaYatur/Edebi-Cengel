import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/url_helper.dart';
import 'api_service.dart';
import 'classroom_service.dart';
import 'local_storage_service.dart';

/// Kimlik doğrulama servisi - Giriş, kayıt, oturum yönetimi
class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'auth_username';
  static const String _displayNameKey = 'auth_display_name';
  static const String _userIdKey = 'auth_user_id';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _pendingSyncKey = 'pending_sync';

  static AuthService? _instance;
  SharedPreferences? _prefs;
  final LocalStorageService _storageService = LocalStorageService.instance;

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _username;
  String? _displayName;
  String? _userId;
  String? _errorMessage;
  bool _hasPendingSync = false;
  bool _cayadevCancelled = false;

  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get userId => _userId;
  String? get errorMessage => _errorMessage;
  bool get hasPendingSync => _hasPendingSync;
  String? get token => _prefs?.getString(_tokenKey);

  /// Servisi başlat, kayıtlı token varsa yükle
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _isLoggedIn = _prefs?.getBool(_isLoggedInKey) ?? false;
    _username = _prefs?.getString(_usernameKey);
    _displayName = _prefs?.getString(_displayNameKey);
    _userId = _prefs?.getString(_userIdKey);
    _hasPendingSync = _prefs?.getBool(_pendingSyncKey) ?? false;

    final token = _prefs?.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      ApiService.instance.setToken(token);
    }

    notifyListeners();
  }

  /// Token ve kullanıcı bilgilerini kaydet
  Future<void> _saveUserData({
    required String token,
    required String username,
    required String displayName,
    required String userId,
  }) async {
    await _prefs?.setString(_tokenKey, token);
    await _prefs?.setString(_usernameKey, username);
    await _prefs?.setString(_displayNameKey, displayName);
    await _prefs?.setString(_userIdKey, userId);
    await _prefs?.setBool(_isLoggedInKey, true);

    ApiService.instance.setToken(token);
    _isLoggedIn = true;
    _username = username;
    _displayName = displayName;
    _userId = userId;
    _errorMessage = null;
  }

  /// Kayıt ol
  Future<bool> register({
    required String username,
    required String password,
    String? displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiService.instance.register(
      username: username,
      password: password,
      displayName: displayName,
    );

    _isLoading = false;

    if (response.isSuccess && response.data != null) {
      await _saveUserData(
        token: response.data!['token'],
        username: response.data!['user']['username'],
        displayName: response.data!['user']['displayName'],
        userId: response.data!['user']['id'],
      );

      // Sunucudan kullanıcı profilini ve istatistiklerini yükle
      final profileResponse = await ApiService.instance.getProfile();
      if (profileResponse.isSuccess && profileResponse.data != null) {
        // Sunucu istatistiklerini yerel saklama alanına senkronize et
        final statsData = profileResponse.data!['stats'];
        if (statsData != null) {
          await _storageService.syncStatsFromServer(statsData);
        }
      }

      // Mevcut yerel istatistikleri sunucuya gönder
      await _syncLocalStatsToServer();

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.errorMessage;
      notifyListeners();
      return false;
    }
  }

  /// Giriş yap
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiService.instance.login(
      username: username,
      password: password,
    );

    _isLoading = false;

    if (response.isSuccess && response.data != null) {
      await _saveUserData(
        token: response.data!['token'],
        username: response.data!['user']['username'],
        displayName: response.data!['user']['displayName'],
        userId: response.data!['user']['id'],
      );

      // Sunucudan kullanıcı profilini ve istatistiklerini yükle
      final profileResponse = await ApiService.instance.getProfile();
      if (profileResponse.isSuccess && profileResponse.data != null) {
        // Sunucu istatistiklerini yerel saklama alanına senkronize et
        final statsData = profileResponse.data!['stats'];
        if (statsData != null) {
          await _storageService.syncStatsFromServer(statsData);
        }
      }

      // Yerel istatistikleri sunucuya senkronize et (eğer oynanmış olup sunucuda yoksa)
      await _syncLocalStatsToServer();

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.errorMessage;
      notifyListeners();
      return false;
    }
  }

  /// Aktif olan CaYaDev OAuth giriş akışını iptal eder.
  /// Polling döngüsü sıradaki yoklamada bayrağı görüp duracak.
  void cancelCayadevLogin() {
    _cayadevCancelled = true;
  }

  /// CaYaDev OAuth ile giriş yap
  /// Tarayıcıda yetkilendirme sayfasını açar, sunucu callback'inden gelen
  /// JWT'yi poll ile bekler. Kullanıcı [cancelCayadevLogin] çağırırsa durur.
  /// [onWaitingForBrowser] tarayıcı açıldıktan sonra UI'a haber vermek için.
  Future<bool> loginWithCayadev({
    void Function()? onWaitingForBrowser,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _cayadevCancelled = false;
    notifyListeners();

    try {
      // 1) Sunucudan state ve authUrl al
      final startRes = await ApiService.instance.startCayadevOAuth();
      if (!startRes.isSuccess || startRes.data == null) {
        _errorMessage = startRes.errorMessage ?? 'CaYaDev girişi başlatılamadı';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final String state = startRes.data!['state'];
      final String authUrl = startRes.data!['authUrl'];

      // 2) Tarayıcıda aç
      // Web'de url_launcher_web MissingPluginException fırlatabilir;
      // bu yüzden web'de dart:html window.open kullanıyoruz.
      final uri = Uri.parse(authUrl);
      bool launched;
      if (kIsWeb) {
        launched = await openUrlInBrowser(authUrl);
      } else {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        _errorMessage = 'Tarayıcı açılamadı';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      onWaitingForBrowser?.call();

      // 3) Sonucu poll et (toplam ~5 dakika, 2 saniyede bir)
      const maxAttempts = 150; // 150 * 2s = 300s
      for (int i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(seconds: 2));

        if (_cayadevCancelled) {
          _errorMessage = null; // sessizce iptal
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final pollRes = await ApiService.instance.pollCayadevOAuth(state);

        if (_cayadevCancelled) {
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (!pollRes.isSuccess) {
          // 404 veya error -> dur
          _errorMessage = pollRes.errorMessage ?? 'Giriş başarısız';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final status = pollRes.data?['status'];
        if (status == 'completed') {
          final user = pollRes.data!['user'];
          await _saveUserData(
            token: pollRes.data!['token'],
            username: user['username'],
            displayName: user['displayName'] ?? user['username'],
            userId: user['id'],
          );

          // Sunucu profilini ve istatistikleri yükle
          final profileResponse = await ApiService.instance.getProfile();
          if (profileResponse.isSuccess && profileResponse.data != null) {
            final statsData = profileResponse.data!['stats'];
            if (statsData != null) {
              await _storageService.syncStatsFromServer(statsData);
            }
          }

          // Yerel veriyi sunucuya yansıt (offline biriken)
          await _syncLocalStatsToServer();

          _isLoading = false;
          notifyListeners();
          return true;
        }
        // pending → devam
      }

      _errorMessage = 'Giriş zaman aşımına uğradı. Lütfen tekrar deneyin.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'CaYaDev girişi hatası: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Çıkış yap
  Future<void> logout() async {
    // Önce sunucuya son sync'i gönder (varsa bekleyen veri)
    if (_isLoggedIn && _hasPendingSync) {
      await _syncLocalStatsToServer();
    }

    // Auth bilgilerini temizle
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_usernameKey);
    await _prefs?.remove(_displayNameKey);
    await _prefs?.remove(_userIdKey);
    await _prefs?.setBool(_isLoggedInKey, false);
    await _prefs?.setBool(_pendingSyncKey, false);

    // Yerel oyun verilerini temizle (başka kullanıcı girişine hazırla)
    await _storageService.clearAllData();

    // Sınıf modu singleton'ındaki yetki ve oda state'ini sıfırla — sonraki
    // soru bankası / arşiv açılışında önceki kullanıcının verisi gözükmesin
    ClassroomService.instance.clearAuth();

    ApiService.instance.setToken(null);
    _isLoggedIn = false;
    _username = null;
    _displayName = null;
    _userId = null;
    _errorMessage = null;
    _hasPendingSync = false;

    notifyListeners();
  }

  /// Yerel istatistikleri sunucuya gönder
  Future<bool> _syncLocalStatsToServer() async {
    if (!_isLoggedIn) return false;

    try {
      final stats = LocalStorageService.instance.stats;
      final response = await ApiService.instance.syncStats(stats.toJson());
      
      if (response.isSuccess) {
        _hasPendingSync = false;
        await _prefs?.setBool(_pendingSyncKey, false);
        return true;
      }
      return false;
    } catch (e) {
      print('AuthService: Senkronizasyon hatası: $e');
      return false;
    }
  }

  /// Bekleyen senkronizasyonu işaretle (offline oyun sonrası)
  Future<void> markPendingSync() async {
    if (_isLoggedIn) {
      _hasPendingSync = true;
      await _prefs?.setBool(_pendingSyncKey, true);
    }
  }

  /// İnternet bağlantısı geldiğinde senkronize et
  Future<bool> trySyncIfNeeded() async {
    if (!_isLoggedIn || !_hasPendingSync) return false;

    final connected = await ApiService.instance.checkConnection();
    if (!connected) return false;

    return await _syncLocalStatsToServer();
  }

  /// Bulmaca sonrası istatistikleri sunucuya gönder
  Future<void> syncAfterPuzzle() async {
    if (!_isLoggedIn) return;

    final connected = await ApiService.instance.checkConnection();
    if (connected) {
      final success = await _syncLocalStatsToServer();
      if (!success) {
        await markPendingSync();
      }
    } else {
      await markPendingSync();
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
