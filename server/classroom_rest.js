// ==================== SINIF MODU REST API ====================
// Öğretmen-öğrenci odaklı, oturum zorunlu, 50 kişiye kadar.
// Çoklu oyuncudan tamamen ayrı: ayrı oda haritası, ayrı kalıcılık dosyası.
//
// Bağımlılıklar: bu modül `app`, `jwt`, `JWT_SECRET` ve `authenticateToken`
// referanslarını parametre olarak alır; sunucu dosyasından bağımsız çalışır.

const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

module.exports = function setupClassroom({ app, authenticateToken, dataDir }) {
  const CLASSROOM_FILE = path.join(dataDir, 'classroom.json');

  // --------- Persistans (özel sorular + sınav arşivi) ---------
  function readClassroomData() {
    try {
      const raw = fs.readFileSync(CLASSROOM_FILE, 'utf8');
      const parsed = JSON.parse(raw);
      if (!parsed.teachers) parsed.teachers = {};
      return parsed;
    } catch (e) {
      return { teachers: {}, lastUpdated: '' };
    }
  }

  function writeClassroomData(data) {
    data.lastUpdated = new Date().toISOString();
    try {
      fs.writeFileSync(CLASSROOM_FILE, JSON.stringify(data, null, 2), 'utf8');
    } catch (e) {
      console.error('[Sınıf] Veri yazılamadı:', e.message);
    }
  }

  function ensureTeacherEntry(data, userId) {
    if (!data.teachers[userId]) {
      data.teachers[userId] = {
        customQuestions: [],
        history: [],
        createdAt: new Date().toISOString(),
      };
    }
    return data.teachers[userId];
  }

  // --------- Aktif sınıf odaları (RAM) ---------
  // roomCode -> roomData
  const classroomRooms = new Map();

  // 6 haneli kod (10x daha fazla benzersiz alan; öğrencilerin okuması kolay)
  function generateClassroomCode() {
    let attempts = 0;
    while (attempts++ < 200) {
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      if (!classroomRooms.has(code)) return code;
    }
    // Olası ama beklenmedik durum: temizliği zorla
    cleanupRooms(true);
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  function cleanupRooms(force = false) {
    const now = Date.now();
    const TTL_WAITING = 60 * 60 * 1000;       // 1 saat
    const TTL_FINISHED = 30 * 60 * 1000;      // 30 dk
    for (const [code, room] of classroomRooms.entries()) {
      const idleMs = now - (room.lastActivityAt || room.createdAt);
      if (room.status === 'waiting' && idleMs > TTL_WAITING) {
        classroomRooms.delete(code);
        console.log(`🧹 [Sınıf] Pasif oda silindi: ${code}`);
      } else if (room.status === 'finished' && now - (room.finishedAt || 0) > TTL_FINISHED) {
        classroomRooms.delete(code);
        console.log(`🧹 [Sınıf] Bitmiş oda silindi: ${code}`);
      } else if (force && room.status === 'waiting' && idleMs > 5 * 60 * 1000) {
        classroomRooms.delete(code);
      }
    }
  }
  setInterval(cleanupRooms, 5 * 60 * 1000);

  // --------- Olay sırası ve uzun sorgu ---------
  function addEvent(roomCode, type, data, targetPlayerId = null) {
    const room = classroomRooms.get(roomCode);
    if (!room) return;
    room.eventIdCounter = (room.eventIdCounter || 0) + 1;
    const event = {
      id: room.eventIdCounter,
      type,
      data,
      timestamp: Date.now(),
      targetPlayerId,
    };
    room.events.push(event);
    if (room.events.length > 400) room.events = room.events.slice(-200);
    room.lastActivityAt = Date.now();
    resolvePendingPolls(roomCode);
  }

  function getEventsForPlayer(room, sinceId, playerId) {
    if (!room.events) return [];
    return room.events
      .filter(e => e.id > sinceId && (e.targetPlayerId === null || e.targetPlayerId === playerId))
      .map(e => ({ id: e.id, type: e.type, data: e.data, timestamp: e.timestamp }));
  }

  function resolvePendingPolls(roomCode) {
    const room = classroomRooms.get(roomCode);
    if (!room || !room.pendingPolls || room.pendingPolls.length === 0) return;
    const toResolve = [...room.pendingPolls];
    room.pendingPolls = [];
    for (const poll of toResolve) {
      clearTimeout(poll.timeoutId);
      const events = getEventsForPlayer(room, poll.sinceId, poll.playerId);
      try {
        if (!poll.res.headersSent) poll.res.json({ events });
      } catch (_) { /* client gitti */ }
    }
  }

  // --------- Yardımcılar ---------
  function sanitizePlayer(p) {
    return {
      id: p.id,
      userId: p.userId,
      displayName: p.displayName,
      isTeacher: p.isTeacher,
      isReady: p.isReady,
      score: p.score,
      completedWords: p.completedWords,
      totalWords: p.totalWords,
      progress: p.progress,
      hintsUsed: p.hintsUsed,
      lettersRevealed: p.lettersRevealed,
      wordsRevealed: p.wordsRevealed,
      isFinished: p.isFinished,
      finishOrder: p.finishOrder,
      durationSeconds: p.durationSeconds,
      disconnected: !!p.disconnected,
      joinedAt: p.joinedAt,
    };
  }

  function sanitizeRoom(room) {
    return {
      roomCode: room.roomCode,
      hostId: room.hostId,
      hostName: room.hostName,
      status: room.status,
      settings: room.settings,
      meta: room.meta,
      players: room.players.map(sanitizePlayer),
      studentCount: room.players.filter(p => !p.isTeacher).length,
      createdAt: room.createdAt,
      gameStartedAt: room.gameStartedAt,
      finishedAt: room.finishedAt,
    };
  }

  function findTeacher(room) {
    return room.players.find(p => p.isTeacher);
  }

  function findStudent(room, playerId) {
    return room.players.find(p => p.id === playerId && !p.isTeacher);
  }

  function requireBody(res, body, fields) {
    for (const f of fields) {
      if (body[f] === undefined || body[f] === null) {
        res.status(400).json({ success: false, message: `Eksik alan: ${f}` });
        return false;
      }
    }
    return true;
  }

  // ==================== SINAV BİTİRME / İSTATİSTİK ====================
  function computeAggregateStats(room) {
    const students = room.players.filter(p => !p.isTeacher);
    const totalWords = room.puzzleData?.words?.length || 0;

    if (students.length === 0) {
      const empty = {
        studentCount: 0,
        finishedCount: 0,
        totalWords,
        averageScore: 0, avgScore: 0,
        averageCompletion: 0, avgCompletion: 0,
        averageHintsUsed: 0, avgHintsUsed: 0,
        averageDurationSeconds: 0, avgDuration: 0,
        avgLettersRevealed: 0,
        avgWordsRevealed: 0,
        medianScore: 0,
        topScore: 0, lowScore: 0,
        stdDeviation: 0,
        passRate: 0,
      };
      return empty;
    }

    const scores = students.map(p => p.score || 0);
    const completions = students.map(p => totalWords > 0 ? (p.completedWords || 0) / totalWords : 0);
    const hints = students.map(p => p.hintsUsed || 0);
    const lettersRev = students.map(p => p.lettersRevealed || 0);
    const wordsRev = students.map(p => p.wordsRevealed || 0);
    const durations = students
      .filter(p => (p.durationSeconds || 0) > 0)
      .map(p => p.durationSeconds);

    const finishedCount = students.filter(p => p.isFinished).length;
    const passingThreshold = 0.5; // %50 ve üstü "geçer"
    const passingCount = completions.filter(c => c >= passingThreshold).length;

    const sortedScores = [...scores].sort((a, b) => a - b);
    const median = sortedScores.length === 0 ? 0
      : sortedScores.length % 2 === 1
        ? sortedScores[(sortedScores.length - 1) / 2]
        : (sortedScores[sortedScores.length / 2 - 1] + sortedScores[sortedScores.length / 2]) / 2;

    const sum = arr => arr.reduce((a, b) => a + b, 0);
    const avg = arr => arr.length === 0 ? 0 : sum(arr) / arr.length;

    // Standart sapma — başarı dağılımının homojenliği
    const meanScore = avg(scores);
    const variance = avg(scores.map(s => (s - meanScore) ** 2));
    const stdDev = Math.sqrt(variance);

    const avgScore = Math.round(meanScore * 100) / 100;
    const avgCompletion = Math.round(avg(completions) * 10000) / 100; // % iki ondalık
    const avgHints = Math.round(avg(hints) * 100) / 100;
    const avgLetters = Math.round(avg(lettersRev) * 100) / 100;
    const avgWords = Math.round(avg(wordsRev) * 100) / 100;
    const avgDuration = Math.round(avg(durations));

    // Hem uzun (averageX) hem kısa (avgX) anahtarları döndür — UI rahatça okusun
    return {
      studentCount: students.length,
      finishedCount,
      totalWords,
      averageScore: avgScore, avgScore,
      averageCompletion: avgCompletion, avgCompletion,
      averageHintsUsed: avgHints, avgHintsUsed: avgHints,
      averageDurationSeconds: avgDuration, avgDuration,
      avgLettersRevealed: avgLetters,
      avgWordsRevealed: avgWords,
      medianScore: Math.round(median * 100) / 100,
      topScore: scores.length === 0 ? 0 : Math.max(...scores),
      lowScore: scores.length === 0 ? 0 : Math.min(...scores),
      stdDeviation: Math.round(stdDev * 100) / 100,
      passRate: Math.round((passingCount / students.length) * 10000) / 100, // %
    };
  }

  function endGame(roomCode, reason = 'completed') {
    const room = classroomRooms.get(roomCode);
    if (!room || room.status === 'finished') return;

    room.status = 'finished';
    room.finishedAt = Date.now();

    // Henüz bitirmemiş öğrencilere geçen süreyi ata (öğretmen erken bitirirse 0 kalmasin)
    const gameElapsed = room.gameStartedAt
      ? Math.round((room.finishedAt - room.gameStartedAt) / 1000)
      : 0;
    for (const p of room.players) {
      if (p.isTeacher || p.isFinished) continue;
      if ((!p.durationSeconds || p.durationSeconds === 0) && gameElapsed > 0) {
        p.durationSeconds = gameElapsed;
      }
    }

    const totalWords = room.puzzleData?.words?.length || 0;
    const students = room.players.filter(p => !p.isTeacher);

    const results = students.map(p => ({
      id: p.id,
      userId: p.userId,
      displayName: p.displayName,
      score: p.score || 0,
      completedWords: p.completedWords || 0,
      totalWords: p.totalWords || totalWords,
      hintsUsed: p.hintsUsed || 0,
      lettersRevealed: p.lettersRevealed || 0,
      wordsRevealed: p.wordsRevealed || 0,
      progress: p.progress || 0,
      isFinished: !!p.isFinished,
      finishOrder: p.finishOrder ?? 9999,
      durationSeconds: p.durationSeconds || 0,
      completionRate: totalWords > 0
        ? Math.round((p.completedWords || 0) / totalWords * 10000) / 100
        : 0,
    }));

    // Sıralama: önce bitirenler (skor → süre), sonra ilerlemeye göre
    results.sort((a, b) => {
      if (a.isFinished !== b.isFinished) return a.isFinished ? -1 : 1;
      if (a.isFinished && b.isFinished) {
        if (b.score !== a.score) return b.score - a.score;
        return a.durationSeconds - b.durationSeconds;
      }
      if (b.completedWords !== a.completedWords) return b.completedWords - a.completedWords;
      return (b.score || 0) - (a.score || 0);
    });
    results.forEach((r, i) => { r.rank = i + 1; });

    const aggregate = computeAggregateStats(room);

    addEvent(roomCode, 'game_ended', {
      reason,
      results,
      aggregate,
      gameDurationMs: room.finishedAt - (room.gameStartedAt || room.finishedAt),
      settings: room.settings,
      meta: room.meta,
    });

    // Öğretmenin arşivine kaydet (otomatik)
    try {
      const data = readClassroomData();
      const teacher = ensureTeacherEntry(data, room.hostUserId);
      const examRecord = {
        id: uuidv4(),
        roomCode: room.roomCode,
        title: room.meta?.title || 'Sınıf Sınavı',
        createdAt: room.createdAt,
        startedAt: room.gameStartedAt,
        finishedAt: room.finishedAt,
        durationMs: room.finishedAt - (room.gameStartedAt || room.finishedAt),
        settings: room.settings,
        meta: room.meta,
        questions: (room.puzzleData?.words || []).map(w => ({
          id: w.id,
          question: w.question,
          answer: w.answer,
        })),
        results,
        aggregate,
      };
      teacher.history.unshift(examRecord);
      // Maks 200 kayıt tut, ötesini düşür
      if (teacher.history.length > 200) teacher.history = teacher.history.slice(0, 200);
      writeClassroomData(data);
      console.log(`📚 [Sınıf] Sınav arşivlendi: ${room.roomCode} (öğretmen: ${room.hostUserId})`);
    } catch (e) {
      console.error('[Sınıf] Arşivleme hatası:', e.message);
    }

    console.log(`🏁 [Sınıf] Sınav bitti: ${roomCode} | ${reason} | ${students.length} öğrenci`);
  }

  // --------- Heartbeat / disconnect / süre tarayıcı ---------
  setInterval(() => {
    const now = Date.now();
    for (const [code, room] of classroomRooms.entries()) {
      if (room.status === 'finished') continue;
      let changed = false;

      // Heartbeat → disconnect tespiti
      for (const p of room.players) {
        if (p.lastHeartbeat && now - p.lastHeartbeat > 45000 && !p.disconnected) {
          p.disconnected = true;
          changed = true;
          addEvent(code, 'player_disconnected', { playerId: p.id, displayName: p.displayName });
          if (p.isTeacher) {
            if (room.status === 'waiting') {
              addEvent(code, 'room_closed', { reason: 'Öğretmen bağlantısı kesildi.' });
              setTimeout(() => classroomRooms.delete(code), 5000);
            } else if (room.status === 'playing') {
              endGame(code, 'teacher_disconnected');
            }
          }
        }
      }
      if (changed) addEvent(code, 'room_updated', sanitizeRoom(room));

      // Süre limiti otomatik bitiş — bağlantısı kopan öğrenci de kaybetmesin diye
      if (room.status === 'playing' &&
          room.settings?.timeLimit > 0 &&
          room.gameStartedAt) {
        const elapsed = (now - room.gameStartedAt) / 1000;
        if (elapsed >= room.settings.timeLimit) {
          // Henüz bitirmemiş öğrencileri "süre doldu" olarak kapat
          for (const p of room.players) {
            if (p.isTeacher || p.isFinished) continue;
            p.isFinished = true;
            p.durationSeconds = Math.round(elapsed);
            p.progress = p.totalWords > 0
              ? Math.round((p.completedWords / p.totalWords) * 100)
              : 0;
          }
          endGame(code, 'time_limit');
        }
      }
    }
  }, 5000);

  // ==================== ENDPOİNTLER ====================

  // Oda oluştur (öğretmen) — JWT zorunlu
  app.post('/api/classroom/rooms', authenticateToken, (req, res) => {
    try {
      const userId = req.user.id;
      const username = req.user.username;
      const { displayName, settings, meta } = req.body || {};

      const roomCode = generateClassroomCode();
      const teacherPlayerId = uuidv4();

      const safeSettings = {
        hintLimit: clampInt(settings?.hintLimit, 0, 50, 3),
        timeLimit: clampInt(settings?.timeLimit, 0, 7200, 0),     // saniye, 0=sınırsız
        maxStudents: clampInt(settings?.maxStudents, 1, 50, 50),
        gridSize: clampInt(settings?.gridSize, 10, 25, 15),
        showScoreboard: settings?.showScoreboard !== false,
        allowLetterHint: settings?.allowLetterHint !== false,
        allowWordHint: settings?.allowWordHint !== false,
      };

      const safeMeta = {
        title: (meta?.title || 'Sınıf Sınavı').toString().slice(0, 80),
        description: (meta?.description || '').toString().slice(0, 240),
      };

      const room = {
        roomCode,
        hostId: teacherPlayerId,
        hostUserId: userId,
        hostName: displayName || username || 'Öğretmen',
        status: 'waiting',
        settings: safeSettings,
        meta: safeMeta,
        players: [{
          id: teacherPlayerId,
          userId,
          displayName: displayName || username || 'Öğretmen',
          isTeacher: true,
          isReady: true,
          score: 0,
          completedWords: 0,
          totalWords: 0,
          progress: 0,
          hintsUsed: 0,
          lettersRevealed: 0,
          wordsRevealed: 0,
          isFinished: false,
          lastHeartbeat: Date.now(),
          disconnected: false,
          joinedAt: Date.now(),
        }],
        puzzleData: null,
        events: [],
        eventIdCounter: 0,
        pendingPolls: [],
        createdAt: Date.now(),
        gameStartedAt: null,
        finishedAt: null,
        lastActivityAt: Date.now(),
      };

      classroomRooms.set(roomCode, room);
      console.log(`🏫 [Sınıf] Oda oluşturuldu: ${roomCode} - öğretmen: ${room.hostName}`);

      res.json({
        success: true,
        roomCode,
        playerId: teacherPlayerId,
        room: sanitizeRoom(room),
      });
    } catch (e) {
      console.error('[Sınıf] Oda oluşturma hatası:', e);
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // Odaya katıl (öğrenci) — JWT zorunlu
  app.post('/api/classroom/rooms/:code/join', authenticateToken, (req, res) => {
    try {
      const { code } = req.params;
      const { displayName } = req.body || {};
      const room = classroomRooms.get(code);
      if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı. Kodu kontrol et.' });
      if (room.status === 'finished') return res.status(400).json({ success: false, message: 'Bu sınav sona erdi.' });

      const userId = req.user.id;

      // Aynı kullanıcı tekrar geldiyse: yerini güncelle (yeniden bağlanma)
      const existing = room.players.find(p => p.userId === userId);
      if (existing) {
        existing.lastHeartbeat = Date.now();
        existing.disconnected = false;
        existing.displayName = displayName || existing.displayName;
        addEvent(code, 'room_updated', sanitizeRoom(room));
        return res.json({
          success: true,
          roomCode: code,
          playerId: existing.id,
          isTeacher: existing.isTeacher,
          room: sanitizeRoom(room),
        });
      }

      const studentCount = room.players.filter(p => !p.isTeacher).length;
      if (studentCount >= room.settings.maxStudents) {
        return res.status(400).json({ success: false, message: 'Sınıf dolu.' });
      }
      if (room.status === 'playing') {
        return res.status(400).json({ success: false, message: 'Sınav başladı, geç katılım kapalı.' });
      }

      const playerId = uuidv4();
      const student = {
        id: playerId,
        userId,
        displayName: displayName || req.user.username || 'Öğrenci',
        isTeacher: false,
        isReady: false,
        score: 0,
        completedWords: 0,
        totalWords: 0,
        progress: 0,
        hintsUsed: 0,
        lettersRevealed: 0,
        wordsRevealed: 0,
        isFinished: false,
        lastHeartbeat: Date.now(),
        disconnected: false,
        joinedAt: Date.now(),
      };
      room.players.push(student);

      addEvent(code, 'room_updated', sanitizeRoom(room));
      addEvent(code, 'student_joined', {
        student: { id: playerId, displayName: student.displayName },
        studentCount: room.players.filter(p => !p.isTeacher).length,
      });

      console.log(`🎒 [Sınıf] Öğrenci katıldı: ${student.displayName} → ${code}`);
      res.json({
        success: true,
        roomCode: code,
        playerId,
        isTeacher: false,
        room: sanitizeRoom(room),
      });
    } catch (e) {
      console.error('[Sınıf] Katılma hatası:', e);
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // Oda durumunu getir
  app.get('/api/classroom/rooms/:code/state', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı' });
    res.json({ success: true, room: sanitizeRoom(room), lastEventId: room.eventIdCounter || 0 });
  });

  // Odaya hızlı bakış (kod onayı için, oturum gerektirmez)
  app.get('/api/classroom/rooms/:code/peek', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı' });
    res.json({
      success: true,
      roomCode: room.roomCode,
      hostName: room.hostName,
      title: room.meta?.title,
      status: room.status,
      studentCount: room.players.filter(p => !p.isTeacher).length,
      maxStudents: room.settings.maxStudents,
    });
  });

  // Ayarları güncelle (yalnız öğretmen, oyun başlamadan)
  app.post('/api/classroom/rooms/:code/settings', authenticateToken, (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı' });
    if (room.hostUserId !== req.user.id) return res.status(403).json({ success: false, message: 'Yalnızca öğretmen yetkili.' });
    if (room.status !== 'waiting') return res.status(400).json({ success: false, message: 'Sınav başladıktan sonra ayar değişmez.' });

    const { settings, meta } = req.body || {};
    if (settings) {
      if (settings.hintLimit !== undefined) room.settings.hintLimit = clampInt(settings.hintLimit, 0, 50, room.settings.hintLimit);
      if (settings.timeLimit !== undefined) room.settings.timeLimit = clampInt(settings.timeLimit, 0, 7200, room.settings.timeLimit);
      if (settings.maxStudents !== undefined) room.settings.maxStudents = clampInt(settings.maxStudents, 1, 50, room.settings.maxStudents);
      if (settings.gridSize !== undefined) room.settings.gridSize = clampInt(settings.gridSize, 10, 25, room.settings.gridSize);
      if (settings.showScoreboard !== undefined) room.settings.showScoreboard = !!settings.showScoreboard;
      if (settings.allowLetterHint !== undefined) room.settings.allowLetterHint = !!settings.allowLetterHint;
      if (settings.allowWordHint !== undefined) room.settings.allowWordHint = !!settings.allowWordHint;
    }
    if (meta) {
      if (meta.title !== undefined) room.meta.title = String(meta.title).slice(0, 80);
      if (meta.description !== undefined) room.meta.description = String(meta.description).slice(0, 240);
    }
    addEvent(req.params.code, 'room_updated', sanitizeRoom(room));
    res.json({ success: true });
  });

  // Sınavı başlat (öğretmen) — puzzle verisini yollar
  app.post('/api/classroom/rooms/:code/start', authenticateToken, (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı' });
    if (room.hostUserId !== req.user.id) return res.status(403).json({ success: false, message: 'Yalnızca öğretmen yetkili.' });
    if (room.status !== 'waiting') return res.status(400).json({ success: false, message: 'Sınav zaten başlatılmış.' });

    const { puzzleData } = req.body || {};
    if (!puzzleData || !Array.isArray(puzzleData.words) || puzzleData.words.length === 0) {
      return res.status(400).json({ success: false, message: 'Geçerli bulmaca verisi gerekli.' });
    }
    const studentCount = room.players.filter(p => !p.isTeacher).length;
    if (studentCount === 0) return res.status(400).json({ success: false, message: 'En az bir öğrenci gerekli.' });

    room.puzzleData = puzzleData;
    room.status = 'playing';
    room.gameStartedAt = Date.now();

    const totalWords = puzzleData.words.length;
    for (const p of room.players) {
      if (p.isTeacher) continue;
      p.score = 0;
      p.completedWords = 0;
      p.totalWords = totalWords;
      p.progress = 0;
      p.hintsUsed = 0;
      p.lettersRevealed = 0;
      p.wordsRevealed = 0;
      p.isFinished = false;
      p.finishOrder = null;
      p.durationSeconds = 0;
    }

    addEvent(req.params.code, 'game_started', {
      puzzleData,
      settings: room.settings,
      meta: room.meta,
      startedAt: room.gameStartedAt,
    });

    console.log(`🚀 [Sınıf] Sınav başladı: ${req.params.code} (${studentCount} öğrenci, ${totalWords} kelime)`);
    res.json({ success: true });
  });

  // Öğrenci ilerleme güncelle
  app.post('/api/classroom/rooms/:code/progress', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room || room.status !== 'playing') return res.json({ success: false });
    const { playerId, completedWords, totalWords, score, hintsUsed, lettersRevealed, wordsRevealed } = req.body || {};
    const player = findStudent(room, playerId);
    if (!player) return res.json({ success: false });

    if (typeof completedWords === 'number') player.completedWords = completedWords;
    if (typeof totalWords === 'number') player.totalWords = totalWords;
    if (typeof score === 'number') player.score = score;
    if (typeof hintsUsed === 'number') player.hintsUsed = hintsUsed;
    if (typeof lettersRevealed === 'number') player.lettersRevealed = lettersRevealed;
    if (typeof wordsRevealed === 'number') player.wordsRevealed = wordsRevealed;

    player.progress = (player.totalWords || 0) > 0
      ? Math.round((player.completedWords / player.totalWords) * 100)
      : 0;
    player.lastHeartbeat = Date.now();

    // Yalnız öğretmene gönder (öğrenciler birbirini izlemesin diye trafiği azalt)
    const teacher = findTeacher(room);
    if (teacher) {
      addEvent(req.params.code, 'player_progress', {
        playerId,
        displayName: player.displayName,
        completedWords: player.completedWords,
        totalWords: player.totalWords,
        score: player.score,
        progress: player.progress,
        hintsUsed: player.hintsUsed,
        lettersRevealed: player.lettersRevealed,
        wordsRevealed: player.wordsRevealed,
      }, teacher.id);
    }
    res.json({ success: true });
  });

  // Öğrenci tamamladı
  app.post('/api/classroom/rooms/:code/finished', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room || room.status !== 'playing') return res.status(400).json({ success: false });
    const { playerId, score, completedWords, totalWords, hintsUsed, lettersRevealed, wordsRevealed, durationSeconds } = req.body || {};
    const player = findStudent(room, playerId);
    if (!player || player.isFinished) return res.status(400).json({ success: false });

    player.isFinished = true;
    if (typeof score === 'number') player.score = score;
    if (typeof completedWords === 'number') player.completedWords = completedWords;
    if (typeof totalWords === 'number') player.totalWords = totalWords;
    if (typeof hintsUsed === 'number') player.hintsUsed = hintsUsed;
    if (typeof lettersRevealed === 'number') player.lettersRevealed = lettersRevealed;
    if (typeof wordsRevealed === 'number') player.wordsRevealed = wordsRevealed;
    player.durationSeconds = typeof durationSeconds === 'number' ? durationSeconds : 0;
    player.progress = 100;

    const finishedStudents = room.players.filter(p => !p.isTeacher && p.isFinished);
    player.finishOrder = finishedStudents.length;

    addEvent(req.params.code, 'player_finished', {
      playerId,
      displayName: player.displayName,
      score: player.score,
      finishOrder: player.finishOrder,
      durationSeconds: player.durationSeconds,
      hintsUsed: player.hintsUsed,
      completedWords: player.completedWords,
      totalWords: player.totalWords,
    });

    const allDone = room.players.filter(p => !p.isTeacher).every(p => p.isFinished);
    if (allDone) endGame(req.params.code, 'all_finished');

    res.json({ success: true });
  });

  // Öğretmen sınavı zorla bitir
  app.post('/api/classroom/rooms/:code/end', authenticateToken, (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ success: false });
    if (room.hostUserId !== req.user.id) return res.status(403).json({ success: false, message: 'Yetkiniz yok.' });
    if (room.status !== 'playing') return res.status(400).json({ success: false, message: 'Sınav aktif değil.' });
    endGame(req.params.code, 'teacher_ended');
    res.json({ success: true });
  });

  // Öğretmen öğrenciyi at
  app.post('/api/classroom/rooms/:code/kick', authenticateToken, (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ success: false });
    if (room.hostUserId !== req.user.id) return res.status(403).json({ success: false, message: 'Yetkiniz yok.' });
    const { studentId } = req.body || {};
    const idx = room.players.findIndex(p => p.id === studentId && !p.isTeacher);
    if (idx === -1) return res.status(404).json({ success: false, message: 'Öğrenci bulunamadı.' });
    const removed = room.players.splice(idx, 1)[0];
    addEvent(req.params.code, 'student_kicked', {
      studentId,
      displayName: removed.displayName,
    });
    addEvent(req.params.code, 'room_updated', sanitizeRoom(room));
    res.json({ success: true });
  });

  // Ayrıl (öğretmen ya da öğrenci)
  app.post('/api/classroom/rooms/:code/leave', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.json({ success: true });
    const { playerId } = req.body || {};
    const idx = room.players.findIndex(p => p.id === playerId);
    if (idx === -1) return res.json({ success: true });
    const player = room.players[idx];

    if (player.isTeacher) {
      // Öğretmen ayrıldıysa odayı kapat / sınavı bitir
      if (room.status === 'playing') {
        endGame(req.params.code, 'teacher_left');
      } else {
        addEvent(req.params.code, 'room_closed', { reason: 'Öğretmen odayı kapattı.' });
        setTimeout(() => classroomRooms.delete(req.params.code), 5000);
      }
    } else {
      room.players.splice(idx, 1);
      addEvent(req.params.code, 'student_left', {
        studentId: playerId,
        displayName: player.displayName,
      });
      addEvent(req.params.code, 'room_updated', sanitizeRoom(room));
    }
    res.json({ success: true });
  });

  // Heartbeat
  app.post('/api/classroom/rooms/:code/heartbeat', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.json({ success: false });
    const { playerId } = req.body || {};
    const player = room.players.find(p => p.id === playerId);
    if (player) {
      player.lastHeartbeat = Date.now();
      if (player.disconnected) {
        player.disconnected = false;
        addEvent(req.params.code, 'room_updated', sanitizeRoom(room));
      }
    }
    res.json({ success: true, timestamp: Date.now() });
  });

  // Long polling
  app.get('/api/classroom/rooms/:code/poll', (req, res) => {
    const room = classroomRooms.get(req.params.code);
    if (!room) return res.status(404).json({ events: [], error: 'Oda yok' });

    const sinceId = parseInt(req.query.since) || 0;
    const playerId = req.query.playerId;

    if (playerId) {
      const player = room.players.find(p => p.id === playerId);
      if (player) {
        player.lastHeartbeat = Date.now();
        if (player.disconnected) player.disconnected = false;
      }
    }

    const events = getEventsForPlayer(room, sinceId, playerId);
    if (events.length > 0) return res.json({ events });

    if (!room.pendingPolls) room.pendingPolls = [];
    const timeoutId = setTimeout(() => {
      if (room.pendingPolls) {
        room.pendingPolls = room.pendingPolls.filter(p => p.res !== res);
      }
      if (!res.headersSent) res.json({ events: [] });
    }, 25000);
    room.pendingPolls.push({ res, playerId, sinceId, timeoutId });

    req.on('close', () => {
      clearTimeout(timeoutId);
      if (room.pendingPolls) {
        room.pendingPolls = room.pendingPolls.filter(p => p.res !== res);
      }
    });
  });

  // ==================== ÖZEL SORU BANKASI ====================
  app.get('/api/classroom/questions', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    writeClassroomData(data); // teacher entry'yi kalıcılaştırmak için
    res.json({ success: true, questions: teacher.customQuestions });
  });

  app.post('/api/classroom/questions', authenticateToken, (req, res) => {
    const { questions } = req.body || {};
    if (!Array.isArray(questions) || questions.length === 0) {
      return res.status(400).json({ success: false, message: 'Soru listesi gerekli.' });
    }
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    const added = [];
    for (const q of questions) {
      const question = (q.question || '').toString().trim();
      const answer = (q.answer || '').toString().trim();
      if (!question || !answer) continue;
      if (question.length > 240) continue;
      if (answer.replace(/\s/g, '').length < 2 || answer.length > 30) continue;
      const item = {
        id: q.id || `cq_${uuidv4()}`,
        question,
        answer,
        difficulty: clampInt(q.difficulty, 1, 3, 2),
        categoryName: (q.categoryName || 'Özel Sorular').toString().slice(0, 60),
        createdAt: new Date().toISOString(),
      };
      // Aynı (soru,cevap) zaten varsa atla
      const dup = teacher.customQuestions.find(x =>
        x.question.toLowerCase() === item.question.toLowerCase() &&
        x.answer.toLowerCase() === item.answer.toLowerCase()
      );
      if (dup) continue;
      teacher.customQuestions.push(item);
      added.push(item);
    }
    writeClassroomData(data);
    res.json({ success: true, added, total: teacher.customQuestions.length });
  });

  app.delete('/api/classroom/questions/:id', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    const before = teacher.customQuestions.length;
    teacher.customQuestions = teacher.customQuestions.filter(q => q.id !== req.params.id);
    writeClassroomData(data);
    res.json({ success: true, removed: before - teacher.customQuestions.length });
  });

  app.delete('/api/classroom/questions', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    const before = teacher.customQuestions.length;
    teacher.customQuestions = [];
    writeClassroomData(data);
    res.json({ success: true, removed: before });
  });

  // ==================== SINAV ARŞİVİ ====================
  app.get('/api/classroom/history', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    writeClassroomData(data);
    // Liste, kart üstünde detay göstermek için nested alanlarla dönüyor:
    // meta, aggregate, results dahil. (Soru gövdesi yine /history/:id ile alınır.)
    const summaries = teacher.history.map(h => ({
      id: h.id,
      roomCode: h.roomCode,
      title: h.title,
      meta: h.meta,
      createdAt: h.createdAt,
      startedAt: h.startedAt,
      finishedAt: h.finishedAt,
      durationMs: h.durationMs,
      settings: h.settings,
      questionCount: h.questions?.length || 0,
      studentCount: h.aggregate?.studentCount || h.results?.length || 0,
      aggregate: h.aggregate || {},
      results: h.results || [],
    }));
    res.json({ success: true, history: summaries });
  });

  app.get('/api/classroom/history/:id', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    const item = teacher.history.find(h => h.id === req.params.id);
    if (!item) return res.status(404).json({ success: false, message: 'Kayıt bulunamadı' });
    res.json({ success: true, record: item });
  });

  app.delete('/api/classroom/history/:id', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    const before = teacher.history.length;
    teacher.history = teacher.history.filter(h => h.id !== req.params.id);
    writeClassroomData(data);
    res.json({ success: true, removed: before - teacher.history.length });
  });

  app.delete('/api/classroom/history', authenticateToken, (req, res) => {
    const data = readClassroomData();
    const teacher = ensureTeacherEntry(data, req.user.id);
    const before = teacher.history.length;
    teacher.history = [];
    writeClassroomData(data);
    res.json({ success: true, removed: before });
  });

  // --------- ufak yardımcı ---------
  function clampInt(v, min, max, def) {
    const n = parseInt(v);
    if (Number.isNaN(n)) return def;
    return Math.min(Math.max(n, min), max);
  }

  console.log('✅ Sınıf Modu REST API yüklendi (/api/classroom)');
};
