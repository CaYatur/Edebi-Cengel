import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/crossword_puzzle.dart';
import '../models/crossword_word.dart';
import '../services/multiplayer_service.dart';
import '../services/crossword_category_service.dart';
import '../services/auth_service.dart';
import '../providers/crossword_provider.dart';

/// Çoklu oyuncu oda durumları
enum RoomStatus { disconnected, connecting, waiting, playing, finished, error }

/// Çoklu oyuncu oyuncu bilgisi
class MultiplayerPlayer {
  final String id;
  final String displayName;
  final bool isHost;
  bool isReady;
  int score;
  int completedWords;
  int totalWords;
  int hintsUsed;
  int progress;
  bool isFinished;
  int? finishOrder;
  int? durationSeconds;
  int? rank;

  MultiplayerPlayer({
    required this.id,
    required this.displayName,
    required this.isHost,
    this.isReady = false,
    this.score = 0,
    this.completedWords = 0,
    this.totalWords = 0,
    this.hintsUsed = 0,
    this.progress = 0,
    this.isFinished = false,
    this.finishOrder,
    this.durationSeconds,
    this.rank,
  });

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayer(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? 'Anonim',
      isHost: json['isHost'] ?? false,
      isReady: json['isReady'] ?? false,
      score: json['score'] ?? 0,
      completedWords: json['completedWords'] ?? 0,
      totalWords: json['totalWords'] ?? 0,
      hintsUsed: json['hintsUsed'] ?? 0,
      progress: json['progress'] ?? 0,
      isFinished: json['isFinished'] ?? false,
      finishOrder: json['finishOrder'],
      durationSeconds: json['durationSeconds'],
      rank: json['rank'],
    );
  }
}

/// Oda ayarları
class RoomSettings {
  String categoryId;
  String categoryName;
  int difficulty;
  int wordCount;
  int gridSize;
  int hintLimit;
  int timeLimit; // saniye, 0 = sınırsız
  int maxPlayers;
  bool isPublic;

  RoomSettings({
    this.categoryId = 'mixed',
    this.categoryName = 'Karışık',
    this.difficulty = 0,
    this.wordCount = 10,
    this.gridSize = 15,
    this.hintLimit = 3,
    this.timeLimit = 0,
    this.maxPlayers = 8,
    this.isPublic = false,
  });

  factory RoomSettings.fromJson(Map<String, dynamic> json) {
    return RoomSettings(
      categoryId: json['categoryId'] ?? 'mixed',
      categoryName: json['categoryName'] ?? 'Karışık',
      difficulty: json['difficulty'] ?? 0,
      wordCount: json['wordCount'] ?? 10,
      gridSize: json['gridSize'] ?? 15,
      hintLimit: json['hintLimit'] ?? 3,
      timeLimit: json['timeLimit'] ?? 0,
      maxPlayers: json['maxPlayers'] ?? 8,
      isPublic: json['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'categoryName': categoryName,
    'difficulty': difficulty,
    'wordCount': wordCount,
    'gridSize': gridSize,
    'hintLimit': hintLimit,
    'timeLimit': timeLimit,
    'maxPlayers': maxPlayers,
    'isPublic': isPublic,
  };
}

/// Çoklu oyuncu provider
class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerService _service = MultiplayerService.instance;
  final CrosswordCategoryService _categoryService = CrosswordCategoryService();

  // Oda durumu
  RoomStatus _status = RoomStatus.disconnected;
  String? _roomCode;
  String? _playerId;
  bool _isHost = false;
  RoomSettings _settings = RoomSettings();
  List<MultiplayerPlayer> _players = [];
  String? _errorMessage;

  // Oyun durumu
  CrosswordPuzzle? _puzzle;
  CrosswordWord? _selectedWord;
  CellPosition? _selectedCell;
  Map<String, String> _userAnswers = {};
  Set<String> _completedWordIds = {};
  Set<String> _correctCells = {};
  Set<String> _hintedCells = {};
  int _hintsUsed = 0;
  DateTime? _gameStartTime;
  bool _isFinished = false;

  // Sonuçlar
  List<Map<String, dynamic>> _gameResults = [];
  
  // Herkese açık odalar
  List<Map<String, dynamic>> _publicRooms = [];
  bool _loadingPublicRooms = false;

  // Timer
  Timer? _progressTimer;
  Timer? _gameLimitTimer;
  int _remainingSeconds = 0;

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Getters
  RoomStatus get status => _status;
  String? get roomCode => _roomCode;
  String? get playerId => _playerId;
  bool get isHost => _isHost;
  RoomSettings get settings => _settings;
  List<MultiplayerPlayer> get players => _players;
  String? get errorMessage => _errorMessage;
  CrosswordPuzzle? get puzzle => _puzzle;
  CrosswordWord? get selectedWord => _selectedWord;
  CellPosition? get selectedCell => _selectedCell;
  Map<String, String> get userAnswers => _userAnswers;
  Set<String> get completedWordIds => _completedWordIds;
  Set<String> get correctCells => _correctCells;
  Set<String> get hintedCells => _hintedCells;
  int get hintsUsed => _hintsUsed;
  bool get isFinished => _isFinished;
  List<Map<String, dynamic>> get gameResults => _gameResults;
  int get remainingSeconds => _remainingSeconds;
  bool get hasTimeLimit => _settings.timeLimit > 0;
  bool get canUseHint => _hintsUsed < _settings.hintLimit;
  int get remainingHints => _settings.hintLimit - _hintsUsed;

  bool get isGameCompleted => _puzzle != null &&
      _completedWordIds.length == _puzzle!.words.length;

  bool get allPlayersReady =>
      _players.where((p) => !p.isHost).every((p) => p.isReady);
  
  List<Map<String, dynamic>> get publicRooms => _publicRooms;
  bool get loadingPublicRooms => _loadingPublicRooms;

  String _cellKey(int row, int col) => '$row-$col';

  /// Provider'ı başlat
  Future<void> initialize() async {
    await _categoryService.initialize();
    _setupListeners();
  }

  void _setupListeners() {
    // Önceki dinleyicileri iptal et
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _subscriptions.add(_service.onRoomCreated.listen(_handleRoomCreated));
    _subscriptions.add(_service.onRoomJoined.listen(_handleRoomJoined));
    _subscriptions.add(_service.onRoomUpdated.listen(_handleRoomUpdated));
    _subscriptions.add(_service.onPlayerJoined.listen(_handlePlayerJoined));
    _subscriptions.add(_service.onPlayerLeft.listen(_handlePlayerLeft));
    _subscriptions.add(_service.onGameStarted.listen(_handleGameStarted));
    _subscriptions.add(_service.onPlayerProgress.listen(_handlePlayerProgress));
    _subscriptions.add(_service.onPlayerCompleted.listen(_handlePlayerCompleted));
    _subscriptions.add(_service.onGameEnded.listen(_handleGameEnded));
    _subscriptions.add(_service.onError.listen(_handleError));
    _subscriptions.add(_service.onPlayerDisconnected.listen(_handlePlayerDisconnected));
    _subscriptions.add(_service.onGameCancelled.listen(_handleGameCancelled));
  }

  // ==================== ODA İŞLEMLERİ ====================

  /// Oda oluştur
  Future<void> createRoom() async {
    _status = RoomStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final authService = AuthService.instance;
      if (!authService.isLoggedIn) {
        _status = RoomStatus.error;
        _errorMessage = 'Giriş yapmalısınız';
        notifyListeners();
        return;
      }

      final token = authService.token ?? '';
      _service.setAuthToken(token, authService.userId ?? '');

      final displayName = authService.displayName ?? authService.username ?? 'Anonim';
      final success = await _service.createRoom(
        displayName: displayName,
        userId: authService.userId,
        settings: _settings.toJson(),
      );

      if (!success) {
        _status = RoomStatus.error;
        _errorMessage = 'Oda oluşturulamadı';
        notifyListeners();
      }
    } catch (e) {
      _status = RoomStatus.error;
      _errorMessage = 'Hata: $e';
      notifyListeners();
    }
  }

  /// Odaya katıl
  Future<void> joinRoom(String roomId) async {
    _status = RoomStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final authService = AuthService.instance;
      if (!authService.isLoggedIn) {
        _status = RoomStatus.error;
        _errorMessage = 'Giriş yapmalısınız';
        notifyListeners();
        return;
      }

      final token = authService.token ?? '';
      _service.setAuthToken(token, authService.userId ?? '');

      final displayName = authService.displayName ?? authService.username ?? 'Anonim';
      final success = await _service.joinRoom(
        roomId: roomId,
        displayName: displayName,
        userId: authService.userId,
      );

      if (!success) {
        _status = RoomStatus.error;
        _errorMessage = 'Odaya katılanamadı';
        notifyListeners();
      }
    } catch (e) {
      _status = RoomStatus.error;
      _errorMessage = 'Hata: $e';
      notifyListeners();
    }
  }

  /// Ayarları güncelle (host)
  Future<void> updateSettings(RoomSettings newSettings) async {
    if (!_isHost || _roomCode == null) return;
    _settings = newSettings;
    try {
      await _service.updateSettings(
        roomId: _roomCode!,
        settings: newSettings.toJson(),
      );
    } catch (e) {
      _errorMessage = 'Ayarlar güncellenemedi: $e';
    }
    notifyListeners();
  }

  /// Oyunu başlat (host) - bulmaca oluşturup gönder
  Future<void> startGame() async {
    if (!_isHost || _roomCode == null) return;

    try {
      // Bulmaca oluştur
      CrosswordPuzzle? puzzle;

      if (_settings.categoryId == 'mixed') {
        puzzle = _categoryService.generateMixedPuzzle(
          wordCount: _settings.wordCount,
          gridSize: _settings.gridSize,
        );
      } else {
        puzzle = _categoryService.generatePuzzleByDifficulty(
          _settings.categoryId,
          _settings.difficulty,
          wordCount: _settings.wordCount,
          gridSize: _settings.gridSize,
        );
      }

      if (puzzle == null) {
        _errorMessage = 'Bulmaca oluşturulamadı. Farklı ayarlar deneyin.';
        notifyListeners();
        return;
      }

      _puzzle = puzzle;
      _gameStartTime = DateTime.now();

      // Oyunu başlat (bulmaca verisini sunucuya gönder)
      final success = await _service.startGame(
        roomId: _roomCode!,
        puzzleData: puzzle.toJson(),
      );
      if (success) {
        _status = RoomStatus.playing;
      } else {
        _errorMessage = 'Oyun başlatılamadı';
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Hata: $e';
      notifyListeners();
    }
  }

  /// Herkese açık odaları getir
  Future<void> fetchPublicRooms() async {
    _loadingPublicRooms = true;
    notifyListeners();
    
    try {
      _publicRooms = await _service.getPublicRooms();
    } catch (e) {
      debugPrint('[MP] Odalar yüklenemedi: $e');
    }
    
    _loadingPublicRooms = false;
    notifyListeners();
  }
  
  /// Odayı herkese açık/kapalı yap
  Future<void> toggleRoomPublic(bool isPublic) async {
    if (!_isHost || _roomCode == null) return;
    _settings.isPublic = isPublic;
    try {
      await _service.updateSettings(
        roomId: _roomCode!,
        settings: _settings.toJson(),
      );
    } catch (e) {
      _errorMessage = 'Ayarlar güncellenemedi: $e';
    }
    notifyListeners();
  }

  /// Hazır durumunu değiştir
  Future<void> toggleReady() async {
    if (_roomCode == null) return;
    try {
      await _service.toggleReady(roomId: _roomCode!);
    } catch (e) {
      _errorMessage = 'Hazır durumu değiştirilemedi: $e';
      notifyListeners();
    }
  }

  /// Odadan ayrıl
  Future<void> leaveRoom() async {
    if (_roomCode == null) return;

    try {
      await _service.leaveRoom(roomId: _roomCode!);
    } catch (e) {
      debugPrint('[MP] leaveRoom error: $e');
    }
    
    _resetState();
    _service.disconnect();
    notifyListeners();
  }

  /// Oyunu zorla bitir (host)
  Future<void> forceEndGame() async {
    if (!_isHost || _roomCode == null) return;
    
    try {
      await _service.endGame(roomId: _roomCode!);
      _status = RoomStatus.finished;
    } catch (e) {
      _errorMessage = 'Oyun bitirilemedi: $e';
    }
    notifyListeners();
  }

  // ==================== OYUN İŞLEMLERİ ====================

  /// Hücre seç
  void selectCell(int row, int col) {
    if (_puzzle == null || _isFinished) return;
    if (!_puzzle!.isCellActive(row, col)) return;

    List<CrosswordWord> wordsAtCell = _puzzle!.getWordsAt(row, col);
    if (wordsAtCell.isEmpty) return;

    if (_selectedCell?.row == row && _selectedCell?.col == col) {
      if (wordsAtCell.length > 1) {
        int currentIndex = wordsAtCell.indexOf(_selectedWord!);
        _selectedWord = wordsAtCell[(currentIndex + 1) % wordsAtCell.length];
      }
    } else {
      _selectedCell = CellPosition(row, col);
      if (_selectedWord != null) {
        var sameDirectionWord = wordsAtCell.firstWhere(
          (w) => w.direction == _selectedWord!.direction,
          orElse: () => wordsAtCell.first,
        );
        _selectedWord = sameDirectionWord;
      } else {
        _selectedWord = wordsAtCell.first;
      }
    }

    notifyListeners();
  }

  /// Kelime seç (ipucu listesinden)
  void selectWord(CrosswordWord word) {
    _selectedWord = word;
    _selectedCell = CellPosition(word.row, word.col);
    notifyListeners();
  }

  /// Harf gir
  void enterLetter(String letter) {
    if (isGameCompleted || _isFinished) return;
    if (_selectedCell == null || _selectedWord == null || _puzzle == null) return;

    String cellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
    _userAnswers[cellKey] = letter.toUpperCase();

    _moveToNextCell();
    _checkWordCompletion();
    _sendProgress();

    notifyListeners();
  }

  /// Harf sil
  void deleteLetter() {
    if (isGameCompleted || _isFinished) return;
    if (_selectedCell == null || _selectedWord == null) return;

    String cellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);

    if (_userAnswers.containsKey(cellKey) && _userAnswers[cellKey]!.isNotEmpty) {
      _userAnswers[cellKey] = '';
    } else {
      _moveToPreviousCell();
      if (_selectedCell != null) {
        String prevCellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
        _userAnswers[prevCellKey] = '';
      }
    }

    _checkWordCompletion();
    notifyListeners();
  }

  /// İpucu - harf aç
  void revealLetter() {
    if (isGameCompleted || _isFinished || !canUseHint) return;
    if (_selectedCell == null || _puzzle == null) return;

    String? correctLetter = _puzzle!.getCorrectLetterAt(
      _selectedCell!.row,
      _selectedCell!.col,
    );

    if (correctLetter != null) {
      String cellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
      if (_correctCells.contains(cellKey)) return;

      _userAnswers[cellKey] = correctLetter.toUpperCase();
      _hintedCells.add(cellKey);
      _hintsUsed++;
      _moveToNextCell();
      _checkWordCompletion();
      _sendProgress();
      notifyListeners();
    }
  }

  /// İpucu - kelime aç
  void revealWord() {
    if (isGameCompleted || _isFinished || !canUseHint) return;
    if (_selectedWord == null || _puzzle == null) return;

    String cleanAnswer = _selectedWord!.answer.replaceAll(' ', '').toUpperCase();

    for (int i = 0; i < _selectedWord!.cells.length; i++) {
      CellPosition cell = _selectedWord!.cells[i];
      String cellKey = _cellKey(cell.row, cell.col);
      _userAnswers[cellKey] = cleanAnswer[i];
      if (!_correctCells.contains(cellKey)) {
        _hintedCells.add(cellKey);
      }
    }
    _hintsUsed++;

    _completedWordIds.add(_selectedWord!.id);
    for (var cell in _selectedWord!.cells) {
      _correctCells.add(_cellKey(cell.row, cell.col));
    }

    _sendProgress();
    notifyListeners();

    // Oyun bitti mi kontrol et
    if (isGameCompleted) {
      _finishGame();
    }
  }

  /// Oyun istatistiklerini hesapla
  Map<String, dynamic> getGameStats() {
    if (_puzzle == null) return {};

    Set<String> allCellKeys = {};
    for (var word in _puzzle!.words) {
      for (var cell in word.cells) {
        allCellKeys.add(_cellKey(cell.row, cell.col));
      }
    }
    int totalCells = allCellKeys.length;
    int hintedCellCount = _hintedCells.length;
    int userFilledCells = totalCells - hintedCellCount;
    if (userFilledCells < 0) userFilledCells = 0;

    // Yeni formül: sadece tamamlanan kelime hücreleri, ipucuyla açılmamış
    final hintedAndCorrect = _correctCells.intersection(_hintedCells).length;
    final completedWordScore = _correctCells.length - hintedAndCorrect;

    int durationSeconds = 0;
    if (_gameStartTime != null) {
      durationSeconds = DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    return {
      'totalWords': _puzzle!.words.length,
      'completedWords': _completedWordIds.length,
      'completionPercentage':
          (_completedWordIds.length / _puzzle!.words.length * 100).round(),
      'isCompleted': isGameCompleted,
      'totalCells': totalCells,
      'hintedCells': hintedCellCount,
      'userFilledCells': userFilledCells,
      'displayScore': userFilledCells,
      'puzzleScore': completedWordScore,
      'maxPossibleScore': totalCells,
      'hintsUsed': _hintsUsed,
      'hintLimit': _settings.hintLimit,
      'durationSeconds': durationSeconds,
    };
  }

  // ==================== PRIVATE METHODS ====================

  void _moveToNextCell() {
    if (_selectedWord == null || _selectedCell == null) return;
    List<CellPosition> cells = _selectedWord!.cells;
    int currentIndex = cells.indexWhere(
      (c) => c.row == _selectedCell!.row && c.col == _selectedCell!.col,
    );
    if (currentIndex >= 0 && currentIndex < cells.length - 1) {
      _selectedCell = cells[currentIndex + 1];
    }
  }

  void _moveToPreviousCell() {
    if (_selectedWord == null || _selectedCell == null) return;
    List<CellPosition> cells = _selectedWord!.cells;
    int currentIndex = cells.indexWhere(
      (c) => c.row == _selectedCell!.row && c.col == _selectedCell!.col,
    );
    if (currentIndex > 0) {
      _selectedCell = cells[currentIndex - 1];
    }
  }

  void _checkWordCompletion() {
    if (_puzzle == null) return;

    for (var word in _puzzle!.words) {
      bool isComplete = true;
      String cleanAnswer = normalizeTurkish(word.answer.replaceAll(' ', ''));

      if (word.cells.length != cleanAnswer.length) continue;

      for (int i = 0; i < word.cells.length; i++) {
        CellPosition cell = word.cells[i];
        String cellKey = _cellKey(cell.row, cell.col);
        String? userLetter = _userAnswers[cellKey];

        if (userLetter == null || userLetter.isEmpty) {
          isComplete = false;
          break;
        }

        String normalizedUserLetter = normalizeTurkish(userLetter);
        String expectedLetter = cleanAnswer[i];

        if (normalizedUserLetter != expectedLetter) {
          isComplete = false;
          break;
        }
      }

      if (isComplete) {
        if (!_completedWordIds.contains(word.id)) {
          _completedWordIds.add(word.id);
          for (var cell in word.cells) {
            _correctCells.add(_cellKey(cell.row, cell.col));
          }
        }
      } else {
        if (_completedWordIds.contains(word.id)) {
          _completedWordIds.remove(word.id);
          for (var cell in word.cells) {
            String cellKey = _cellKey(cell.row, cell.col);
            bool usedByOtherCompleted = _puzzle!.words.any((otherWord) =>
                otherWord.id != word.id &&
                _completedWordIds.contains(otherWord.id) &&
                otherWord.cells.any(
                    (c) => c.row == cell.row && c.col == cell.col));
            if (!usedByOtherCompleted) {
              _correctCells.remove(cellKey);
            }
          }
        }
      }
    }

    // Oyun bitti mi kontrol et
    if (isGameCompleted && !_isFinished) {
      _finishGame();
    }
  }

  void _sendProgress() {
    if (_roomCode == null || _puzzle == null) return;

    final stats = getGameStats();
    _service.updateProgress(
      roomId: _roomCode!,
      progress: stats['completedWords'] ?? 0,
      score: stats['puzzleScore'] ?? 0,
    );
  }

  void _finishGame() {
    if (_isFinished || _roomCode == null) return;
    _isFinished = true;

    final stats = getGameStats();
    final durationSeconds = stats['durationSeconds'] ?? 0;
    
    _service.playerFinished(
      roomId: _roomCode!,
      score: stats['puzzleScore'] ?? 0,
      finalTime: durationSeconds,
    );

    _progressTimer?.cancel();
    notifyListeners();
  }

  // ==================== EVENT HANDLERS ====================

  void _handleRoomCreated(Map<String, dynamic> data) {
    _roomCode = data['roomCode'] ?? data['id'];
    _isHost = true;
    _status = RoomStatus.waiting;
    _errorMessage = null;

    // Use service's playerId (set from REST response) as authoritative
    _playerId = _service.playerId;
    // Fallback: extract from players list
    if (_playerId == null && data['players'] != null && (data['players'] as List).isNotEmpty) {
      _playerId = (data['players'][0] as Map)['id'];
    }

    _updateRoomData(Map<String, dynamic>.from(data));

    notifyListeners();
    debugPrint('[MP] Oda oluşturuldu: $_roomCode (playerId: $_playerId)');
  }

  void _handleRoomJoined(Map<String, dynamic> data) {
    _roomCode = data['roomCode'] ?? data['id'];
    _isHost = false;
    _status = RoomStatus.waiting;
    _errorMessage = null;

    // Use service's playerId (set from REST response) as authoritative
    _playerId = _service.playerId;
    // Fallback: extract from players list
    if (_playerId == null && data['players'] != null && (data['players'] as List).isNotEmpty) {
      _playerId = (data['players'].last as Map)['id'];
    }

    _updateRoomData(Map<String, dynamic>.from(data));

    notifyListeners();
    debugPrint('[MP] Odaya katılındı: $_roomCode (playerId: $_playerId)');
  }

  void _handleRoomUpdated(Map<String, dynamic> data) {
    _updateRoomData(data);
    notifyListeners();
  }

  void _handlePlayerJoined(Map<String, dynamic> data) {
    debugPrint('[MP] Oyuncu katıldı: ${data['player']?['displayName']}');
    notifyListeners();
  }

  void _handlePlayerLeft(Map<String, dynamic> data) {
    // Host değiştiyse kontrol et
    if (data['newHostId'] != null && data['newHostId'] == _playerId) {
      _isHost = true;
    }
    debugPrint('[MP] Oyuncu ayrıldı: ${data['displayName']}');
    notifyListeners();
  }

  void _handleGameStarted(Map<String, dynamic> data) {
    _status = RoomStatus.playing;
    _isFinished = false;
    _gameResults = [];

    // Bulmaca verisi
    if (data['puzzleData'] != null) {
      _puzzle = CrosswordPuzzle.fromJson(Map<String, dynamic>.from(data['puzzleData']));
    }

    // Ayarları güncelle
    if (data['settings'] != null) {
      _settings = RoomSettings.fromJson(Map<String, dynamic>.from(data['settings']));
    }

    // Oyun state sıfırla
    _userAnswers = {};
    _completedWordIds = {};
    _correctCells = {};
    _hintedCells = {};
    _hintsUsed = 0;
    _gameStartTime = DateTime.now();

    if (_puzzle != null && _puzzle!.words.isNotEmpty) {
      _selectedWord = _puzzle!.words.first;
      _selectedCell = CellPosition(_selectedWord!.row, _selectedWord!.col);
    }

    // İlerleme güncellemesini periyodik gönder
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendProgress();
    });

    // Süre limiti varsa timer başlat
    if (_settings.timeLimit > 0) {
      _remainingSeconds = _settings.timeLimit;
      _gameLimitTimer?.cancel();
      _gameLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          if (!_isFinished) {
            _finishGame();
          }
        }
        notifyListeners();
      });
    }

    notifyListeners();
    debugPrint('[MP] Oyun başladı! ${_puzzle?.words.length ?? 0} kelime');
  }

  void _handlePlayerProgress(Map<String, dynamic> data) {
    final playerId = data['playerId'];
    final playerIndex = _players.indexWhere((p) => p.id == playerId);
    if (playerIndex >= 0) {
      _players[playerIndex].completedWords = data['completedWords'] ?? 0;
      _players[playerIndex].totalWords = data['totalWords'] ?? 0;
      _players[playerIndex].score = data['score'] ?? 0;
      _players[playerIndex].progress = data['progress'] ?? 0;
      _players[playerIndex].hintsUsed = data['hintsUsed'] ?? 0;
      notifyListeners();
    }
  }

  void _handlePlayerCompleted(Map<String, dynamic> data) {
    final playerId = data['playerId'];
    final playerIndex = _players.indexWhere((p) => p.id == playerId);
    if (playerIndex >= 0) {
      _players[playerIndex].isFinished = true;
      _players[playerIndex].score = data['score'] ?? 0;
      _players[playerIndex].finishOrder = data['finishOrder'];
      _players[playerIndex].completedWords = data['completedWords'] ?? 0;
      _players[playerIndex].durationSeconds = data['durationSeconds'];
      _players[playerIndex].progress = 100;
      notifyListeners();
    }
    debugPrint('[MP] ${data['displayName']} bitirdi! (${data['finishOrder']}. sıra)');
  }

  void _handleGameEnded(Map<String, dynamic> data) {
    _status = RoomStatus.finished;
    _progressTimer?.cancel();
    _gameLimitTimer?.cancel();

    if (data['results'] != null) {
      _gameResults = List<Map<String, dynamic>>.from(
        (data['results'] as List).map((r) => Map<String, dynamic>.from(r)),
      );
    }

    notifyListeners();
    debugPrint('[MP] Oyun bitti!');
  }

  void _handleError(Map<String, dynamic> data) {
    _errorMessage = data['message'] ?? 'Bilinmeyen hata';
    if (_status == RoomStatus.connecting) {
      _status = RoomStatus.disconnected;
    }
    notifyListeners();
    debugPrint('[MP] Hata: $_errorMessage');
  }

  void _handlePlayerDisconnected(Map<String, dynamic> data) {
    debugPrint('[MP] Oyuncu bağlantısı kesildi: ${data['displayName']}');
    notifyListeners();
  }

  void _handleGameCancelled(Map<String, dynamic> data) {
    _status = RoomStatus.finished;
    _progressTimer?.cancel();
    _gameLimitTimer?.cancel();
    _errorMessage = data['reason'] ?? 'Oyun iptal edildi.';
    _gameResults = [];
    notifyListeners();
    debugPrint('[MP] Oyun iptal edildi: ${data['reason']}');
  }

  void _updateRoomData(Map<String, dynamic> data) {
    if (data['settings'] != null) {
      _settings = RoomSettings.fromJson(Map<String, dynamic>.from(data['settings']));
    }
    if (data['players'] != null) {
      _players = (data['players'] as List)
          .map((p) => MultiplayerPlayer.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }
    if (data['hostId'] != null) {
      _isHost = data['hostId'] == _playerId;
    }
  }

  void _resetState() {
    _status = RoomStatus.disconnected;
    _roomCode = null;
    _playerId = null;
    _isHost = false;
    _settings = RoomSettings();
    _players = [];
    _errorMessage = null;
    _puzzle = null;
    _selectedWord = null;
    _selectedCell = null;
    _userAnswers = {};
    _completedWordIds = {};
    _correctCells = {};
    _hintedCells = {};
    _hintsUsed = 0;
    _gameStartTime = null;
    _isFinished = false;
    _gameResults = [];
    _remainingSeconds = 0;
    _progressTimer?.cancel();
    _gameLimitTimer?.cancel();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _gameLimitTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
