import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/crossword_clue.dart';
import '../models/crossword_puzzle.dart';
import '../models/crossword_word.dart';
import '../services/auth_service.dart';
import '../services/classroom_service.dart';
import '../services/crossword_category_service.dart';
import '../services/dynamic_crossword_generator.dart';
import 'crossword_provider.dart';

enum ClassroomStatus { idle, connecting, waiting, playing, finished, error }

/// Bir sınıf üyesi (öğretmen veya öğrenci)
class ClassroomMember {
  final String id;
  final String userId;
  final String displayName;
  final bool isTeacher;
  bool isReady;
  int score;
  int completedWords;
  int totalWords;
  int progress;
  int hintsUsed;
  int lettersRevealed;
  int wordsRevealed;
  bool isFinished;
  int? finishOrder;
  int? durationSeconds;
  bool disconnected;

  ClassroomMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.isTeacher,
    this.isReady = false,
    this.score = 0,
    this.completedWords = 0,
    this.totalWords = 0,
    this.progress = 0,
    this.hintsUsed = 0,
    this.lettersRevealed = 0,
    this.wordsRevealed = 0,
    this.isFinished = false,
    this.finishOrder,
    this.durationSeconds,
    this.disconnected = false,
  });

  factory ClassroomMember.fromJson(Map<String, dynamic> json) =>
      ClassroomMember(
        id: json['id'] ?? '',
        userId: json['userId'] ?? '',
        displayName: json['displayName'] ?? 'Anonim',
        isTeacher: json['isTeacher'] == true,
        isReady: json['isReady'] == true,
        score: (json['score'] ?? 0) as int,
        completedWords: (json['completedWords'] ?? 0) as int,
        totalWords: (json['totalWords'] ?? 0) as int,
        progress: (json['progress'] ?? 0) as int,
        hintsUsed: (json['hintsUsed'] ?? 0) as int,
        lettersRevealed: (json['lettersRevealed'] ?? 0) as int,
        wordsRevealed: (json['wordsRevealed'] ?? 0) as int,
        isFinished: json['isFinished'] == true,
        finishOrder: json['finishOrder'],
        durationSeconds: json['durationSeconds'],
        disconnected: json['disconnected'] == true,
      );
}

/// Sınıf odası ayarları
class ClassroomSettings {
  int hintLimit;
  int timeLimit;          // saniye, 0 = sınırsız
  int maxStudents;
  int gridSize;
  bool showScoreboard;
  bool allowLetterHint;
  bool allowWordHint;

  ClassroomSettings({
    this.hintLimit = 3,
    this.timeLimit = 0,
    this.maxStudents = 50,
    this.gridSize = 15,
    this.showScoreboard = true,
    this.allowLetterHint = true,
    this.allowWordHint = true,
  });

  factory ClassroomSettings.fromJson(Map<String, dynamic> j) =>
      ClassroomSettings(
        hintLimit: (j['hintLimit'] ?? 3) as int,
        timeLimit: (j['timeLimit'] ?? 0) as int,
        maxStudents: (j['maxStudents'] ?? 50) as int,
        gridSize: (j['gridSize'] ?? 15) as int,
        showScoreboard: j['showScoreboard'] != false,
        allowLetterHint: j['allowLetterHint'] != false,
        allowWordHint: j['allowWordHint'] != false,
      );

  Map<String, dynamic> toJson() => {
        'hintLimit': hintLimit,
        'timeLimit': timeLimit,
        'maxStudents': maxStudents,
        'gridSize': gridSize,
        'showScoreboard': showScoreboard,
        'allowLetterHint': allowLetterHint,
        'allowWordHint': allowWordHint,
      };
}

class ClassroomMeta {
  String title;
  String description;
  ClassroomMeta({this.title = 'Sınıf Sınavı', this.description = ''});

  factory ClassroomMeta.fromJson(Map<String, dynamic> j) => ClassroomMeta(
        title: j['title']?.toString() ?? 'Sınıf Sınavı',
        description: j['description']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'title': title, 'description': description};
}

/// Sınıf modu state yöneticisi
class ClassroomProvider extends ChangeNotifier {
  final ClassroomService _service = ClassroomService.instance;
  final CrosswordCategoryService _categoryService = CrosswordCategoryService();

  // Asıl çengel bulmaca motoru — oyunun kendi CrosswordProvider'ı
  final CrosswordProvider _cp = CrosswordProvider();

  // --- Oda durumu ---
  ClassroomStatus _status = ClassroomStatus.idle;
  String? _roomCode;
  String? _playerId;
  bool _isTeacher = false;
  ClassroomSettings _settings = ClassroomSettings();
  ClassroomMeta _meta = ClassroomMeta();
  List<ClassroomMember> _members = [];
  String? _errorMessage;

  // --- Sınıf oyun durumu (CrosswordProvider'a DELEGELENMEYEN sınıf-özel alanlar) ---
  int _hintsUsed = 0;
  int _lettersRevealed = 0;
  int _wordsRevealed = 0;
  DateTime? _startTime;
  bool _finishedSelf = false;

  // --- Sonuçlar (sınav bittiğinde) ---
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic> _aggregate = {};
  String? _endReason;

  // Süre
  Timer? _timeTimer;
  int _remainingSeconds = 0;

  // Periyodik ilerleme yollama
  Timer? _progressTimer;

  final List<StreamSubscription> _subs = [];

  // --- Getter'lar ---
  ClassroomStatus get status => _status;
  String? get roomCode => _roomCode;
  String? get playerId => _playerId;
  bool get isTeacher => _isTeacher;
  ClassroomSettings get settings => _settings;
  ClassroomMeta get meta => _meta;
  List<ClassroomMember> get members => _members;
  List<ClassroomMember> get students =>
      _members.where((m) => !m.isTeacher).toList();
  ClassroomMember? get teacher =>
      _members.cast<ClassroomMember?>().firstWhere(
            (m) => m?.isTeacher == true,
            orElse: () => null,
          );
  String? get errorMessage => _errorMessage;

  // Çengel bulmaca state'i — CrosswordProvider'a delege edildi
  CrosswordPuzzle? get puzzle => _cp.currentPuzzle;
  CrosswordWord? get selectedWord => _cp.selectedWord;
  CellPosition? get selectedCell => _cp.selectedCell;
  Map<String, String> get userAnswers => _cp.userAnswers;
  Set<String> get completedWordIds => _cp.completedWordIds;
  Set<String> get correctCells => _cp.correctCells;
  Set<String> get hintedCells => _cp.hintedCells;
  bool get isGameCompleted => _cp.isGameCompleted;
  String? get lastCompletedWordId => _cp.lastCompletedWordId;
  void clearLastCompletedWord() => _cp.clearLastCompletedWord();

  /// Çoklu oyuncu / tek oyuncu ekranıyla aynı istatistik yapısı
  Map<String, dynamic> getGameStats() {
    final gs = _cp.getGameStats();
    // displayScore: UI gösterimi için eski formül (doldurduğun her hücre sayilir)
    // puzzleScore: sunucuya kaydedilen gerçek puan (sadece tamamlanan kelimeler)
    final correctCells = _cp.correctCells;
    final hintedCells = _cp.hintedCells;
    final hintedAndCorrect = hintedCells.intersection(correctCells).length;
    final classroomScore = (correctCells.length - hintedAndCorrect).clamp(0, 999999);
    return {
      ...gs,
      'displayScore': gs['puzzleScore'] ?? 0,   // eski formül = totalCells - hinted
      'puzzleScore': classroomScore,             // gerçek classroom puanı
    };
  }

  // Sınıf-özel getter'lar
  int get hintsUsed => _hintsUsed;
  int get lettersRevealed => _lettersRevealed;
  int get wordsRevealed => _wordsRevealed;
  bool get finishedSelf => _finishedSelf;
  bool get hasTimeLimit => _settings.timeLimit > 0;
  int get remainingSeconds => _remainingSeconds;
  bool get canUseHint => _hintsUsed < _settings.hintLimit;
  int get remainingHints =>
      (_settings.hintLimit - _hintsUsed).clamp(0, 999);
  List<Map<String, dynamic>> get results => _results;
  Map<String, dynamic> get aggregate => _aggregate;
  String? get endReason => _endReason;

  String _cellKey(int r, int c) => '$r-$c';

  // --------------------------------------------------------------
  // İlk hazırlık ve dinleyiciler
  // --------------------------------------------------------------
  bool _authListenerAttached = false;
  bool _cpListenerAttached = false;

  Future<void> initialize() async {
    await _categoryService.initialize();
    final auth = AuthService.instance;
    if (auth.token != null) _service.setAuthToken(auth.token!);

    // CrosswordProvider değişimlerini ClassroomProvider'a yansıt
    if (!_cpListenerAttached) {
      _cpListenerAttached = true;
      _cp.addListener(_onCrosswordChange);
    }

    // Auth değişiminde (özellikle logout) provider state'ini temizle —
    // sonraki kullanıcı önceki kişinin sorularını/kayıtlarını görmesin.
    if (!_authListenerAttached) {
      _authListenerAttached = true;
      auth.addListener(_handleAuthChange);
    }
    _setupListeners();
  }

  /// CrosswordProvider her değiştiğinde ClassroomProvider'ı da bilgilendir
  /// ve oyun bitişini kontrol et.
  void _onCrosswordChange() {
    if (!_isTeacher &&
        !_finishedSelf &&
        _status == ClassroomStatus.playing &&
        _cp.isGameCompleted) {
      _finishGame();
      return; // _finishGame zaten notifyListeners() çağırır
    }
    notifyListeners();
  }

  void _handleAuthChange() {
    final auth = AuthService.instance;
    if (auth.isLoggedIn) {
      // Yeni token'la servisi güncelle
      if (auth.token != null) _service.setAuthToken(auth.token!);
    } else {
      // Logout — tüm classroom state'i sıfırla
      _resetState();
      notifyListeners();
    }
  }

  void _setupListeners() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _subs.add(_service.onRoomCreated.listen(_onRoomCreated));
    _subs.add(_service.onRoomJoined.listen(_onRoomJoined));
    _subs.add(_service.onRoomUpdated.listen(_onRoomUpdated));
    _subs.add(_service.onStudentJoined.listen((_) => notifyListeners()));
    _subs.add(_service.onStudentLeft.listen((_) => notifyListeners()));
    _subs.add(_service.onStudentKicked.listen(_onKicked));
    _subs.add(_service.onGameStarted.listen(_onGameStarted));
    _subs.add(_service.onPlayerProgress.listen(_onPlayerProgress));
    _subs.add(_service.onPlayerFinished.listen(_onPlayerFinished));
    _subs.add(_service.onGameEnded.listen(_onGameEnded));
    _subs.add(_service.onRoomClosed.listen(_onRoomClosed));
    _subs.add(_service.onError.listen((d) {
      _errorMessage = d['message']?.toString();
      notifyListeners();
    }));
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --------------------------------------------------------------
  // Oda işlemleri
  // --------------------------------------------------------------
  Future<bool> createRoom({
    required ClassroomSettings settings,
    required ClassroomMeta meta,
  }) async {
    final auth = AuthService.instance;
    if (!auth.isLoggedIn) {
      _errorMessage = 'Giriş yapmanız gerekiyor.';
      notifyListeners();
      return false;
    }
    // Önceki oturumdan kalan rol/bayrakları temizle (state sızıntısı önle)
    _resetState();
    _service.setAuthToken(auth.token ?? '');
    _status = ClassroomStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    final result = await _service.createRoom(
      displayName: auth.displayName ?? auth.username ?? 'Öğretmen',
      settings: settings.toJson(),
      meta: meta.toJson(),
    );
    if (result == null) {
      _status = ClassroomStatus.error;
      notifyListeners();
      return false;
    }
    // Stream olayı asenkron geldiğinden burada hemen set ediyoruz
    _isTeacher = true;
    _roomCode = _service.roomCode;
    _playerId = _service.playerId;
    _status = ClassroomStatus.waiting;
    notifyListeners();
    return true;
  }

  Future<bool> joinRoom(String code) async {
    final auth = AuthService.instance;
    if (!auth.isLoggedIn) {
      _errorMessage = 'Giriş yapmanız gerekiyor.';
      notifyListeners();
      return false;
    }
    // Önceki oturumdan kalan rol/bayrakları temizle (öğrenci yanlışlıkla
    // teacher görünmesin diye)
    _resetState();
    _service.setAuthToken(auth.token ?? '');
    _status = ClassroomStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    final result = await _service.joinRoom(
      code: code,
      displayName: auth.displayName ?? auth.username ?? 'Öğrenci',
    );
    if (result == null) {
      _status = ClassroomStatus.error;
      notifyListeners();
      return false;
    }
    // Sunucudan yetkili `isTeacher` bayrağını al — aynı kullanıcı tekrar
    // katılırsa öğretmen olarak da dönebilir
    _isTeacher = result['isTeacher'] == true;
    _roomCode = _service.roomCode;
    _playerId = _service.playerId;
    _status = ClassroomStatus.waiting;
    notifyListeners();
    return true;
  }

  Future<void> updateSettings(ClassroomSettings s, {ClassroomMeta? meta}) async {
    if (!_isTeacher) return;
    _settings = s;
    if (meta != null) _meta = meta;
    notifyListeners();
    await _service.updateSettings(
      settings: s.toJson(),
      meta: meta?.toJson(),
    );
  }

  /// Öğretmen — seçilen ipuçlarından bulmaca üret ve sınavı başlat.
  /// [clues] zaten öğretmen tarafından dahili UI üzerinden seçilmiş soru listesidir.
  Future<ClassroomStartResult> startExamWithClues(
      List<CrosswordClue> clues) async {
    if (!_isTeacher || _roomCode == null) {
      return ClassroomStartResult.failure('Yalnızca öğretmen başlatabilir.');
    }
    if (clues.length < 2) {
      return ClassroomStartResult.failure(
          'En az 2 soru seçmelisiniz.');
    }

    final generator = DynamicCrosswordGenerator(
      gridRows: _settings.gridSize,
      gridCols: _settings.gridSize,
    );
    final puzzle = generator.generatePuzzle(
      id: 'classroom_${DateTime.now().millisecondsSinceEpoch}',
      title: _meta.title,
      description: _meta.description,
      clues: clues,
      maxWords: clues.length,
    );

    if (puzzle.words.isEmpty) {
      return ClassroomStartResult.failure(
          'Seçilen sorulardan bulmaca oluşturulamadı. Daha fazla veya kısa cevaplı soru ekleyin.');
    }
    if (puzzle.words.length < clues.length) {
      // Kısmi yerleşim — uyarı olarak döneceğiz ama başlatmaya izin vereceğiz
      final placed = puzzle.words.length;
      final dropped = clues.length - placed;
      final warning =
          '$dropped soru bulmacaya yerleştirilemedi (toplam $placed/${clues.length}). Yine de başlatmak ister misiniz?';
      return ClassroomStartResult.warning(puzzle, warning);
    }
    return ClassroomStartResult.ready(puzzle);
  }

  /// Üretilen bulmaca onaylandıktan sonra sunucuya gönderir
  Future<bool> commitStart(CrosswordPuzzle puzzle) async {
    final ok = await _service.startGame(puzzle.toJson());
    if (!ok) {
      _errorMessage = 'Sınav başlatılamadı';
      notifyListeners();
    }
    return ok;
  }

  Future<void> kickStudent(String studentId) async {
    if (!_isTeacher) return;
    await _service.kickStudent(studentId);
  }

  Future<void> endExamEarly() async {
    if (!_isTeacher) return;
    await _service.endExam();
  }

  Future<void> leaveRoom() async {
    _progressTimer?.cancel();
    _timeTimer?.cancel();
    await _service.leaveRoom();
    _resetState();
    notifyListeners();
  }

  // --------------------------------------------------------------
  // Olay alıcılar
  // --------------------------------------------------------------
  void _onRoomCreated(Map<String, dynamic> data) {
    _roomCode = (data['roomCode'] ?? '') as String;
    _playerId = (data['_selfPlayerId'] as String?) ?? _service.playerId;
    // Service explicitly tags this — onaylanmış öğretmen rolü
    _isTeacher = data['_isTeacher'] == true;
    _status = ClassroomStatus.waiting;
    _absorbRoom(data, preserveExplicitRole: true);
    notifyListeners();
  }

  void _onRoomJoined(Map<String, dynamic> data) {
    _roomCode = (data['roomCode'] ?? '') as String;
    _playerId = (data['_selfPlayerId'] as String?) ?? _service.playerId;
    // Service explicit bayrak iletti → onu kullan (varsayılanı: false)
    _isTeacher = data['_isTeacher'] == true;
    _status = ClassroomStatus.waiting;
    _absorbRoom(data, preserveExplicitRole: true);
    notifyListeners();
  }

  void _onRoomUpdated(Map<String, dynamic> data) {
    _absorbRoom(data);
    notifyListeners();
  }

  /// [preserveExplicitRole] true ise `_isTeacher`'ı players listesinden
  /// türetme — çağıran daha güvenilir bir kaynaktan zaten ayarlamış demektir.
  void _absorbRoom(Map<String, dynamic> data,
      {bool preserveExplicitRole = false}) {
    if (data['settings'] != null) {
      _settings = ClassroomSettings.fromJson(
          Map<String, dynamic>.from(data['settings']));
    }
    if (data['meta'] != null) {
      _meta = ClassroomMeta.fromJson(Map<String, dynamic>.from(data['meta']));
    }
    if (data['players'] != null) {
      _members = (data['players'] as List)
          .map((p) =>
              ClassroomMember.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    }
    // Sonradan gelen room_updated olaylarında players'tan rol türet — ama
    // create/join'in açık bayrağını bozma
    if (!preserveExplicitRole && _playerId != null) {
      final me = _members.firstWhere(
        (m) => m.id == _playerId,
        orElse: () => ClassroomMember(
            id: '', userId: '', displayName: '', isTeacher: false),
      );
      if (me.id.isNotEmpty) _isTeacher = me.isTeacher;
    }
  }

  void _onKicked(Map<String, dynamic> data) {
    if (data['studentId'] == _playerId) {
      _errorMessage = 'Öğretmen sizi sınıftan çıkardı.';
      _resetState();
      _status = ClassroomStatus.idle;
    }
    notifyListeners();
  }

  void _onGameStarted(Map<String, dynamic> data) {
    _status = ClassroomStatus.playing;
    _finishedSelf = false;
    _results = [];
    _aggregate = {};
    _hintsUsed = 0;
    _lettersRevealed = 0;
    _wordsRevealed = 0;
    _startTime = DateTime.now();

    if (data['settings'] != null) {
      _settings = ClassroomSettings.fromJson(
          Map<String, dynamic>.from(data['settings']));
    }

    // Bulmaca verisini CrosswordProvider üzerinden yükle — oyunun kendi motoru kullanılıyor
    if (data['puzzleData'] != null) {
      final puzzle = CrosswordPuzzle.fromJson(
          Map<String, dynamic>.from(data['puzzleData']));
      _cp.loadExternalPuzzle(puzzle);
    }

    _startProgressTimer();
    if (_settings.timeLimit > 0) {
      _remainingSeconds = _settings.timeLimit;
      _timeTimer?.cancel();
      _timeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          t.cancel();
          if (!_finishedSelf && !_isTeacher) _finishGame();
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _onPlayerProgress(Map<String, dynamic> data) {
    final id = data['playerId'] as String?;
    if (id == null) return;
    final idx = _members.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final m = _members[idx];
    m.completedWords = (data['completedWords'] ?? m.completedWords) as int;
    m.totalWords = (data['totalWords'] ?? m.totalWords) as int;
    m.score = (data['score'] ?? m.score) as int;
    m.progress = (data['progress'] ?? m.progress) as int;
    m.hintsUsed = (data['hintsUsed'] ?? m.hintsUsed) as int;
    m.lettersRevealed =
        (data['lettersRevealed'] ?? m.lettersRevealed) as int;
    m.wordsRevealed = (data['wordsRevealed'] ?? m.wordsRevealed) as int;
    notifyListeners();
  }

  void _onPlayerFinished(Map<String, dynamic> data) {
    final id = data['playerId'] as String?;
    final idx = _members.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final m = _members[idx];
    m.isFinished = true;
    m.score = (data['score'] ?? m.score) as int;
    m.finishOrder = data['finishOrder'] as int?;
    m.durationSeconds = data['durationSeconds'] as int?;
    m.completedWords = (data['completedWords'] ?? m.completedWords) as int;
    m.progress = 100;
    notifyListeners();
  }

  void _onGameEnded(Map<String, dynamic> data) {
    _status = ClassroomStatus.finished;
    _progressTimer?.cancel();
    _timeTimer?.cancel();
    if (data['results'] != null) {
      _results = List<Map<String, dynamic>>.from(
          (data['results'] as List).map((e) => Map<String, dynamic>.from(e)));
    }
    if (data['aggregate'] != null) {
      _aggregate = Map<String, dynamic>.from(data['aggregate']);
    }
    _endReason = data['reason']?.toString();
    notifyListeners();
  }

  void _onRoomClosed(Map<String, dynamic> data) {
    _errorMessage = data['reason']?.toString() ?? 'Oda kapatıldı';
    // Öğretmen ayrıldı / sunucu odayı kapattı → results ekranında göster
    _endReason = 'teacher_left';
    _status = ClassroomStatus.finished;
    _progressTimer?.cancel();
    _timeTimer?.cancel();
    notifyListeners();
  }

  // --------------------------------------------------------------
  // Öğrenci oyun mantığı — CrosswordProvider'a delege edildi
  // --------------------------------------------------------------
  void selectCell(int row, int col) {
    if (_isTeacher || _cp.currentPuzzle == null || _finishedSelf) return;
    _cp.selectCell(row, col); // notifyListeners → _onCrosswordChange
  }

  void selectWord(CrosswordWord word) {
    if (_isTeacher || _finishedSelf) return;
    _cp.selectWord(word);
  }

  void enterLetter(String letter) {
    if (_isTeacher || _finishedSelf || _cp.currentPuzzle == null) return;
    if (_cp.isGameCompleted) return;
    _cp.enterLetter(letter); // CrosswordProvider: harf gir, kontrol et, bildir
  }

  void deleteLetter() {
    if (_isTeacher || _finishedSelf) return;
    _cp.deleteLetter();
  }

  void revealLetter() {
    if (_isTeacher || _finishedSelf || !canUseHint) return;
    if (!_settings.allowLetterHint) return;
    if (_cp.selectedCell == null || _cp.currentPuzzle == null) return;
    // Sayaçları ÖNCE artır — sonraki notifyListeners'da doğru değer görünsün
    _hintsUsed++;
    _lettersRevealed++;
    _cp.revealLetter(); // CrosswordProvider: hücreyi aç, hintedCells ekle, bildir
  }

  void revealWord() {
    if (_isTeacher || _finishedSelf || !canUseHint) return;
    if (!_settings.allowWordHint) return;
    if (_cp.selectedWord == null || _cp.currentPuzzle == null) return;
    _hintsUsed++;
    _wordsRevealed++;
    _cp.revealWord();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isTeacher || _finishedSelf || _cp.currentPuzzle == null) return;
      final stats = _computeMyStats();
      _service.updateProgress(
        completedWords: stats['completedWords'] as int,
        totalWords: stats['totalWords'] as int,
        score: stats['score'] as int,
        hintsUsed: _hintsUsed,
        lettersRevealed: _lettersRevealed,
        wordsRevealed: _wordsRevealed,
      );
    });
  }

  Map<String, dynamic> _computeMyStats() {
    final gs = _cp.getGameStats();
    final duration = _startTime == null
        ? 0
        : DateTime.now().difference(_startTime!).inSeconds;

    // Classroom için gerçek puan: sadece TAMAMLANAN kelimelerin
    // kullanıcının kendi doldurduğu hücreleri sayılır.
    final correctCells = _cp.correctCells;
    final hintedCells = _cp.hintedCells;
    final hintedAndCorrect = hintedCells.intersection(correctCells).length;
    final classroomScore = (correctCells.length - hintedAndCorrect).clamp(0, 999999);

    return {
      'completedWords': gs['completedWords'] ?? 0,
      'totalWords': gs['totalWords'] ?? 0,
      'score': classroomScore,
      'totalCells': gs['totalCells'] ?? 0,
      'hintedCells': gs['hintedCells'] ?? 0,
      'durationSeconds': duration,
    };
  }

  void _finishGame() {
    if (_finishedSelf) return;
    _finishedSelf = true;
    _progressTimer?.cancel();
    if (_cp.currentPuzzle != null) {
      final s = _computeMyStats();
      _service.finishGame(
        score: s['score'] as int,
        completedWords: s['completedWords'] as int,
        totalWords: s['totalWords'] as int,
        hintsUsed: _hintsUsed,
        lettersRevealed: _lettersRevealed,
        wordsRevealed: _wordsRevealed,
        durationSeconds: s['durationSeconds'] as int,
      );
    }
    notifyListeners();
  }

  // --------------------------------------------------------------

  void _resetState() {
    _status = ClassroomStatus.idle;
    _roomCode = null;
    _playerId = null;
    _isTeacher = false;
    _settings = ClassroomSettings();
    _meta = ClassroomMeta();
    _members = [];
    _hintsUsed = 0;
    _lettersRevealed = 0;
    _wordsRevealed = 0;
    _startTime = null;
    _finishedSelf = false;
    _results = [];
    _aggregate = {};
    _endReason = null;
    _remainingSeconds = 0;
    _progressTimer?.cancel();
    _timeTimer?.cancel();
    // CrosswordProvider state'ini temizle
    _cp.resetGame();
  }

  @override
  void dispose() {
    if (_authListenerAttached) {
      AuthService.instance.removeListener(_handleAuthChange);
      _authListenerAttached = false;
    }
    if (_cpListenerAttached) {
      _cp.removeListener(_onCrosswordChange);
      _cpListenerAttached = false;
    }
    _cp.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    _progressTimer?.cancel();
    _timeTimer?.cancel();
    super.dispose();
  }
}

class ClassroomStartResult {
  final bool ok;
  final bool warning;
  final String? message;
  final CrosswordPuzzle? puzzle;

  ClassroomStartResult._(
      {required this.ok, this.warning = false, this.message, this.puzzle});

  factory ClassroomStartResult.ready(CrosswordPuzzle p) =>
      ClassroomStartResult._(ok: true, puzzle: p);
  factory ClassroomStartResult.warning(CrosswordPuzzle p, String msg) =>
      ClassroomStartResult._(
          ok: true, warning: true, puzzle: p, message: msg);
  factory ClassroomStartResult.failure(String msg) =>
      ClassroomStartResult._(ok: false, message: msg);
}
