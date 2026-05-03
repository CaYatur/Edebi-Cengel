import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Sunucu API servisi - HTTP istekleri yönetimi
class ApiService {
  // Production server URL
  static const String _baseUrl = 'https://app.cayadev.com/edebi-cengel-server';
  
  String? _authToken;

  static ApiService? _instance;
  
  ApiService._();
  
  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  /// Auth token'ı ayarla
  void setToken(String? token) {
    _authToken = token;
  }

  /// Auth token mevcut mu?
  bool get hasToken => _authToken != null && _authToken!.isNotEmpty;

  /// Sunucuya bağlantı kontrolü
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Kayıt ol
  Future<ApiResponse> register({
    required String username,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName ?? username,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        _authToken = data['token'];
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error(data['error'] ?? 'Kayıt başarısız');
      }
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor. İnternet bağlantınızı kontrol edin.');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// Giriş yap
  Future<ApiResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        _authToken = data['token'];
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error(data['error'] ?? 'Giriş başarısız');
      }
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor. İnternet bağlantınızı kontrol edin.');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// CaYaDev OAuth - state ve auth URL al
  Future<ApiResponse> startCayadevOAuth() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/cayadev/start'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'CaYaDev girişi başlatılamadı');
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor. İnternet bağlantınızı kontrol edin.');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// CaYaDev OAuth - sonuç için poll et
  Future<ApiResponse> pollCayadevOAuth(String state) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/cayadev/poll/$state'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'Poll başarısız');
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// Profil bilgisi getir
  Future<ApiResponse> getProfile() async {
    if (!hasToken) return ApiResponse.error('Giriş yapılmamış');
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error(data['error'] ?? 'Profil getirilemedi');
      }
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// İstatistikleri sunucuya senkronize et
  Future<ApiResponse> syncStats(Map<String, dynamic> stats) async {
    if (!hasToken) return ApiResponse.error('Giriş yapılmamış');
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/stats/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'stats': stats}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error(data['error'] ?? 'Senkronizasyon başarısız');
      }
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// Sıralama tablosu getir
  Future<ApiResponse> getLeaderboard({int limit = 50, String period = 'all'}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/leaderboard?limit=$limit&period=$period'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error(data['error'] ?? 'Sıralama getirilemedi');
      }
    } on SocketException {
      return ApiResponse.error('Sunucuya bağlanılamıyor');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  // ==================== AI BULMACA ====================

  /// AI ile bulmaca oluştur (production server)
  static const String _aiBaseUrl = 'https://app.cayadev.com/edebi-cengel-server';

  /// AI bulmaca oluştur — async job pattern ile Cloudflare 504'ü önler.
  /// 1) POST /ai/generate-puzzle  → jobId (hemen döner, 202)
  /// 2) GET  /ai/puzzle-result/:jobId → pending/completed/failed poll et
  Future<ApiResponse> generateAIPuzzle({String? topic, required String mode}) async {
    if (!hasToken) return ApiResponse.error('Bu özellik için giriş yapmanız gerekiyor');

    // --- Adım 1: Job başlat ---
    String jobId;
    try {
      final startRes = await http.post(
        Uri.parse('$_aiBaseUrl/ai/generate-puzzle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'topic': topic, 'mode': mode}),
      ).timeout(const Duration(seconds: 15));

      if (startRes.statusCode == 429) {
        Map<String, dynamic> d;
        try { d = jsonDecode(startRes.body) as Map<String, dynamic>; } on FormatException { d = {}; }
        return ApiResponse.error(d['error'] ?? 'Çok sık istek. Lütfen bekleyin.');
      }
      if (startRes.statusCode == 401 || startRes.statusCode == 403) {
        return ApiResponse.error('Bu özellik için giriş yapmanız gerekiyor');
      }
      if (startRes.statusCode != 202) {
        Map<String, dynamic> d;
        try { d = jsonDecode(startRes.body) as Map<String, dynamic>; } on FormatException { d = {}; }
        return ApiResponse.error(d['error'] ?? 'Bulmaca başlatılamadı (${startRes.statusCode})');
      }
      final startData = jsonDecode(startRes.body) as Map<String, dynamic>;
      jobId = startData['jobId'] as String;
    } on SocketException {
      return ApiResponse.error('CaYaDevAI sunucusuna bağlanılamıyor. Bağlantınızı kontrol edin.');
    } on TimeoutException {
      return ApiResponse.error('Sunucu yanıt vermedi. Bağlantınızı kontrol edin.');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }

    // --- Adım 2: Sonucu poll et (max ~150 saniye, 3 saniyede bir) ---
    const maxAttempts = 50;
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final pollRes = await http.get(
          Uri.parse('$_aiBaseUrl/ai/puzzle-result/$jobId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
        ).timeout(const Duration(seconds: 10));

        if (pollRes.statusCode == 404) {
          return ApiResponse.error('AI job süresi doldu. Lütfen tekrar deneyin.');
        }

        Map<String, dynamic> data;
        try {
          data = jsonDecode(pollRes.body) as Map<String, dynamic>;
        } on FormatException {
          continue; // geçici sorun, tekrar dene
        }

        final status = data['status'] as String?;
        if (status == 'completed') return ApiResponse.success(data);
        if (status == 'failed') {
          return ApiResponse.error(data['error'] ?? 'Bulmaca oluşturulamadı');
        }
        // pending → devam
      } on SocketException {
        return ApiResponse.error('CaYaDevAI sunucusuna bağlanılamıyor.');
      } on TimeoutException {
        continue; // tek poll timeout'u, devam et
      } catch (e) {
        return ApiResponse.error('Bağlantı hatası: $e');
      }
    }

    return ApiResponse.error('AI bulmaca oluşturma zaman aşımına uğradı. Sunucu yoğun olabilir, lütfen tekrar deneyin.');
  }

  /// AI rate limit durumunu kontrol et
  Future<ApiResponse> checkAIRateLimit() async {
    if (!hasToken) return ApiResponse.error('Giriş yapılmamış');
    
    try {
      final response = await http.get(
        Uri.parse('$_aiBaseUrl/ai/rate-limit-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error(data['error'] ?? 'Kontrol başarısız');
      }
    } on SocketException {
      return ApiResponse.error('AI sunucusuna bağlanılamıyor');
    } catch (e) {
      return ApiResponse.error('Bağlantı hatası: $e');
    }
  }

  /// AI sunucusunun durumu ve erişilebilirliği
  Future<ApiResponse> checkAIStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_aiBaseUrl/ai/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['error'] ?? 'AI durum kontrolü başarısız');
    } on SocketException {
      return ApiResponse.error('AI sunucusuna bağlanamıyor');
    } catch (e) {
      return ApiResponse.error('AI sağlık kontrolü hatası: $e');
    }
  }
}

/// API yanıt modeli
class ApiResponse {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  ApiResponse._({required this.isSuccess, this.data, this.errorMessage});

  factory ApiResponse.success(Map<String, dynamic> data) {
    return ApiResponse._(isSuccess: true, data: data);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(isSuccess: false, errorMessage: message);
  }
}
