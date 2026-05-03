// ==================== ÇOKLU OYUNCU REST API + LONG POLLING ====================
// Socket.IO yerine saf HTTP REST API + Long Polling sistemi.
// Cloudflare üzerinden sorunsuz çalışır (WebSocket gerektirmez).
// Tüm iletişim HTTP GET/POST ile yapılır.

const { v4: uuidv4 } = require('uuid');

module.exports = function (app, activeRooms, publicRooms, generateRoomCode) {

  // ==================== EVENT QUEUE SYSTEM ====================
  // Her oda bir event kuyruğuna sahip.
  // Long polling: client GET /api/mp/rooms/:roomCode/poll?since=<id>&playerId=<pid>
  // Yeni event varsa hemen döner, yoksa 25 sn bekler.

  function addEvent(roomCode, type, data, targetPlayerId = null) {
    const room = activeRooms.get(roomCode);
    if (!room) return;
    if (!room.events) room.events = [];
    if (room.eventIdCounter === undefined) room.eventIdCounter = 0;
    room.eventIdCounter++;
    const event = {
      id: room.eventIdCounter,
      type,
      data,
      timestamp: Date.now(),
      targetPlayerId, // null = herkese, string = sadece o oyuncuya
    };
    room.events.push(event);
    // Son 200 event'i tut
    if (room.events.length > 200) room.events = room.events.slice(-100);
    // Bekleyen poll'ları çöz
    resolvePendingPolls(roomCode);
  }

  function resolvePendingPolls(roomCode) {
    const room = activeRooms.get(roomCode);
    if (!room || !room.pendingPolls || room.pendingPolls.length === 0) return;
    const toResolve = [...room.pendingPolls];
    room.pendingPolls = [];
    for (const poll of toResolve) {
      clearTimeout(poll.timeoutId);
      const events = getEventsForPlayer(room, poll.sinceId, poll.playerId);
      try {
        if (!poll.res.headersSent) {
          poll.res.json({ events });
        }
      } catch (e) { /* client disconnected */ }
    }
  }

  function getEventsForPlayer(room, sinceId, playerId) {
    if (!room.events) return [];
    return room.events
      .filter(e => e.id > sinceId && (e.targetPlayerId === null || e.targetPlayerId === playerId))
      .map(e => ({ id: e.id, type: e.type, data: e.data, timestamp: e.timestamp }));
  }

  // ==================== ROOM HELPERS ====================

  function sanitizeRoom(room) {
    return {
      id: room.roomCode,
      roomCode: room.roomCode,
      hostId: room.hostId,
      hostName: room.hostName,
      status: room.status,
      settings: room.settings,
      players: room.players.map(p => ({
        id: p.id,
        displayName: p.displayName,
        isHost: p.isHost,
        isReady: p.isReady,
        score: p.score,
        completedWords: p.completedWords,
        totalWords: p.totalWords,
        progress: p.progress,
        hintsUsed: p.hintsUsed,
        isFinished: p.isFinished,
        finishOrder: p.finishOrder,
        durationSeconds: p.durationSeconds,
      })),
      playerCount: room.players.length,
      createdAt: room.createdAt,
    };
  }

  function endGame(roomCode) {
    const room = activeRooms.get(roomCode);
    if (!room) return;

    room.status = 'finished';
    room.finishedAt = Date.now();

    const results = room.players
      .map(p => ({
        id: p.id,
        displayName: p.displayName,
        isHost: p.isHost,
        score: p.score,
        completedWords: p.completedWords,
        totalWords: p.totalWords,
        hintsUsed: p.hintsUsed,
        progress: p.progress,
        isFinished: p.isFinished,
        finishOrder: p.finishOrder ?? 999,
        durationSeconds: p.durationSeconds ?? 0,
      }))
      .sort((a, b) => {
        if (a.isFinished && !b.isFinished) return -1;
        if (!a.isFinished && b.isFinished) return 1;
        if (a.isFinished && b.isFinished) {
          if (b.score !== a.score) return b.score - a.score;
          return a.finishOrder - b.finishOrder;
        }
        return b.progress - a.progress;
      });

    results.forEach((r, i) => { r.rank = i + 1; });

    addEvent(roomCode, 'game_ended', {
      results,
      gameDuration: room.finishedAt - room.gameStartedAt,
      settings: room.settings,
    });

    // Tüm bekleyen poll'ları çöz (game_ended gönderildi)
    // pendingPolls zaten resolvePendingPolls ile çözülüyor

    console.log(`🏆 Oyun bitti: ${roomCode} - Kazanan: ${results[0]?.displayName || 'Yok'}`);
  }

  function handlePlayerLeave(roomCode, playerId) {
    if (!roomCode || !playerId) return;

    const room = activeRooms.get(roomCode);
    if (!room) return;

    const playerIndex = room.players.findIndex(p => p.id === playerId);
    if (playerIndex === -1) return;

    const player = room.players[playerIndex];
    const wasHost = player.isHost;

    // Oyun oynandıysa
    if (room.status === 'playing') {
      if (wasHost) {
        addEvent(roomCode, 'game_cancelled', {
          reason: 'Ev sahibi oyundan ayrıldı. Maç iptal edildi.',
          hostName: player.displayName,
        });
        room.status = 'finished';
        room.finishedAt = Date.now();
        // Bekleyen poll'ları çöz
        resolvePendingPolls(roomCode);
        // Temizlik
        setTimeout(() => {
          activeRooms.delete(roomCode);
          publicRooms.delete(roomCode);
        }, 5000);
        console.log(`❌ Maç iptal edildi (ev sahibi ayrıldı): ${roomCode}`);
        return;
      }

      // Normal oyuncu ayrıldıysa
      player.disconnected = true;
      addEvent(roomCode, 'player_disconnected', {
        playerId,
        displayName: player.displayName,
      });

      const allDisconnected = room.players.every(p => p.disconnected);
      if (allDisconnected) {
        activeRooms.delete(roomCode);
        publicRooms.delete(roomCode);
        console.log(`🗑️  Oda silindi (tüm oyuncular ayrıldı): ${roomCode}`);
      }
      return;
    }

    // Bekleme sırasında çıkarsa oyuncuyu kaldır
    room.players.splice(playerIndex, 1);

    if (room.players.length === 0) {
      activeRooms.delete(roomCode);
      publicRooms.delete(roomCode);
      console.log(`🗑️  Oda silindi (boş): ${roomCode}`);
      return;
    }

    // Host ayrıldıysa yeni host ata
    if (wasHost && room.players.length > 0) {
      room.players[0].isHost = true;
      room.players[0].isReady = true;
      room.hostId = room.players[0].id;
      room.hostName = room.players[0].displayName;
    }

    addEvent(roomCode, 'room_updated', sanitizeRoom(room));
    addEvent(roomCode, 'player_left', {
      playerId,
      displayName: player.displayName,
      playerCount: room.players.length,
      newHostId: wasHost ? room.hostId : null,
    });

    console.log(`👋 ${player.displayName} odadan ayrıldı: ${roomCode}`);
  }

  // ==================== HEARTBEAT & DISCONNECT DETECTION ====================
  setInterval(() => {
    const now = Date.now();
    for (const [roomCode, room] of activeRooms.entries()) {
      if (room.status === 'finished') continue;
      for (const player of room.players) {
        if (player.lastHeartbeat && now - player.lastHeartbeat > 30000 && !player.disconnected) {
          player.disconnected = true;
          console.log(`💔 Heartbeat timeout: ${player.displayName} (${roomCode})`);
          addEvent(roomCode, 'player_disconnected', {
            playerId: player.id,
            displayName: player.displayName,
          });
          // Host disconnect during game → cancel
          if (player.isHost && room.status === 'playing') {
            addEvent(roomCode, 'game_cancelled', {
              reason: 'Ev sahibi bağlantısı kesildi. Maç iptal edildi.',
              hostName: player.displayName,
            });
            room.status = 'finished';
            room.finishedAt = Date.now();
          }
        }
      }
    }
  }, 15000);

  // ==================== REST API ENDPOINTS ====================

  // --- ODA OLUŞTUR ---
  app.post('/api/mp/rooms', (req, res) => {
    try {
      const { displayName, userId, settings } = req.body || {};
      const roomCode = generateRoomCode();
      const playerId = userId || uuidv4();

      const room = {
        roomCode,
        hostId: playerId,
        hostName: displayName || 'Anonim',
        status: 'waiting',
        createdAt: Date.now(),
        finishedAt: null,
        settings: {
          categoryId: settings?.categoryId || 'mixed',
          categoryName: settings?.categoryName || 'Karışık',
          difficulty: settings?.difficulty ?? 0,
          wordCount: settings?.wordCount || 10,
          gridSize: settings?.gridSize || 15,
          hintLimit: settings?.hintLimit ?? 3,
          timeLimit: settings?.timeLimit || 0,
          maxPlayers: settings?.maxPlayers || 8,
          isPublic: settings?.isPublic || false,
        },
        players: [{
          id: playerId,
          displayName: displayName || 'Anonim',
          isHost: true,
          isReady: true,
          score: 0,
          completedWords: 0,
          totalWords: 0,
          hintsUsed: 0,
          progress: 0,
          finishedAt: null,
          isFinished: false,
          lastHeartbeat: Date.now(),
          disconnected: false,
        }],
        puzzleData: null,
        gameStartedAt: null,
        events: [],
        eventIdCounter: 0,
        pendingPolls: [],
      };

      activeRooms.set(roomCode, room);
      if (room.settings.isPublic) publicRooms.set(roomCode, room);

      console.log(`🏠 [REST] Oda oluşturuldu: ${roomCode} - ${displayName}`);

      res.json({
        success: true,
        roomCode,
        playerId,
        room: sanitizeRoom(room),
      });
    } catch (error) {
      console.error(`❌ [REST] Oda oluşturma hatası: ${error.message}`);
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // --- ODAYA KATIL ---
  app.post('/api/mp/rooms/:roomCode/join', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { displayName, userId } = req.body || {};
      const room = activeRooms.get(roomCode);

      if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı. Kodu kontrol edin.' });
      if (room.status !== 'waiting') return res.status(400).json({ success: false, message: 'Oyun zaten başlamış.' });
      if (room.players.length >= room.settings.maxPlayers) return res.status(400).json({ success: false, message: 'Oda dolu.' });

      const playerId = userId || uuidv4();

      // Aynı kullanıcı tekrar katılırsa
      const existing = room.players.find(p => p.id === playerId);
      if (existing) {
        existing.lastHeartbeat = Date.now();
        existing.disconnected = false;
        addEvent(roomCode, 'room_updated', sanitizeRoom(room));
        return res.json({ success: true, roomCode, playerId, room: sanitizeRoom(room) });
      }

      const player = {
        id: playerId,
        displayName: displayName || 'Anonim',
        isHost: false,
        isReady: false,
        score: 0,
        completedWords: 0,
        totalWords: 0,
        hintsUsed: 0,
        progress: 0,
        finishedAt: null,
        isFinished: false,
        lastHeartbeat: Date.now(),
        disconnected: false,
      };

      room.players.push(player);

      addEvent(roomCode, 'room_updated', sanitizeRoom(room));
      addEvent(roomCode, 'player_joined', {
        player: { id: player.id, displayName: player.displayName },
        playerCount: room.players.length,
      });

      console.log(`👤 [REST] ${displayName} odaya katıldı: ${roomCode} (${room.players.length} kişi)`);

      res.json({ success: true, roomCode, playerId, room: sanitizeRoom(room) });
    } catch (error) {
      console.error(`❌ [REST] Katılma hatası: ${error.message}`);
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // --- ODA AYARLARINI GÜNCELLE ---
  app.post('/api/mp/rooms/:roomCode/settings', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId, settings } = req.body || {};
      const room = activeRooms.get(roomCode);

      if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı.' });
      if (room.hostId !== playerId) return res.status(403).json({ success: false, message: 'Yetkiniz yok.' });
      if (room.status !== 'waiting') return res.status(400).json({ success: false, message: 'Oyun başladıktan sonra ayarlar değiştirilemez.' });

      if (settings) {
        if (settings.categoryId !== undefined) room.settings.categoryId = settings.categoryId;
        if (settings.categoryName !== undefined) room.settings.categoryName = settings.categoryName;
        if (settings.difficulty !== undefined) room.settings.difficulty = settings.difficulty;
        if (settings.wordCount !== undefined) room.settings.wordCount = settings.wordCount;
        if (settings.gridSize !== undefined) room.settings.gridSize = settings.gridSize;
        if (settings.hintLimit !== undefined) room.settings.hintLimit = settings.hintLimit;
        if (settings.timeLimit !== undefined) room.settings.timeLimit = settings.timeLimit;
        if (settings.maxPlayers !== undefined) room.settings.maxPlayers = settings.maxPlayers;
        if (settings.isPublic !== undefined) {
          room.settings.isPublic = settings.isPublic;
          if (settings.isPublic) publicRooms.set(roomCode, room);
          else publicRooms.delete(roomCode);
        }
      }

      addEvent(roomCode, 'room_updated', sanitizeRoom(room));
      console.log(`⚙️  [REST] Oda ayarları güncellendi: ${roomCode}`);

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // --- HAZIR DURUMU DEĞİŞTİR ---
  app.post('/api/mp/rooms/:roomCode/ready', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId } = req.body || {};
      const room = activeRooms.get(roomCode);
      if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı.' });

      const player = room.players.find(p => p.id === playerId);
      if (!player) return res.status(404).json({ success: false, message: 'Oyuncu bulunamadı.' });

      player.isReady = !player.isReady;
      addEvent(roomCode, 'room_updated', sanitizeRoom(room));

      res.json({ success: true, isReady: player.isReady });
    } catch (error) {
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // --- OYUNU BAŞLAT ---
  app.post('/api/mp/rooms/:roomCode/start', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId, puzzleData } = req.body || {};
      const room = activeRooms.get(roomCode);

      if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı.' });
      if (room.hostId !== playerId) return res.status(403).json({ success: false, message: 'Sadece oda sahibi oyunu başlatabilir.' });
      if (room.players.length < 2) return res.status(400).json({ success: false, message: 'Oyunu başlatmak için en az 2 kişi gerekli.' });

      const notReady = room.players.filter(p => !p.isHost && !p.isReady);
      if (notReady.length > 0) {
        return res.status(400).json({
          success: false,
          message: `${notReady.map(p => p.displayName).join(', ')} henüz hazır değil.`,
        });
      }

      room.puzzleData = puzzleData;
      room.status = 'playing';
      room.gameStartedAt = Date.now();

      room.players.forEach(p => {
        p.score = 0;
        p.completedWords = 0;
        p.totalWords = puzzleData?.words ? puzzleData.words.length : 0;
        p.hintsUsed = 0;
        p.progress = 0;
        p.finishedAt = null;
        p.isFinished = false;
      });

      addEvent(roomCode, 'game_started', {
        puzzleData: room.puzzleData,
        settings: room.settings,
        startTime: room.gameStartedAt,
        players: room.players.map(p => ({
          id: p.id,
          displayName: p.displayName,
          isHost: p.isHost,
        })),
      });

      console.log(`🎮 [REST] Oyun başladı: ${roomCode} (${room.players.length} oyuncu)`);

      res.json({ success: true });
    } catch (error) {
      console.error(`❌ [REST] Oyun başlatma hatası: ${error.message}`);
      res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
  });

  // --- İLERLEME GÜNCELLE ---
  app.post('/api/mp/rooms/:roomCode/progress', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId, completedWords, totalWords, score, hintsUsed } = req.body || {};
      const room = activeRooms.get(roomCode);
      if (!room || room.status !== 'playing') return res.json({ success: false });

      const player = room.players.find(p => p.id === playerId);
      if (!player) return res.json({ success: false });

      player.completedWords = completedWords ?? player.completedWords;
      player.totalWords = totalWords ?? player.totalWords;
      player.score = score ?? player.score;
      player.hintsUsed = hintsUsed ?? player.hintsUsed;
      player.progress = player.totalWords > 0 ? Math.round((player.completedWords / player.totalWords) * 100) : 0;

      // İlerleme event'ini diğer oyunculara gönder (kendisi hariç)
      for (const otherPlayer of room.players) {
        if (otherPlayer.id !== playerId) {
          addEvent(roomCode, 'player_progress', {
            playerId,
            displayName: player.displayName,
            completedWords: player.completedWords,
            totalWords: player.totalWords,
            score: player.score,
            progress: player.progress,
            hintsUsed: player.hintsUsed,
          }, otherPlayer.id);
        }
      }

      res.json({ success: true });
    } catch (error) {
      res.json({ success: false });
    }
  });

  // --- OYUNCU BİTİRDİ ---
  app.post('/api/mp/rooms/:roomCode/finished', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId, score, completedWords, totalWords, hintsUsed, durationSeconds } = req.body || {};
      const room = activeRooms.get(roomCode);
      if (!room || room.status !== 'playing') return res.status(400).json({ success: false });

      const player = room.players.find(p => p.id === playerId);
      if (!player || player.isFinished) return res.status(400).json({ success: false });

      player.isFinished = true;
      player.finishedAt = Date.now();
      player.score = score ?? 0;
      player.completedWords = completedWords ?? player.completedWords;
      player.totalWords = totalWords ?? player.totalWords;
      player.hintsUsed = hintsUsed ?? player.hintsUsed;
      player.progress = 100;
      player.durationSeconds = durationSeconds ?? 0;

      const finishedPlayers = room.players.filter(p => p.isFinished);
      player.finishOrder = finishedPlayers.length;

      addEvent(roomCode, 'player_completed', {
        playerId,
        displayName: player.displayName,
        score: player.score,
        finishOrder: player.finishOrder,
        completedWords: player.completedWords,
        totalWords: player.totalWords,
        durationSeconds: player.durationSeconds,
      });

      if (room.players.every(p => p.isFinished)) {
        endGame(roomCode);
      }

      console.log(`🏁 [REST] ${player.displayName} bitirdi: ${roomCode} (${player.finishOrder}. sıra, ${player.score} puan)`);

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ success: false });
    }
  });

  // --- OYUNU ZORLA BİTİR ---
  app.post('/api/mp/rooms/:roomCode/end', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId } = req.body || {};
      const room = activeRooms.get(roomCode);
      if (!room || room.status !== 'playing') return res.status(400).json({ success: false });
      if (room.hostId !== playerId) return res.status(403).json({ success: false, message: 'Yetkiniz yok.' });

      endGame(roomCode);

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ success: false });
    }
  });

  // --- ODADAN AYRIL ---
  app.post('/api/mp/rooms/:roomCode/leave', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId } = req.body || {};

      handlePlayerLeave(roomCode, playerId);

      res.json({ success: true });
    } catch (error) {
      res.json({ success: true }); // Ayrılma her zaman başarılı sayılır
    }
  });

  // --- MESAJ GÖNDER ---
  app.post('/api/mp/rooms/:roomCode/chat', (req, res) => {
    try {
      const { roomCode } = req.params;
      const { playerId, message } = req.body || {};
      const room = activeRooms.get(roomCode);
      if (!room) return res.status(404).json({ success: false });

      const player = room.players.find(p => p.id === playerId);
      if (!player) return res.status(404).json({ success: false });

      addEvent(roomCode, 'chat_message', {
        playerId,
        displayName: player.displayName,
        message: (message || '').substring(0, 200),
        timestamp: Date.now(),
      });

      res.json({ success: true });
    } catch (error) {
      res.json({ success: false });
    }
  });

  // --- HEARTBEAT ---
  app.post('/api/mp/rooms/:roomCode/heartbeat', (req, res) => {
    const { roomCode } = req.params;
    const { playerId } = req.body || {};
    const room = activeRooms.get(roomCode);
    if (!room) return res.json({ success: false });

    const player = room.players.find(p => p.id === playerId);
    if (player) {
      player.lastHeartbeat = Date.now();
      if (player.disconnected) {
        player.disconnected = false;
        // Yeniden bağlandığını bildir
        addEvent(roomCode, 'room_updated', sanitizeRoom(room));
        console.log(`💚 [REST] Oyuncu yeniden bağlandı: ${player.displayName} (${roomCode})`);
      }
    }

    res.json({ success: true, timestamp: Date.now() });
  });

  // --- LONG POLLING ---
  app.get('/api/mp/rooms/:roomCode/poll', (req, res) => {
    const { roomCode } = req.params;
    const sinceId = parseInt(req.query.since) || 0;
    const playerId = req.query.playerId;
    const room = activeRooms.get(roomCode);

    if (!room) {
      return res.status(404).json({ events: [], error: 'Oda bulunamadı' });
    }

    // Heartbeat update (poll = alive)
    if (playerId) {
      const player = room.players.find(p => p.id === playerId);
      if (player) {
        player.lastHeartbeat = Date.now();
        if (player.disconnected) player.disconnected = false;
      }
    }

    // Hemen dönecek event var mı?
    const events = getEventsForPlayer(room, sinceId, playerId);
    if (events.length > 0) {
      return res.json({ events });
    }

    // Event yok - bağlantıyı aç tut (long poll)
    if (!room.pendingPolls) room.pendingPolls = [];

    const timeoutId = setTimeout(() => {
      if (room.pendingPolls) {
        room.pendingPolls = room.pendingPolls.filter(p => p.res !== res);
      }
      if (!res.headersSent) {
        res.json({ events: [] });
      }
    }, 25000); // 25 sn timeout (Cloudflare default 100s)

    room.pendingPolls.push({ res, playerId, sinceId, timeoutId });

    // Client bağlantıyı keserse temizle
    req.on('close', () => {
      clearTimeout(timeoutId);
      if (room.pendingPolls) {
        room.pendingPolls = room.pendingPolls.filter(p => p.res !== res);
      }
    });
  });

  // --- ODA BİLGİSİ (detaylı - katılanlar için) ---
  app.get('/api/mp/rooms/:roomCode/state', (req, res) => {
    const { roomCode } = req.params;
    const room = activeRooms.get(roomCode);
    if (!room) return res.status(404).json({ success: false, message: 'Oda bulunamadı' });
    res.json({ success: true, room: sanitizeRoom(room), lastEventId: room.eventIdCounter || 0 });
  });

  console.log('✅ Çoklu Oyuncu REST API + Long Polling sistemi yüklendi');
};
