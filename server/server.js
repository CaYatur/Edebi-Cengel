const fs = require('fs');
const path = require('path');

// .env dosyasını yükle (basit, dotenv bağımlılığı olmadan)
(function loadDotEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    // Çevreleyen tırnakları kaldır
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (key && !(key in process.env)) {
      process.env[key] = value;
    }
  }
  console.log('🔐 .env dosyası yüklendi');
})();

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const http = require('http');
const https = require('https');
const crypto = require('crypto');

const app = express();

// HTTP Sunucu
let server;
// Cloudflare URL normalizasyonu: Cloudflare /edebi-cengel-server/ prefix'ini
// HTTP isteklerinde soyabilir. Tüm istekleri normalize ediyoruz.
server = http.createServer((req, res) => {
  // HTTP istek URL'lerindeki prefix'i soy
  if (req.url && req.url.startsWith('/edebi-cengel-server/')) {
    req.url = req.url.replace('/edebi-cengel-server', '');
  }
  app(req, res);
});
console.log('✅ HTTP modunda çalışıyor (URL normalizasyonu aktif)');

const PORT = process.env.PORT || 9889;
if (!process.env.JWT_SECRET) {
  console.error('❌ HATA: JWT_SECRET ortam değişkeni tanımlanmamış. .env dosyasını oluştur.');
  process.exit(1);
}
const JWT_SECRET = process.env.JWT_SECRET;
const DATA_FILE = path.join(__dirname, 'data', 'users.json');
const AI_ENABLED = true; // true: açık, false: kapalı
const SERVER_DIR_NAME = path.basename(__dirname); // Dinamik sunucu dizin adı

// Debug: log AI_ENABLED during startup
if (process.env.AI_ENABLED) console.log(`[STARTUP] process.env.AI_ENABLED="${process.env.AI_ENABLED}" → AI_ENABLED=${AI_ENABLED}`);

// ==================== Middleware ====================
app.set('trust proxy', true); // Cloudflare proxy'yi güven

// DetailedLogging middleware tüm request'ler için
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const clientIp = req.ip || req.connection.remoteAddress || 'UNKNOWN';
  console.log(`[${timestamp}] 📨 REQUEST: ${req.method} ${req.path} | IP: ${clientIp}`);
  
  // Response logging
  const originalSend = res.send;
  res.send = function(data) {
    console.log(`[${timestamp}] ✅ RESPONSE: ${req.method} ${req.path} | Status: ${res.statusCode}`);
    return originalSend.call(this, data);
  };
  
  next();
});

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.options('*', cors()); // Preflight requests için

// ==================== Statik Dosyalar ====================
// Web uygulaması - Cloudflare /edebi-cengel/ yolundan serve edilir
const webBuildPath = path.join(__dirname, '..', 'cengel_bulmaca', 'build', 'web');
app.use('/edebi-cengel/', express.static(webBuildPath));

// SPA routing - /edebi-cengel/* istemleri index.html'ye yönlendir (API rotaları hariç)
app.get('/edebi-cengel/*', (req, res, next) => {
  // API istemleri geç
  if (req.path.startsWith('/edebi-cengel/api')) {
    return next();
  }
  // SPA routing için index.html'yi serve et
  res.sendFile(path.join(webBuildPath, 'index.html'));
});

// ==================== SAĞLIK KONTROLÜ ====================
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    socketIO: 'enabled'
  });
});

app.get('/test', (req, res) => {
  res.json({ 
    message: 'Sunucu çalışıyor',
    version: '1.0.2',
    socketConnections: io.engine.clientsCount || 0
  });
});

// ==================== Veri Dosyası İşlemleri ====================
function readData() {
  try {
    const raw = fs.readFileSync(DATA_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    return { users: [], lastUpdated: '' };
  }
}

function writeData(data) {
  data.lastUpdated = new Date().toISOString();
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
}

// ==================== Rate Limiting ====================
// IP bazlı kayıt sınırı: saatlik max 3
const registerAttempts = new Map(); // ip -> [{timestamp}]
// IP bazlı giriş sınırı: 10 dakikada max 5
const loginAttempts = new Map(); // ip -> [{timestamp}]

function cleanOldEntries(attempts, windowMs) {
  const now = Date.now();
  for (const [ip, times] of attempts.entries()) {
    const filtered = times.filter(t => now - t < windowMs);
    if (filtered.length === 0) {
      attempts.delete(ip);
    } else {
      attempts.set(ip, filtered);
    }
  }
}

// Her 5 dakikada temizlik
setInterval(() => {
  cleanOldEntries(registerAttempts, 60 * 60 * 1000);
  cleanOldEntries(loginAttempts, 10 * 60 * 1000);
}, 5 * 60 * 1000);

function checkRegisterLimit(ip) {
  const window = 60 * 60 * 1000; // 1 saat
  const maxAttempts = 3;
  const now = Date.now();
  const times = (registerAttempts.get(ip) || []).filter(t => now - t < window);
  return times.length < maxAttempts;
}

function recordRegisterAttempt(ip) {
  const times = registerAttempts.get(ip) || [];
  times.push(Date.now());
  registerAttempts.set(ip, times);
}

function checkLoginLimit(ip) {
  const window = 10 * 60 * 1000; // 10 dakika
  const maxAttempts = 5;
  const now = Date.now();
  const times = (loginAttempts.get(ip) || []).filter(t => now - t < window);
  return times.length < maxAttempts;
}

function recordLoginAttempt(ip) {
  const times = loginAttempts.get(ip) || [];
  times.push(Date.now());
  loginAttempts.set(ip, times);
}

// ==================== JWT Doğrulama Middleware ====================
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: 'Token gerekli' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Geçersiz veya süresi dolmuş token' });
    }
    req.user = user;
    next();
  });
}

// IP adresini al
function getClientIP(req) {
  return req.headers['x-forwarded-for'] || req.socket?.remoteAddress || req.ip;
}

// ==================== KAYIT ====================
app.post('/auth/register', (req, res) => {
  const ip = getClientIP(req);

  // Rate limit kontrolü
  if (!checkRegisterLimit(ip)) {
    return res.status(429).json({
      error: 'Çok fazla hesap oluşturma denemesi. Lütfen 1 saat sonra tekrar deneyin.'
    });
  }

  const { username, password, displayName } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Kullanıcı adı ve şifre zorunludur' });
  }

  if (username.length < 3 || username.length > 20) {
    return res.status(400).json({ error: 'Kullanıcı adı 3-20 karakter olmalıdır' });
  }

  if (password.length < 6) {
    return res.status(400).json({ error: 'Şifre en az 6 karakter olmalıdır' });
  }

  // Reserved namespace: _cyd suffix ve cyd_ prefix CaYaDev OAuth kullanıcılarına ait.
  // Manuel kayıtlar bu pattern'i kullanamaz → kullanıcılar "OAuth kullanıcısı kılığına"
  // giremez, gerçek OAuth user'ı login olduğunda namespace çakışması olmaz.
  if (isReservedOAuthUsername(username)) {
    return res.status(400).json({
      error: 'Bu kullanıcı adı CaYaDev hesapları için ayrılmıştır. Lütfen başka bir isim seçin.'
    });
  }

  const data = readData();

  // Kullanıcı adı kontrolü
  if (data.users.find(u => u.username.toLowerCase() === username.toLowerCase())) {
    return res.status(409).json({ error: 'Bu kullanıcı adı zaten kullanılıyor' });
  }

  recordRegisterAttempt(ip);

  // Şifreyi hashle
  const hashedPassword = bcrypt.hashSync(password, 10);

  const newUser = {
    id: uuidv4(),
    username: username,
    displayName: displayName || username,
    password: hashedPassword,
    stats: {
      totalScore: 0,
      totalPuzzlesCompleted: 0,
      totalWordsCompleted: 0,
      totalHintsUsed: 0,
      totalLettersRevealed: 0,
      totalWordsRevealed: 0,
      totalCellsFilled: 0,
      fastestPuzzleSeconds: 0,
      currentStreak: 0,
      bestStreak: 0,
      playedCategories: [],
      earnedBadgeIds: [],
      lastPlayedDate: null,
      // Konu bazlı başarı analizi (kategoriId -> kümülatif değer)
      categoryUserScores: {},
      categoryMaxScores: {},
      categoryPuzzleCounts: {},
      categoryWordsCorrect: {},
      categoryWordsTotal: {},
      categoryLastMissedClues: {}
    },
    createdAt: new Date().toISOString(),
    lastLoginAt: new Date().toISOString()
  };

  data.users.push(newUser);
  writeData(data);

  // Token oluştur
  const token = jwt.sign(
    { id: newUser.id, username: newUser.username },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  res.status(201).json({
    message: 'Hesap başarıyla oluşturuldu',
    token,
    user: {
      id: newUser.id,
      username: newUser.username,
      displayName: newUser.displayName,
      stats: newUser.stats
    }
  });
});

// ==================== GİRİŞ ====================
app.post('/auth/login', (req, res) => {
  const ip = getClientIP(req);

  // Rate limit kontrolü
  if (!checkLoginLimit(ip)) {
    return res.status(429).json({
      error: 'Çok fazla giriş denemesi. Lütfen 10 dakika sonra tekrar deneyin.'
    });
  }

  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Kullanıcı adı ve şifre zorunludur' });
  }

  recordLoginAttempt(ip);

  const data = readData();
  const user = data.users.find(u => u.username.toLowerCase() === username.toLowerCase());

  if (!user) {
    return res.status(401).json({ error: 'Kullanıcı adı veya şifre hatalı' });
  }

  if (!bcrypt.compareSync(password, user.password)) {
    return res.status(401).json({ error: 'Kullanıcı adı veya şifre hatalı' });
  }

  // Son giriş zamanını güncelle
  user.lastLoginAt = new Date().toISOString();
  writeData(data);

  const token = jwt.sign(
    { id: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  res.json({
    message: 'Giriş başarılı',
    token,
    user: {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      stats: user.stats
    }
  });
});

// ==================== PROFİL BİLGİSİ ====================
app.get('/user/profile', authenticateToken, (req, res) => {
  const data = readData();
  const user = data.users.find(u => u.id === req.user.id);

  if (!user) {
    return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
  }

  res.json({
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    stats: user.stats,
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt
  });
});

// ==================== İSTATİSTİK GÜNCELLE ====================
app.post('/user/stats/sync', authenticateToken, (req, res) => {
  const data = readData();
  const user = data.users.find(u => u.id === req.user.id);

  if (!user) {
    return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
  }

  const clientStats = req.body.stats;
  if (!clientStats) {
    return res.status(400).json({ error: 'İstatistik verisi gerekli' });
  }

  // Client verisi her zaman son durumdur (offline oynandığında biriken veriler)
  user.stats = {
    totalScore: clientStats.totalScore ?? user.stats.totalScore,
    totalPuzzlesCompleted: clientStats.totalPuzzlesCompleted ?? user.stats.totalPuzzlesCompleted,
    totalWordsCompleted: clientStats.totalWordsCompleted ?? user.stats.totalWordsCompleted,
    totalHintsUsed: clientStats.totalHintsUsed ?? user.stats.totalHintsUsed,
    totalLettersRevealed: clientStats.totalLettersRevealed ?? user.stats.totalLettersRevealed,
    totalWordsRevealed: clientStats.totalWordsRevealed ?? user.stats.totalWordsRevealed,
    totalCellsFilled: clientStats.totalCellsFilled ?? user.stats.totalCellsFilled,
    fastestPuzzleSeconds: clientStats.fastestPuzzleSeconds ?? user.stats.fastestPuzzleSeconds,
    currentStreak: clientStats.currentStreak ?? user.stats.currentStreak,
    bestStreak: clientStats.bestStreak ?? user.stats.bestStreak,
    playedCategories: clientStats.playedCategories ?? user.stats.playedCategories,
    earnedBadgeIds: clientStats.earnedBadgeIds ?? user.stats.earnedBadgeIds,
    lastPlayedDate: clientStats.lastPlayedDate ?? user.stats.lastPlayedDate,
    // Konu bazlı başarı analizi - client her zaman güncel kümülatif değerleri gönderir
    categoryUserScores: clientStats.categoryUserScores ?? user.stats.categoryUserScores ?? {},
    categoryMaxScores: clientStats.categoryMaxScores ?? user.stats.categoryMaxScores ?? {},
    categoryPuzzleCounts: clientStats.categoryPuzzleCounts ?? user.stats.categoryPuzzleCounts ?? {},
    categoryWordsCorrect: clientStats.categoryWordsCorrect ?? user.stats.categoryWordsCorrect ?? {},
    categoryWordsTotal: clientStats.categoryWordsTotal ?? user.stats.categoryWordsTotal ?? {},
    categoryLastMissedClues: clientStats.categoryLastMissedClues ?? user.stats.categoryLastMissedClues ?? {}
  };

  writeData(data);

  res.json({
    message: 'İstatistikler güncellendi',
    stats: user.stats
  });
});

// ==================== CAYADEV OAUTH 2.0 ====================
// CaYaDev OAuth ile giriş - client_secret sadece sunucuda tutulur.
// Akış: client /auth/cayadev/start çağırır → tarayıcıda authUrl açar →
// CaYaDev /auth/cayadev/callback'e yönlendirir → client /auth/cayadev/poll/:state
// ile JWT'yi alır.

const CAYADEV_AUTH_URL = process.env.CAYADEV_AUTH_URL || 'https://cayadev.com/oauth/authorize';
const CAYADEV_TOKEN_URL = process.env.CAYADEV_TOKEN_URL || 'https://cayadev.com/oauth/token';
const CAYADEV_USERINFO_URL = process.env.CAYADEV_USERINFO_URL || 'https://cayadev.com/oauth/userinfo';
const CAYADEV_CLIENT_ID = process.env.CAYADEV_CLIENT_ID || '';
const CAYADEV_CLIENT_SECRET = process.env.CAYADEV_CLIENT_SECRET || '';
const CAYADEV_REDIRECT_URI = process.env.CAYADEV_REDIRECT_URI ||
  'https://app.cayadev.com/edebi-cengel-server/auth/cayadev/callback';
const CAYADEV_SCOPE = 'profile:read email:read avatar:read';

if (!CAYADEV_CLIENT_ID || !CAYADEV_CLIENT_SECRET) {
  console.warn('⚠️  CAYADEV_CLIENT_ID / CAYADEV_CLIENT_SECRET ortam değişkenleri tanımlı değil. CaYaDev girişi devre dışı.');
}

// state -> { status, createdAt, token, user, error, code }
const oauthSessions = new Map();
const OAUTH_SESSION_TTL_MS = 10 * 60 * 1000; // 10 dakika

setInterval(() => {
  const now = Date.now();
  for (const [state, session] of oauthSessions.entries()) {
    if (now - session.createdAt > OAUTH_SESSION_TTL_MS) {
      oauthSessions.delete(state);
    }
  }
}, 2 * 60 * 1000);

// 1. Flutter app'ten gelen istek - state üret ve auth URL'i geri döndür
app.post('/auth/cayadev/start', (req, res) => {
  if (!CAYADEV_CLIENT_ID) {
    return res.status(503).json({ error: 'CaYaDev girişi yapılandırılmamış' });
  }

  const state = crypto.randomBytes(24).toString('hex');
  oauthSessions.set(state, { status: 'pending', createdAt: Date.now() });

  const params = new URLSearchParams({
    client_id: CAYADEV_CLIENT_ID,
    redirect_uri: CAYADEV_REDIRECT_URI,
    response_type: 'code',
    scope: CAYADEV_SCOPE,
    state
  });

  res.json({
    state,
    authUrl: `${CAYADEV_AUTH_URL}?${params.toString()}`
  });
});

// 2. Tarayıcı - CaYaDev'in yönlendirdiği callback
app.get('/auth/cayadev/callback', async (req, res) => {
  const { code, state, error: oauthError } = req.query;

  if (oauthError) {
    if (state && oauthSessions.has(state)) {
      const session = oauthSessions.get(state);
      session.status = 'error';
      session.error = oauthError === 'access_denied'
        ? 'Kullanıcı izni reddetti'
        : `OAuth hatası: ${oauthError}`;
    }
    return res.status(400).send(renderOAuthResult(false, 'Giriş iptal edildi.'));
  }

  if (!code || !state || !oauthSessions.has(state)) {
    return res.status(400).send(renderOAuthResult(false, 'Geçersiz istek (state veya code eksik).'));
  }

  const session = oauthSessions.get(state);

  try {
    // Code → Token değişimi
    const tokenRes = await fetch(CAYADEV_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: CAYADEV_REDIRECT_URI,
        client_id: CAYADEV_CLIENT_ID,
        client_secret: CAYADEV_CLIENT_SECRET
      })
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      throw new Error(`Token alınamadı (${tokenRes.status}): ${errText}`);
    }

    const tokenData = await tokenRes.json();
    const accessToken = tokenData.access_token;

    // Kullanıcı bilgilerini çek
    const userRes = await fetch(CAYADEV_USERINFO_URL, {
      headers: { Authorization: `Bearer ${accessToken}` }
    });

    if (!userRes.ok) {
      const errText = await userRes.text();
      throw new Error(`Kullanıcı bilgisi alınamadı (${userRes.status}): ${errText}`);
    }

    const profile = await userRes.json();

    // Kullanıcıyı bul ya da oluştur
    const { user, isNew } = upsertCayadevUser(profile);

    // JWT üret
    const jwtToken = jwt.sign(
      { id: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    session.status = 'completed';
    session.token = jwtToken;
    session.user = {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      stats: user.stats
    };
    session.isNewUser = isNew;

    return res.send(renderOAuthResult(true, 'Giriş başarılı! Uygulamaya geri dönebilirsiniz.'));
  } catch (e) {
    console.error('CaYaDev OAuth callback hatası:', e);
    session.status = 'error';
    session.error = e.message || 'Bilinmeyen hata';
    return res.status(500).send(renderOAuthResult(false, 'Giriş sırasında bir hata oluştu.'));
  }
});

// 3. Flutter app - JWT için poll
app.get('/auth/cayadev/poll/:state', (req, res) => {
  const session = oauthSessions.get(req.params.state);
  if (!session) {
    return res.status(404).json({ status: 'not_found' });
  }

  if (session.status === 'pending') {
    return res.json({ status: 'pending' });
  }

  if (session.status === 'error') {
    oauthSessions.delete(req.params.state);
    return res.status(400).json({ status: 'error', error: session.error });
  }

  // completed - tek seferlik teslim, sonra sil
  oauthSessions.delete(req.params.state);
  res.json({
    status: 'completed',
    token: session.token,
    user: session.user,
    isNewUser: session.isNewUser
  });
});

// ==================== CaYaDev Kullanıcı Eşleştirme Algoritması ====================
// Çok aşamalı, idempotent ve güvenli matching:
//   AŞAMA 1 — sub ile eşleştir (en güvenilir; aynı CaYaDev hesabı = aynı kullanıcı)
//             + duplike OAuth kayıtlarını temizle
//             + orphan ise: lokal email-eşleşmeli hesaba RESCUE MERGE yap
//             + uygun username'e dön (orphan slot reclaim varsa)
//   AŞAMA 2 — email ile mevcut lokal hesaba bağla (kullanıcı kendi username'ini korur)
//   AŞAMA 3 — username çakışmasını çöz (orphan reclaim, son çare _cyd suffix)
//   AŞAMA 4 — yeni OAuth kullanıcı oluştur (collision-safe displayName ile)

const CAYADEV_PROVIDER = 'cayadev';

// CaYaDev namespace: bu pattern'lere uyan username'ler OAuth için ayrılmıştır.
//   - "_cyd" suffix (örn: cayatur_cyd, cayatur_cyd2, cayatur_cyd_a1b2c3)
//   - "cyd_" prefix (kısa profil sub fallback'i için)
// Manuel kayıt bunları alamaz; OAuth tarafı bu pattern'lerle güvenli suffix üretebilir.
const RESERVED_SUFFIX_PATTERN = /_cyd(\d+|_[a-z0-9]+)?$/i;
const RESERVED_PREFIX_PATTERN = /^cyd_/i;

function isReservedOAuthUsername(name) {
  if (!name || typeof name !== 'string') return false;
  return RESERVED_SUFFIX_PATTERN.test(name) || RESERVED_PREFIX_PATTERN.test(name);
}

function normalizeEmail(email) {
  if (!email || typeof email !== 'string') return null;
  const trimmed = email.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeName(name) {
  if (!name || typeof name !== 'string') return '';
  return name.trim().toLowerCase();
}

function sanitizeUsername(raw, sub) {
  const cleaned = String(raw || '').toLowerCase().replace(/[^a-z0-9_]/g, '');
  if (cleaned.length >= 3) return cleaned.slice(0, 18);
  // Çok kısa/boş → sub fragmentinden türet (kullanıcıya "cayadev_xxx" göstermekten daha temiz)
  const fragment = String(sub || '').replace(/[^a-zA-Z0-9]/g, '').slice(0, 8) ||
    Date.now().toString(36).slice(-6);
  return `cyd_${fragment}`.toLowerCase().slice(0, 18);
}

function createEmptyStats() {
  return {
    totalScore: 0,
    totalPuzzlesCompleted: 0,
    totalWordsCompleted: 0,
    totalHintsUsed: 0,
    totalLettersRevealed: 0,
    totalWordsRevealed: 0,
    totalCellsFilled: 0,
    fastestPuzzleSeconds: 0,
    currentStreak: 0,
    bestStreak: 0,
    playedCategories: [],
    earnedBadgeIds: [],
    lastPlayedDate: null,
    categoryUserScores: {},
    categoryMaxScores: {},
    categoryPuzzleCounts: {},
    categoryWordsCorrect: {},
    categoryWordsTotal: {},
    categoryLastMissedClues: {}
  };
}

// "Orphan" = hiç gerçek aktivite olmayan hesap (silmek/kaybetmek güvenli)
function isOrphanAccount(u) {
  if (!u || !u.stats) return false;
  const s = u.stats;
  const hasActivity =
    (s.totalPuzzlesCompleted || 0) > 0 ||
    (s.totalScore || 0) > 0 ||
    (s.totalWordsCompleted || 0) > 0 ||
    (s.totalCellsFilled || 0) > 0 ||
    (Array.isArray(s.earnedBadgeIds) && s.earnedBadgeIds.length > 0) ||
    !!s.lastPlayedDate;
  return !hasActivity;
}

// CaYaDev profile'ını doğrula ve normalize et.
// 'sub' her ikisinde de mantıklı: bazı sağlayıcılar 'sub', bazıları 'id' kullanır.
function validateCayadevProfile(profile) {
  if (!profile || typeof profile !== 'object') {
    return { ok: false, error: 'Boş profil' };
  }
  const subRaw = profile.sub != null ? profile.sub
              : profile.id  != null ? profile.id
              : null;
  const sub = subRaw != null ? String(subRaw).trim() : '';
  if (!sub || sub === 'undefined' || sub === 'null') {
    return { ok: false, error: 'CaYaDev profili sub/id içermiyor' };
  }
  return {
    ok: true,
    sub,
    rawUsername: profile.username || profile.preferred_username || null,
    displayName: profile.display_name || profile.name || null,
    email: normalizeEmail(profile.email),
    avatar: profile.avatar || profile.picture || null
  };
}

// Aynı sub'a sahip duplike kayıtları temizle (target dışındakileri sil).
// Eski denemelerden kalan yetim kayıtların temizliğini garantiler.
function cleanupDuplicateOAuthRecords(data, target, sub) {
  const before = data.users.length;
  data.users = data.users.filter(u =>
    u === target ||
    !(u.oauthProvider === CAYADEV_PROVIDER && String(u.oauthSub) === sub)
  );
  const removed = before - data.users.length;
  if (removed > 0) {
    console.log(`[CaYaDev] ${removed} duplike OAuth kaydı temizlendi (sub=${sub})`);
  }
}

// Profil bilgilerini kullanıcıya yansıt (stats'a dokunmaz).
// displayName her seferinde collision-safe hale getirilir: aynı isimli başka
// aktif kullanıcı varsa "(CaYaDev)" rozeti eklenir.
function refreshUserFromProfile(data, user, info) {
  user.lastLoginAt = new Date().toISOString();
  if (info.displayName) {
    user.displayName = disambiguateDisplayName(data, info.displayName, user.id);
  }
  if (info.email) user.email = info.email;
  if (info.avatar) user.avatar = info.avatar;
}

// Mümkünse daha temiz username'e geri dön (örn: cayatur_cyd → cayatur).
// Sadece çakışma yoksa veya çakışan(lar) hep orphan ise yapar.
function tryReclaimCleanerUsername(data, user, desiredUsername) {
  if (!desiredUsername) return;
  if (user.username.toLowerCase() === desiredUsername.toLowerCase()) return;

  const conflicts = data.users.filter(u =>
    u.id !== user.id && u.username.toLowerCase() === desiredUsername.toLowerCase()
  );

  if (conflicts.length === 0) {
    console.log(`[CaYaDev] Username yenilendi: ${user.username} → ${desiredUsername}`);
    user.username = desiredUsername;
    return;
  }

  if (conflicts.every(u => isOrphanAccount(u))) {
    const orphanIds = new Set(conflicts.map(o => o.id));
    data.users = data.users.filter(u => !orphanIds.has(u.id));
    console.log(`[CaYaDev] ${conflicts.length} orphan silindi, username geri kazanıldı: ${user.username} → ${desiredUsername}`);
    user.username = desiredUsername;
  }
  // Aksi hâlde mevcut (suffixli) username korunur — gerçek başka kullanıcının slotunu çalmaz.
}

// AŞAMA 2 yardımcı: email eşleşen, OAuth-sız lokal hesabı bul.
// CaYaDev tarafının email doğrulamasına güveniyoruz.
function findLinkableLocalUserByEmail(data, profileEmail) {
  if (!profileEmail) return null;
  return data.users.find(u =>
    !u.oauthProvider &&
    typeof u.email === 'string' &&
    u.email.trim().toLowerCase() === profileEmail
  ) || null;
}

// AŞAMA 1 yardımcı (RESCUE MERGE): mevcut OAuth kullanıcısı orphan ise ve
// SADECE doğrulanmış email ile lokal bir hesap eşleşiyorsa, OAuth kimliğini
// lokal hesaba taşı ve orphan OAuth kaydını sil.
//
// GÜVENLİK: displayName/username eşleşmesi rescue merge için YETERSİZ, çünkü
// iki farklı kişi aynı ada sahip olabilir. Sadece email (CaYaDev tarafında
// doğrulanmış) hesabın aynı kişiye ait olduğunu kanıtlar.
function tryRescueMergeOrphanIntoLocal(data, oauthUser, info) {
  if (!isOrphanAccount(oauthUser)) return null;
  if (!info.email) return null;

  const target = findLinkableLocalUserByEmail(data, info.email);
  if (!target) return null;

  target.oauthProvider = oauthUser.oauthProvider;
  target.oauthSub = oauthUser.oauthSub;
  target.password = null;
  // Orphan kaydı önce listeden çıkar ki disambiguation onunla collision görmesin
  data.users = data.users.filter(u => u.id !== oauthUser.id);
  refreshUserFromProfile(data, target, info);
  console.log(`[CaYaDev] RESCUE MERGE (email): orphan OAuth (${oauthUser.username}) → lokal (${target.username})`);
  return target;
}

// Username çakışmasını çöz: orphan'ları sil, kalan gerçek çakışma için _cyd suffix.
// Geri dönen username garantili olarak benzersiz.
function resolveOAuthUsername(data, baseUsername) {
  const baseLower = baseUsername.toLowerCase();
  const conflicts = data.users.filter(u => u.username.toLowerCase() === baseLower);

  if (conflicts.length === 0) return baseUsername;

  const orphans = conflicts.filter(u => isOrphanAccount(u));
  const realUsers = conflicts.filter(u => !isOrphanAccount(u));

  if (orphans.length > 0) {
    const orphanIds = new Set(orphans.map(o => o.id));
    data.users = data.users.filter(u => !orphanIds.has(u.id));
    console.log(`[CaYaDev] ${orphans.length} orphan silindi (username: ${baseUsername})`);
  }

  if (realUsers.length === 0) return baseUsername;

  return uniqueOAuthSuffixedUsername(data, baseUsername);
}

function uniqueOAuthSuffixedUsername(data, base) {
  const taken = new Set(data.users.map(u => u.username.toLowerCase()));

  // Stem çıkarımı: base zaten reserved namespace ise (kullanıcının cayadev.com'daki
  // adı tesadüfen "test_cyd" gibi olabilir), tekrar suffix eklenince "test_cyd_cyd"
  // olmasın diye stem'e indir, sonra temiz suffix uygula.
  let stem = base;
  if (RESERVED_SUFFIX_PATTERN.test(stem)) {
    stem = stem.replace(/_cyd(\d+|_[a-z0-9]+)?$/i, '');
  } else if (RESERVED_PREFIX_PATTERN.test(stem)) {
    stem = stem.replace(/^cyd_/i, '');
  }
  if (!stem || stem.length < 2) stem = base; // fallback: stem çok kısaysa orijinali kullan

  const first = `${stem}_cyd`;
  if (!taken.has(first.toLowerCase())) return first;
  for (let i = 2; i < 1000; i++) {
    const candidate = `${stem}_cyd${i}`;
    if (!taken.has(candidate.toLowerCase())) return candidate;
  }
  return `${stem}_cyd_${Date.now().toString(36)}`;
}

// DisplayName'i collision-safe yap.
// Çakışma kontrolü hem displayName hem USERNAME alanlarına bakar — örn:
// lokal user'ın username'i "CaYatur" iken OAuth user'ın displayName'i de
// "CaYatur" olabilir; bu identity collision'dır ve kullanıcı için kafa karıştırıcı.
// Idempotent: önce mevcut "(CaYaDev)" suffix'ini sökerek yeniden değerlendirir;
// çakışma kalkmışsa suffix kaldırılır.
function disambiguateDisplayName(data, displayName, ignoreUserId) {
  if (!displayName) return displayName;

  const stripped = displayName.replace(/\s*\(CaYaDev\)\s*$/i, '').trim();
  if (!stripped) return displayName;
  const baseLower = stripped.toLowerCase();

  const conflict = data.users.find(u =>
    u.id !== ignoreUserId &&
    ((typeof u.displayName === 'string' && u.displayName.replace(/\s*\(CaYaDev\)\s*$/i, '').trim().toLowerCase() === baseLower) ||
     (typeof u.username === 'string' && u.username.trim().toLowerCase() === baseLower))
  );

  return conflict ? `${stripped} (CaYaDev)` : stripped;
}

// ==================== DATA MIGRATION ====================
// Sunucu açılışında bir kez çalışır; eski kayıtları yeni kurallara göre düzeltir.
// Idempotent (her çalıştığında aynı sonuç) ve non-destructive (stats kaybetmez).
function migrateUserDataIfNeeded() {
  const data = readData();
  if (!Array.isArray(data.users) || data.users.length === 0) return;

  const changes = [];

  // 1) Aynı sub'a sahip duplike OAuth kayıtlarını birleştir
  //    En çok aktiviteye sahip olanı koru, diğerlerini sil (boş olanlar)
  const subGroups = new Map(); // sub -> [users]
  for (const u of data.users) {
    if (u.oauthProvider === CAYADEV_PROVIDER && u.oauthSub) {
      const key = String(u.oauthSub);
      if (!subGroups.has(key)) subGroups.set(key, []);
      subGroups.get(key).push(u);
    }
  }
  const duplicateIdsToRemove = new Set();
  for (const [sub, group] of subGroups.entries()) {
    if (group.length <= 1) continue;
    // En aktif olanı seç (totalScore + totalPuzzlesCompleted sırası)
    group.sort((a, b) => {
      const sa = (a.stats?.totalScore || 0) + (a.stats?.totalPuzzlesCompleted || 0) * 10;
      const sb = (b.stats?.totalScore || 0) + (b.stats?.totalPuzzlesCompleted || 0) * 10;
      return sb - sa;
    });
    const winner = group[0];
    for (let i = 1; i < group.length; i++) {
      // Sadece aktivitesi olmayan duplike'ları sil (veri kaybı riski yok)
      if (isOrphanAccount(group[i])) {
        duplicateIdsToRemove.add(group[i].id);
        changes.push(`duplike sub=${sub} sildi: ${group[i].username} (orphan)`);
      } else {
        changes.push(`UYARI: sub=${sub} için aktif duplike: ${group[i].username} — manuel inceleme gerekir, kazanan: ${winner.username}`);
      }
    }
  }
  if (duplicateIdsToRemove.size > 0) {
    data.users = data.users.filter(u => !duplicateIdsToRemove.has(u.id));
  }

  // 2) Identity collision → OAuth kullanıcılarına "(CaYaDev)" rozeti uygula
  //    Çakışma hem displayName hem USERNAME alanlarına bakılarak tespit edilir.
  //    Tipik durum: manuel "CaYatur" username'i + OAuth user'ın displayName="CaYatur"
  //    → identity çakışması, OAuth tarafına rozet eklenir. Manuel kullanıcı dokunulmaz.
  for (const u of data.users) {
    if (u.oauthProvider !== CAYADEV_PROVIDER) continue;
    if (!u.displayName) continue;

    const newDisplayName = disambiguateDisplayName(data, u.displayName, u.id);
    if (newDisplayName !== u.displayName) {
      const oldName = u.displayName;
      u.displayName = newDisplayName;
      changes.push(`displayName ayrıştırıldı: "${oldName}" → "${u.displayName}" (username=${u.username})`);
    }
  }

  // 3) Eksik stats alanlarını tamamla (yeni eklenen alanlar için backfill)
  const emptyStatsKeys = Object.keys(createEmptyStats());
  for (const u of data.users) {
    if (!u.stats) {
      u.stats = createEmptyStats();
      changes.push(`stats oluşturuldu: ${u.username}`);
      continue;
    }
    for (const key of emptyStatsKeys) {
      if (!(key in u.stats)) {
        const empty = createEmptyStats()[key];
        u.stats[key] = empty;
      }
    }
  }

  if (changes.length > 0) {
    console.log(`[MIGRATION] ${changes.length} düzeltme uygulandı:`);
    for (const c of changes) console.log(`  - ${c}`);
    writeData(data);
  } else {
    console.log('[MIGRATION] Düzeltme gerekmedi, veri tutarlı.');
  }
}

// === ANA AKIŞ: CaYaDev profilinden kullanıcıyı bul/oluştur/bağla ===
function upsertCayadevUser(profile) {
  const validation = validateCayadevProfile(profile);
  if (!validation.ok) {
    throw new Error(`CaYaDev profili geçersiz: ${validation.error}`);
  }
  const info = validation;
  const sub = info.sub;
  const desiredUsername = sanitizeUsername(info.rawUsername || `cyd_${sub.slice(-6)}`, sub);

  const data = readData();

  // ===== AŞAMA 1: sub ile eşleştir (deterministik) =====
  let user = data.users.find(u =>
    u.oauthProvider === CAYADEV_PROVIDER && String(u.oauthSub) === sub
  );

  if (user) {
    cleanupDuplicateOAuthRecords(data, user, sub);

    // 1a) Bu OAuth kaydı orphan ise lokal aktif hesaba taşımayı dene (rescue merge)
    const merged = tryRescueMergeOrphanIntoLocal(data, user, info);
    if (merged) {
      // user referansı değişti — birleştirilmiş hedef hesaba devam
      user = merged;
      tryReclaimCleanerUsername(data, user, desiredUsername);
      writeData(data);
      console.log(`[CaYaDev] Giriş (rescue merge sonrası): ${user.username} (id=${user.id})`);
      return { user, isNew: false, action: 'rescue_merged' };
    }

    refreshUserFromProfile(data, user, info);
    tryReclaimCleanerUsername(data, user, desiredUsername);
    writeData(data);
    console.log(`[CaYaDev] sub eşleşti: ${user.username} (id=${user.id})`);
    return { user, isNew: false, action: 'matched_by_sub' };
  }

  // ===== AŞAMA 2: email ile mevcut lokal hesaba bağla =====
  // Aynı kişinin manuel hesabı varsa onu OAuth'a yükselt.
  // Username & stats korunur — kullanıcı önceki ilerlemesini kaybetmez.
  if (info.email) {
    const linkable = findLinkableLocalUserByEmail(data, info.email);
    if (linkable) {
      linkable.oauthProvider = CAYADEV_PROVIDER;
      linkable.oauthSub = sub;
      linkable.password = null; // Şifreye artık gerek yok
      refreshUserFromProfile(data, linkable, info);
      writeData(data);
      console.log(`[CaYaDev] Email ile bağlandı: ${linkable.username} (${info.email}) → sub=${sub}`);
      return { user: linkable, isNew: false, action: 'linked_by_email' };
    }
  }

  // ===== AŞAMA 3: Yeni kullanıcı için username çöz =====
  const finalUsername = resolveOAuthUsername(data, desiredUsername);

  // ===== AŞAMA 4: Yeni OAuth kullanıcı oluştur =====
  const newId = uuidv4();
  const baseDisplayName = info.displayName || info.rawUsername || finalUsername;
  const safeDisplayName = disambiguateDisplayName(data, baseDisplayName, newId);

  user = {
    id: newId,
    username: finalUsername,
    displayName: safeDisplayName,
    email: info.email,
    avatar: info.avatar,
    password: null,
    oauthProvider: CAYADEV_PROVIDER,
    oauthSub: sub,
    stats: createEmptyStats(),
    createdAt: new Date().toISOString(),
    lastLoginAt: new Date().toISOString()
  };
  data.users.push(user);
  writeData(data);
  console.log(`[CaYaDev] Yeni kullanıcı: ${user.username} (display=${user.displayName}, id=${user.id}, sub=${sub})`);
  return { user, isNew: true, action: 'created_new' };
}

// Tarayıcıda gösterilecek basit sonuç sayfası
function renderOAuthResult(success, message) {
  const color = success ? '#26A69A' : '#E53935';
  const icon = success ? '✓' : '✗';
  return `<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Edebi Çengel - CaYaDev Giriş</title>
<style>
body{margin:0;font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:linear-gradient(135deg,#0A1929,#19857B);color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px}
.card{background:rgba(255,255,255,0.08);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,0.15);border-radius:20px;padding:32px;max-width:420px;text-align:center;box-shadow:0 12px 40px rgba(0,0,0,0.3)}
.icon{width:72px;height:72px;border-radius:50%;background:${color};display:inline-flex;align-items:center;justify-content:center;font-size:42px;font-weight:bold;margin-bottom:16px}
h1{margin:0 0 8px;font-size:22px}p{margin:0;opacity:0.85;line-height:1.5}
.hint{margin-top:18px;font-size:13px;opacity:0.6}
</style></head><body><div class="card">
<div class="icon">${icon}</div>
<h1>${success ? 'Giriş Başarılı' : 'Giriş Başarısız'}</h1>
<p>${message}</p>
<p class="hint">Bu sekmeyi kapatabilirsiniz.</p>
</div></body></html>`;
}

// ==================== SIRALAMA TABLOSU ====================
app.get('/leaderboard', (req, res) => {
  const data = readData();
  const limit = parseInt(req.query.limit) || 50;
  const period = req.query.period || 'all'; // 'all', 'monthly', 'weekly'

  // Dönem filtreleme için tarih hesapla
  const now = new Date();
  let filterDate = null;
  if (period === 'weekly') {
    filterDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  } else if (period === 'monthly') {
    filterDate = new Date(now.getFullYear(), now.getMonth(), 1);
  }

  let filteredUsers = data.users;

  // Eğer haftalık/aylık filtre varsa, o dönemde oynayan kullanıcıları filtrele
  if (filterDate) {
    filteredUsers = data.users.filter(u => {
      const lastPlayed = u.stats.lastPlayedDate ? new Date(u.stats.lastPlayedDate) : null;
      return lastPlayed && lastPlayed >= filterDate;
    });
  }

  const leaderboard = filteredUsers
    .map(u => ({
      id: u.id,
      username: u.username,
      displayName: u.displayName,
      totalScore: u.stats.totalScore ?? 0,
      totalPuzzlesCompleted: u.stats.totalPuzzlesCompleted ?? 0,
      totalWordsCompleted: u.stats.totalWordsCompleted ?? 0,
      bestStreak: u.stats.bestStreak ?? 0,
      earnedBadgeCount: (u.stats.earnedBadgeIds ?? []).length,
      earnedBadgeIds: u.stats.earnedBadgeIds ?? [],
      totalHintsUsed: u.stats.totalHintsUsed ?? 0,
      totalCellsFilled: u.stats.totalCellsFilled ?? 0,
      fastestPuzzleSeconds: u.stats.fastestPuzzleSeconds ?? 0,
      currentStreak: u.stats.currentStreak ?? 0,
      playedCategories: u.stats.playedCategories || [],
      level: getLevel(u.stats.totalScore),
      rank: getRank(u.stats.totalScore),
      rankIcon: getRankIcon(u.stats.totalScore),
      lastPlayedDate: u.stats.lastPlayedDate
    }))
    .sort((a, b) => b.totalScore - a.totalScore)
    .slice(0, limit);

  // Sıra numaraları ekle
  leaderboard.forEach((entry, index) => {
    entry.position = index + 1;
  });

  res.json({
    leaderboard,
    totalPlayers: filteredUsers.length,
    period: period
  });
});

// ==================== LEADERBOARD WEB ====================
app.get('/leaderboard/web', (req, res) => {
  const data = readData();
  const limit = parseInt(req.query.limit) || 20;
  const period = req.query.period || 'all';

  const now = new Date();
  let filterDate = null;
  if (period === 'weekly') {
    filterDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  } else if (period === 'monthly') {
    filterDate = new Date(now.getFullYear(), now.getMonth(), 1);
  }

  let filteredUsers = data.users;
  if (filterDate) {
    filteredUsers = data.users.filter(u => {
      const lastPlayed = u.stats.lastPlayedDate ? new Date(u.stats.lastPlayedDate) : null;
      return lastPlayed && lastPlayed >= filterDate;
    });
  }

  const leaderboard = filteredUsers
    .map(u => ({
      id: u.id,
      username: u.username,
      displayName: u.displayName,
      totalScore: u.stats.totalScore ?? 0,
      totalPuzzlesCompleted: u.stats.totalPuzzlesCompleted ?? 0,
      totalWordsCompleted: u.stats.totalWordsCompleted ?? 0,
      bestStreak: u.stats.bestStreak ?? 0,
      earnedBadgeCount: (u.stats.earnedBadgeIds ?? []).length,
      level: getLevel(u.stats.totalScore),
      rank: getRank(u.stats.totalScore),
      lastPlayedDate: u.stats.lastPlayedDate
    }))
    .sort((a, b) => b.totalScore - a.totalScore)
    .slice(0, limit);

  leaderboard.forEach((entry, index) => {
    entry.position = index + 1;
  });

  const periodText = period === 'weekly' ? 'Bu Hafta' : period === 'monthly' ? 'Bu Ay' : 'Tüm Zamanlar';

  // Tablo HTML'i oluştur
  let tableHtml = '';
  if (leaderboard.length > 0) {
    tableHtml = '<table><thead><tr><th>#</th><th>Oyuncu</th><th class="responsive-hide">Puan</th><th class="responsive-hide">Bulmaca</th><th>Puan</th></tr></thead><tbody>';
    tableHtml += leaderboard.map(entry => {
      let medalEmoji = '';
      if (entry.position === 1) medalEmoji = '🥇';
      else if (entry.position === 2) medalEmoji = '🥈';
      else if (entry.position === 3) medalEmoji = '🥉';
      
      return `<tr><td class="position position-${entry.position}"><span class="medal">${medalEmoji || entry.position}</span></td><td><div class="player-name">${entry.displayName || entry.username}</div><div class="stat responsive-hide">Seviye ${entry.level}</div></td><td class="responsive-hide stat">${entry.totalScore.toLocaleString('tr-TR')}</td><td class="responsive-hide stat">${entry.totalPuzzlesCompleted}</td><td class="score">${entry.totalScore.toLocaleString('tr-TR')}</td></tr>`;
    }).join('');
    tableHtml += '</tbody></table>';
  } else {
    tableHtml = '<div class="empty-state"><p style="font-size: 1.2em; margin-bottom: 10px;">Henüz veri yok</p><p>Oyunculara başlamalarını bekleyin...</p></div>';
  }

  const html = `
    <!DOCTYPE html>
    <html lang="tr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Sıralamalar - Edebi Çengel</title>
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background: linear-gradient(135deg, #0f0f1e 0%, #1a1a2e 50%, #0f0f1e 100%);
          min-height: 100vh;
          padding: 20px;
          color: #ffffff;
        }
        .container {
          max-width: 900px;
          margin: 0 auto;
        }
        .header {
          text-align: center;
          margin-bottom: 40px;
          animation: slideIn 0.6s ease-out;
        }
        .header h1 {
          color: #00d9ff;
          font-size: clamp(1.8em, 6vw, 2.5em);
          margin-bottom: 10px;
          text-shadow: 0 0 20px rgba(0, 217, 255, 0.6);
        }
        .header p {
          color: #00bfff;
          font-size: 1.1em;
          text-shadow: 0 0 10px rgba(0, 191, 255, 0.4);
        }
        .period-filter {
          display: flex;
          gap: 10px;
          justify-content: center;
          margin-bottom: 30px;
          flex-wrap: wrap;
        }
        .period-btn {
          background: rgba(0, 217, 255, 0.1);
          border: 2px solid rgba(0, 217, 255, 0.3);
          color: #00d9ff;
          padding: 10px 20px;
          border-radius: 20px;
          cursor: pointer;
          transition: all 0.3s ease;
          text-decoration: none;
          font-weight: 600;
        }
        .period-btn:hover,
        .period-btn.active {
          background: linear-gradient(135deg, #00d9ff 0%, #00bfff 100%);
          color: #0f0f1e;
          border-color: #00d9ff;
        }
        .table-wrapper {
          background: rgba(26, 26, 46, 0.4);
          border: 2px solid rgba(0, 217, 255, 0.3);
          border-radius: 15px;
          overflow: hidden;
          backdrop-filter: blur(10px);
          animation: slideIn 0.6s ease-out 0.1s both;
        }
        table {
          width: 100%;
          border-collapse: collapse;
        }
        thead {
          background: linear-gradient(135deg, rgba(0, 217, 255, 0.15) 0%, rgba(0, 191, 255, 0.15) 100%);
          border-bottom: 2px solid rgba(0, 217, 255, 0.3);
        }
        th {
          padding: 16px;
          text-align: left;
          color: #00d9ff;
          font-weight: 600;
          font-size: 0.95em;
        }
        tbody tr {
          border-bottom: 1px solid rgba(0, 217, 255, 0.1);
          transition: all 0.3s ease;
        }
        tbody tr:hover {
          background: rgba(0, 217, 255, 0.05);
          border-bottom-color: rgba(0, 217, 255, 0.3);
        }
        td {
          padding: 14px 16px;
          color: #b3b3cc;
          font-size: 0.95em;
        }
        .position {
          color: #00d9ff;
          font-weight: 700;
          width: 50px;
        }
        .position-1 {
          color: #ffd700;
        }
        .position-2 {
          color: #c0c0c0;
        }
        .position-3 {
          color: #cd7f32;
        }
        .medal {
          display: inline-block;
          width: 24px;
          height: 24px;
          line-height: 24px;
          text-align: center;
          font-weight: 700;
          margin-right: 8px;
        }
        .player-name {
          color: #ffffff;
          font-weight: 600;
        }
        .score {
          color: #00d9ff;
          font-weight: 600;
        }
        .stat {
          color: #00bfff;
          font-size: 0.9em;
        }
        .empty-state {
          text-align: center;
          padding: 40px 20px;
          color: #b3b3cc;
        }
        @keyframes slideIn {
          from {
            opacity: 0;
            transform: translateY(-20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        @media (max-width: 768px) {
          .header h1 {
            margin-bottom: 15px;
          }
          th, td {
            padding: 10px 8px;
            font-size: 0.85em;
          }
          .responsive-hide {
            display: none;
          }
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>SIRALAMA</h1>
          <p>${periodText}</p>
        </div>

        <div class="period-filter">
          <a href="/leaderboard/web?period=all" class="period-btn ${period === 'all' ? 'active' : ''}">Tüm Zamanlar</a>
          <a href="/leaderboard/web?period=monthly" class="period-btn ${period === 'monthly' ? 'active' : ''}">Bu Ay</a>
          <a href="/leaderboard/web?period=weekly" class="period-btn ${period === 'weekly' ? 'active' : ''}">Bu Hafta</a>
        </div>

        <div class="table-wrapper">
          ${tableHtml}
        </div>
      </div>
    </body>
    </html>
  `;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

// ==================== Seviye Hesaplama ====================
function getLevel(score) {
  if (score >= 10000) return 8;
  if (score >= 5000) return 7;
  if (score >= 2000) return 6;
  if (score >= 1000) return 5;
  if (score >= 500) return 4;
  if (score >= 200) return 3;
  if (score >= 50) return 2;
  return 1;
}

// ==================== Rütbe Hesaplama ====================
function getRank(score) {
  if (score >= 10000) return 'Edebiyat Efsanesi';
  if (score >= 5000) return 'Edebiyat Ustası';
  if (score >= 2000) return 'Çengel Uzmanı';
  if (score >= 1000) return 'Kelime Avcısı';
  if (score >= 500) return 'Bulmaca Tutkunu';
  if (score >= 200) return 'Meraklı Çözücü';
  if (score >= 50) return 'Acemi Çözücü';
  return 'Yeni Başlayan';
}

function getRankIcon(score) {
  if (score >= 10000) return 'crown';
  if (score >= 5000) return 'emoji_events';
  if (score >= 2000) return 'star';
  if (score >= 1000) return 'target';
  if (score >= 500) return 'local_fire_department';
  if (score >= 200) return 'library_books';
  if (score >= 50) return 'edit';
  return 'sprout';
}

// ==================== ÇOKLU OYUNCU SİSTEMİ ====================
// Aktif odalar: roomCode -> roomData
const activeRooms = new Map();
// Herkese açık odalar: roomCode -> roomData
const publicRooms = new Map();

// Kullanılmış oda kodlarını takip et (aktif odalar arasında çakışma olmasın)
function generateRoomCode() {
  let code;
  let attempts = 0;
  do {
    code = Math.floor(1000 + Math.random() * 9000).toString(); // 4 basamaklı
    attempts++;
    if (attempts > 100) {
      // Çok fazla deneme olduysa eski odaları temizle
      cleanExpiredRooms();
      attempts = 0;
    }
  } while (activeRooms.has(code));
  return code;
}

// Süresi dolmuş odaları temizle (30 dakikadan eski)
function cleanExpiredRooms() {
  const now = Date.now();
  const ROOM_TIMEOUT = 30 * 60 * 1000; // 30 dakika
  for (const [code, room] of activeRooms.entries()) {
    if (now - room.createdAt > ROOM_TIMEOUT && room.status !== 'playing') {
      activeRooms.delete(code);
      console.log(`🗑️  Süresi dolmuş oda silindi: ${code}`);
    }
    // Oyun bitmişse 5 dakika sonra sil
    if (room.status === 'finished' && now - (room.finishedAt || room.createdAt) > 5 * 60 * 1000) {
      activeRooms.delete(code);
    }
  }
}

// Her 2 dakikada odaları temizle
setInterval(cleanExpiredRooms, 2 * 60 * 1000);

// ==================== REST API - ODA İŞLEMLERİ ====================

// Oda bilgisi getir (katılmadan önce kontrol için)
app.get('/room/:code', (req, res) => {
  const room = activeRooms.get(req.params.code);
  if (!room) {
    return res.status(404).json({ error: 'Oda bulunamadı' });
  }
  res.json({
    roomCode: room.roomCode,
    hostName: room.hostName,
    status: room.status,
    playerCount: room.players.length,
    maxPlayers: room.settings.maxPlayers,
    settings: {
      categoryId: room.settings.categoryId,
      categoryName: room.settings.categoryName,
      difficulty: room.settings.difficulty,
      wordCount: room.settings.wordCount,
      hintLimit: room.settings.hintLimit,
      timeLimit: room.settings.timeLimit,
    },
    players: room.players.map(p => ({
      id: p.id,
      displayName: p.displayName,
      isHost: p.isHost,
      isReady: p.isReady,
    }))
  });
});

// Aktif oda sayısı
app.get('/rooms/count', (req, res) => {
  res.json({ activeRooms: activeRooms.size });
});

// Herkese açık odaları listele
app.get('/rooms/public/list', (req, res) => {
  console.log(`\n🔍 [API] /rooms/public/list isteği alındı`);
  console.log(`   Mevcut public rooms: ${publicRooms.size}`);
  console.log(`   Mevcut active rooms: ${activeRooms.size}`);
  
  try {
    const publicList = Array.from(publicRooms.values())
      .filter(room => room.status !== 'finished') // Bitmemiş odalar
      .map(room => ({
        code: room.roomCode,
        hostName: room.hostName,
        playersCount: room.players.length,
        maxPlayers: room.settings?.maxPlayers || 8,
        status: room.status,
        categoryName: room.settings?.categoryName || 'Karışık',
        difficulty: room.settings?.difficulty ?? 0,
      }));
    
    console.log(`   ✅ Döndürülecek odalar: ${publicList.length}`);
    res.json({ rooms: publicList });
  } catch (error) {
    console.error(`   ❌ HATA: ${error.message}`);
    console.error(`   Stack: ${error.stack}`);
    res.status(500).json({ error: error.message, rooms: [] });
  }
});

// ==================== ÇOKLU OYUNCU REST API ====================
require('./multiplayer_rest')(app, activeRooms, publicRooms, generateRoomCode);

// ==================== SINIF MODU REST API ====================
require('./classroom_rest')({
  app,
  authenticateToken,
  dataDir: path.join(__dirname, 'data'),
});

// ==================== ANA SAYFA ====================
app.get('/', (req, res) => {
  const html = `
    <!DOCTYPE html>
    <html lang="tr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Edebi Çengel Sunucu</title>
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background: linear-gradient(135deg, #0f0f1e 0%, #1a1a2e 50%, #0f0f1e 100%);
          min-height: 100vh;
          display: flex;
          justify-content: center;
          align-items: center;
          padding: 15px;
          color: #ffffff;
        }
        .container {
          border-radius: 20px;
          box-shadow: 0 20px 60px rgba(0, 217, 255, 0.2), 0 20px 60px rgba(0, 0, 0, 0.8);
          padding: 40px 25px;
          text-align: center;
          max-width: 650px;
          width: 100%;
          animation: slideIn 0.6s ease-out;
          background: rgba(26, 26, 46, 0.4);
          backdrop-filter: blur(10px);
          border: 2px solid rgba(0, 217, 255, 0.3);
        }
        @keyframes slideIn {
          from {
            opacity: 0;
            transform: translateY(-30px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        .logo-container {
          margin-bottom: 25px;
          animation: float 3s ease-in-out infinite;
        }
        .logo-container img {
          max-width: 200px;
          width: 100%;
          height: auto;
          filter: drop-shadow(0 0 20px rgba(0, 217, 255, 0.4));
        }
        @keyframes float {
          0%, 100% {
            transform: translateY(0px);
          }
          50% {
            transform: translateY(-5px);
          }
        }
        h1 {
          color: #00d9ff;
          font-size: clamp(1.8em, 6vw, 2.2em);
          margin-bottom: 8px;
          text-shadow: 0 0 20px rgba(0, 217, 255, 0.6), 2px 2px 4px rgba(0, 0, 0, 0.8);
          font-weight: 700;
          letter-spacing: 1px;
        }
        .subtitle {
          color: #00bfff;
          font-size: clamp(0.95em, 3vw, 1.1em);
          margin-bottom: 20px;
          font-weight: 300;
          text-shadow: 0 0 10px rgba(0, 191, 255, 0.4);
        }
        .status {
          background: linear-gradient(135deg, rgba(0, 217, 255, 0.1) 0%, rgba(0, 191, 255, 0.1) 100%);
          border: 2px solid rgba(0, 217, 255, 0.3);
          color: #00d9ff;
          padding: 20px 15px;
          border-radius: 15px;
          margin-bottom: 20px;
          font-size: clamp(0.95em, 2vw, 1.05em);
          backdrop-filter: blur(10px);
        }
        .status-icon {
          width: 50px;
          height: 50px;
          margin: 0 auto 10px;
          animation: pulse 2s ease-in-out infinite;
        }
        .status-icon svg {
          width: 100%;
          height: 100%;
          stroke: #00d9ff;
          fill: none;
          stroke-width: 2;
        }
        @keyframes pulse {
          0%, 100% {
            opacity: 1;
            transform: scale(1);
          }
          50% {
            opacity: 0.7;
            transform: scale(1.1);
          }
        }
        .status-text {
          color: #ffffff;
          font-size: clamp(0.9em, 2vw, 1em);
          margin-bottom: 5px;
        }
        .status-version {
          font-size: 0.85em;
          opacity: 0.8;
          color: #00bfff;
        }
        .cta-button {
          display: inline-block;
          background: linear-gradient(135deg, #00d9ff 0%, #00bfff 100%);
          color: #0f0f1e;
          padding: 14px 35px;
          border-radius: 50px;
          text-decoration: none;
          font-size: clamp(0.95em, 2vw, 1.05em);
          font-weight: 600;
          transition: all 0.3s ease;
          box-shadow: 0 10px 30px rgba(0, 217, 255, 0.5), 0 0 20px rgba(0, 217, 255, 0.3);
          border: none;
          cursor: pointer;
          text-transform: uppercase;
          letter-spacing: 1px;
          margin: 15px 0;
        }
        .cta-button:hover {
          transform: translateY(-2px);
          box-shadow: 0 15px 40px rgba(0, 217, 255, 0.8), 0 0 30px rgba(0, 217, 255, 0.5);
        }
        .info {
          margin-top: 20px;
          color: #b3b3cc;
          font-size: clamp(0.85em, 2vw, 0.95em);
        }
        .info-grid {
          display: grid;
          grid-template-columns: 1fr;
          gap: 12px;
          margin-top: 15px;
        }
        @media (min-width: 600px) {
          .info-grid {
            grid-template-columns: 1fr 1fr;
          }
        }
        .info-item {
          padding: 12px;
          border: 1px solid rgba(0, 217, 255, 0.2);
          border-radius: 8px;
          background: rgba(0, 217, 255, 0.05);
          display: flex;
          align-items: center;
          gap: 10px;
        }
        .icon {
          width: 24px;
          height: 24px;
          flex-shrink: 0;
        }
        .icon svg {
          width: 100%;
          height: 100%;
          stroke: #00d9ff;
          fill: none;
          stroke-width: 2;
        }
        .info-text {
          text-align: left;
          flex: 1;
        }
        .info-label {
          display: block;
          font-weight: 600;
          color: #ffffff;
          font-size: 0.9em;
          margin-bottom: 2px;
        }
        .info-item a {
          color: #00d9ff;
          text-decoration: none;
          transition: all 0.3s ease;
          text-shadow: 0 0 10px rgba(0, 217, 255, 0.3);
          font-size: 0.85em;
        }
        .info-item a:hover {
          color: #00ffff;
          text-shadow: 0 0 20px rgba(0, 217, 255, 0.6);
        }
        .divider {
          height: 1px;
          background: linear-gradient(to right, transparent, rgba(0, 217, 255, 0.3), transparent);
          margin: 15px 0;
        }
        @media (max-width: 480px) {
          .container {
            padding: 30px 15px;
            border-radius: 15px;
          }
          .status {
            padding: 15px 12px;
          }
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="logo-container">
          <img src="/${SERVER_DIR_NAME}/EdebiCengelLogo2.png" alt="Edebi Çengel Logo">
        </div>
        
        <h1>EDEBİ ÇENGEL</h1>
        <p class="subtitle">Sunucu Aktif</p>
        
        <div class="divider"></div>
        
        <div class="status">
          <div class="status-icon">
            <svg viewBox="0 0 24 24">
              <path d="M12 2L15.09 8.26H22L17.09 12.61L20.16 18.87L12 14.52L3.84 18.87L6.91 12.61L2 8.26H8.91L12 2Z"/>
            </svg>
          </div>
          <div class="status-text">Sunucu başarıyla çalışıyor</div>
          <div class="status-version">v1.0.2</div>
        </div>
        
        <a href="https://cayadev.com/project/edebi-cengel" class="cta-button">
          Oyunu Başlat
        </a>
        
        <div class="info">
          <div class="info-grid">
            <div class="info-item">
              <div class="icon">
                <svg viewBox="0 0 24 24">
                  <path d="M3 13h2v8H3zm4-8h2v16H7zm4-2h2v18h-2zm4-2h2v20h-2zm4 4h2v16h-2z"/>
                </svg>
              </div>
              <div class="info-text">
                <span class="info-label">Sıralama</span>
                <a href="/leaderboard/web">/leaderboard/web</a>
              </div>
            </div>
            
            <div class="info-item">
              <div class="icon">
                <svg viewBox="0 0 24 24">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm3.5-9c.83 0 1.5-.67 1.5-1.5S16.33 8 15.5 8 14 8.67 14 9.5s.67 1.5 1.5 1.5zm-7 0c.83 0 1.5-.67 1.5-1.5S9.33 8 8.5 8 7 8.67 7 9.5 7.67 11 8.5 11zm3.5 6.5c2.33 0 4.31-1.46 5.11-3.5H6.89c.8 2.04 2.78 3.5 5.11 3.5z"/>
                </svg>
              </div>
              <div class="info-text">
                <span class="info-label">Sağlık Kontrol</span>
                <a href="/health">/health</a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
  `;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

// ==================== AI BULMACA OLUŞTURMA ====================
// Hesap bazlı AI rate limiting: 1 dakikada max 1 istek
const aiGenerationAttempts = new Map(); // userId -> lastTimestamp

// Her 5 dakikada AI rate limit temizliği
setInterval(() => {
  const now = Date.now();
  for (const [userId, lastTime] of aiGenerationAttempts.entries()) {
    if (now - lastTime > 5 * 60 * 1000) {
      aiGenerationAttempts.delete(userId);
    }
  }
}, 5 * 60 * 1000);

function checkAIRateLimit(userId) {
  const window = 60 * 1000; // 1 dakika
  const now = Date.now();
  const lastTime = aiGenerationAttempts.get(userId);
  if (lastTime && now - lastTime < window) {
    const remainingSeconds = Math.ceil((window - (now - lastTime)) / 1000);
    return { allowed: false, remainingSeconds };
  }
  return { allowed: true, remainingSeconds: 0 };
}

function recordAIGeneration(userId) {
  aiGenerationAttempts.set(userId, Date.now());
}

// ==================== AI BULMACA SİSTEMİ ====================

// Edebiyat konuları
const EDEBIYAT_KONULARI = [
  'Türk Edebiyatı Genel',
  'Divan Edebiyatı',
  'Halk Edebiyatı',
  'Tanzimat Edebiyatı',
  'Servetifünun Edebiyatı',
  'Milli Edebiyat',
  'Cumhuriyet Dönemi Edebiyatı',
  'Şairler ve Yazarlar',
  'Romanlar ve Hikayeler',
  'Söz Sanatları',
  'Edebi Akımlar'
];

// Model kendi bilgisine göre üret - validation yok

// Ollama'ya istek at ve cevabı al - gpt-oss uyumlu basit format
const FIXED_MODEL = 'minimax-m2.5:cloud';

function ollamaRequest(systemPrompt, userPrompt) {
  const body = JSON.stringify({
    model: FIXED_MODEL,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ],
    stream: false,
  });

  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1', port: 11434, family: 4,
      path: '/api/chat', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
    }, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          const resp = JSON.parse(raw);
          const content = (resp.message?.content || '').trim();
          resolve({ content, rawLen: raw.length });
        } catch(e) {
          reject(new Error('Ollama yanıtı parse edilemedi'));
        }
      });
    });
    req.on('error', (err) => reject(new Error(`Ollama bağlantı hatası: ${err.code || err.message}`)));
    req.setTimeout(120000, () => { req.destroy(); reject(new Error('Ollama zaman aşımı (120s)')); });
    req.write(body);
    req.end();
  });
}

// Metinden JSON çıkar
function extractJSON(text) {
  if (!text || text.length < 5) return null;
  
  // Son '}' ile ilk '{' arasını al
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  
  let json = text.substring(start, end + 1);
  
  // Temizlik
  json = json
    .replace(/[\r\n\t]/g, ' ')
    .replace(/\u2018|\u2019/g, "'")     // Akıllı tırnak
    .replace(/\u201C|\u201D/g, '"')     // Akıllı çift tırnak
    .replace(/,\s*]/g, ']')            // Trailing comma
    .replace(/,\s*}/g, '}');           // Trailing comma
  
  try { 
    const parsed = JSON.parse(json);
    if (parsed.questions?.length > 0) return parsed;
  } catch(e) {}
  
  // İkinci deneme: questions array'ini regex ile bul
  const match = text.match(/"questions"\s*:\s*\[([\s\S]*?)\]/);
  if (match) {
    try {
      let cleaned = match[1]
        .replace(/[\r\n\t]/g, ' ')
        .replace(/,\s*}/g, '}')
        .replace(/,\s*]/g, ']')
        .replace(/'([a-zA-Z0-9_]+)'\s*:/g, '"$1":');
      let arr = '[' + cleaned + ']';
      const questions = JSON.parse(arr);
      return { questions };
    } catch(e) {
      // Regex de başarısız, daha gevşek dene
      try {
        const loose = '[' + match[1].replace(/'/g, '"').replace(/  +/g, ' ') + ']';
        const q = JSON.parse(loose);
        return { questions: q };
      } catch(e2) {}
    }
  }
  
  return null;
}

// Cevabı normalize et: büyük harf, boşluk kaldır, sadece harf
function normalizeAnswer(raw) {
  if (!raw) return '';
  let ans = String(raw).trim().toUpperCase();
  
  // Tüm boşlukları kaldır (birleştir)
  ans = ans.replace(/\s+/g, '');
  
  // Sadece Türkçe harfler
  ans = ans.replace(/[^A-ZĞÜŞİÖÇ]/g, '');
  
  // 12'den uzunsa kes
  if (ans.length > 12) ans = ans.substring(0, 12);
  
  return ans;
}

// Ana AI bulmaca fonksiyonu - gpt-oss:20b kullanır
async function generateAIPuzzle(topic, mode, retryCount = 0) {
  const MAX_RETRIES = 2;
  
  let finalTopic = topic;
  if (mode === 'free' || !topic || topic.trim() === '') {
    finalTopic = EDEBIYAT_KONULARI[Math.floor(Math.random() * EDEBIYAT_KONULARI.length)];
  }

  const basePrompt = `Sen bir Türk Edebiyatı çengel bulmaca üreticisisin. Verilen konuya ait TAM 5 soru-cevap çifti üreteceksin.

CEVAP KURALLARI:
- Her cevap tek kelime olmalı (boşluk, tire yok)
- Büyük harf, 3-12 karakter (örnek: DIVAN, GAZEL, KASIDE)
- Türkçe karakterler doğru kullanılmalı: Ğ Ü Ş İ Ö Ç
- 5 cevap birbirinden farklı olmalı
- Cevaplar konuyla doğrudan ilgili olmalı: şair adı, eser adı, nazım türü, edebi akım veya terim

SORU KURALLARI:
- Her soru kısa ve net olmalı (1-2 cümle yeter)
- Çengel bulmaca tarzı: tanımlayıcı, ipucu niteliğinde
- Soruda ASLA çift tırnak (") kullanma

ÇIKTI: Yalnızca tek satır JSON döndür. Markdown, açıklama, boşluk satırı ekleme.
ŞEMA: {"questions":[{"question":"...","answer":"..."},{"question":"...","answer":"..."},{"question":"...","answer":"..."},{"question":"...","answer":"..."},{"question":"...","answer":"..."}]}`;

  const jsonInstruction = FIXED_MODEL.startsWith('llama')
    ? ' Cevabı tek satır JSON olarak ver, noktalama için sadece soru işareti kullan.'
    : '';

  const systemPrompt = `${basePrompt}${jsonInstruction}`;

  const userPrompt = `Konu: "${finalTopic}"\n\nSadece JSON döndür.`;

  try {
    console.log(`   ⏳ Deneme ${retryCount + 1}/${MAX_RETRIES + 1} - Model: ${FIXED_MODEL} - Konu: ${finalTopic}`);
    
    const response = await ollamaRequest(systemPrompt, userPrompt);
    
    console.log(`   🔍 Response: content=${response.content.length}B, raw=${response.rawLen}B`);
    console.log(`   📋 Content (ilk 200): ${response.content.substring(0, 200)}`);
    
    // Content'ten JSON çıkar
    let puzzleData = extractJSON(response.content);
    
    if (!puzzleData?.questions?.length) {
      console.log(`   ❌ JSON çıkarılamadı. Content (ilk 200): "${(response.content || '').substring(0, 200)}"`);
      if (retryCount < MAX_RETRIES) return generateAIPuzzle(topic, mode, retryCount + 1);
      throw new Error('CaYaDevAI geçerli yanıt üretemedi. Tekrar deneyin.');
    }

    console.log(`   ✓ JSON parse başarılı, ${puzzleData.questions.length} soru bulundu`);

    // Soruları normalize et, filtrele, geçerlilik kontrol et
    const seenAnswers = new Set();
    const valid = [];
    const rejected = [];
    
    for (const q of puzzleData.questions) {
      if (valid.length >= 5) break;
      if (!q?.question || !q?.answer) continue;
      
      const rawAnswer = String(q.answer).trim();
      const answer = normalizeAnswer(rawAnswer);
      const question = String(q.question).trim();
      
      // Format kontrolü
      if (answer.length < 3 || answer.length > 12 || question.length < 3) {
        rejected.push(`${rawAnswer} (uzunluk: ${answer.length})`);
        continue;
      }
      
      // Tekrar kontrol
      if (seenAnswers.has(answer)) {
        rejected.push(`${answer} (tekrar)`);
        continue;
      }
      
      seenAnswers.add(answer);
      valid.push({ question: question.substring(0, 150), answer, number: valid.length + 1 });
    }

    console.log(`   ✅ ${valid.length} geçerli: ${valid.map(v => v.answer).join(', ')}`);
    if (rejected.length > 0) console.log(`   ⚠️  Atılan: ${rejected.join(' | ')}`);

    if (valid.length < 3) {
      if (retryCount < MAX_RETRIES) {
        console.log(`   🔄 Retry ${retryCount + 1}/${MAX_RETRIES}...`);
        return generateAIPuzzle(topic, mode, retryCount + 1);
      }
      throw new Error('CaYaDevAI yeterli doğru soru bulamadı.');
    }

    return valid;
  } catch (e) {
    if (e.message.includes('CaYaDevAI')) throw e;
    console.log(`   💥 Hata: ${e.message}`);
    if (retryCount < MAX_RETRIES) return generateAIPuzzle(topic, mode, retryCount + 1);
    throw new Error('CaYaDevAI sunucusuna bağlanılamıyor. Ollama çalışıyor mu?');
  }
}

// Grid oluşturma - kesişim tabanlı
function generateCrosswordGrid(questions) {
  const gridSize = 15;
  const grid = Array(gridSize).fill().map(() => Array(gridSize).fill(''));
  const words = [];
  const sorted = [...questions].sort((a, b) => b.answer.length - a.answer.length);
  let wordNum = 1;

  // İlk kelime ortaya yatay
  const first = sorted[0];
  const startRow = Math.floor(gridSize / 2);
  const startCol = Math.floor((gridSize - first.answer.length) / 2);
  for (let i = 0; i < first.answer.length; i++) grid[startRow][startCol + i] = first.answer[i];
  words.push({ id: 'ai_word_1', question: first.question, answer: first.answer, row: startRow, col: startCol, direction: 'across', number: wordNum++ });

  // Diğer kelimeler
  for (let wi = 1; wi < sorted.length; wi++) {
    const word = sorted[wi];
    let placed = false;
    
    for (const pw of words) {
      if (placed) break;
      for (let pi = 0; pi < pw.answer.length && !placed; pi++) {
        for (let ci = 0; ci < word.answer.length && !placed; ci++) {
          if (pw.answer[pi] !== word.answer[ci]) continue;
          
          const dir = pw.direction === 'across' ? 'down' : 'across';
          const row = dir === 'across' ? pw.row + pi : pw.row - ci;
          const col = dir === 'across' ? pw.col - ci : pw.col + pi;
          
          // Sınır kontrolü
          if (dir === 'across' && (col < 0 || col + word.answer.length > gridSize || row < 0 || row >= gridSize)) continue;
          if (dir === 'down' && (row < 0 || row + word.answer.length > gridSize || col < 0 || col >= gridSize)) continue;

          // Çakışma kontrolü
          let ok = true;
          for (let k = 0; k < word.answer.length && ok; k++) {
            const r = dir === 'across' ? row : row + k;
            const c = dir === 'across' ? col + k : col;
            if (grid[r][c] && grid[r][c] !== word.answer[k]) { ok = false; break; }
            if (!grid[r][c]) {
              if (dir === 'across' && (grid[r-1]?.[c] || grid[r+1]?.[c])) { ok = false; break; }
              if (dir === 'down' && (grid[r]?.[c-1] || grid[r]?.[c+1])) { ok = false; break; }
            }
          }
          // Uç kontrol
          if (ok && dir === 'across') {
            if (col > 0 && grid[row][col-1]) ok = false;
            if (col + word.answer.length < gridSize && grid[row][col + word.answer.length]) ok = false;
          }
          if (ok && dir === 'down') {
            if (row > 0 && grid[row-1]?.[col]) ok = false;
            if (row + word.answer.length < gridSize && grid[row + word.answer.length]?.[col]) ok = false;
          }
          
          if (ok) {
            for (let k = 0; k < word.answer.length; k++) {
              const r = dir === 'across' ? row : row + k;
              const c = dir === 'across' ? col + k : col;
              grid[r][c] = word.answer[k];
            }
            words.push({ id: `ai_word_${wi+1}`, question: word.question, answer: word.answer, row, col, direction: dir, number: wordNum++ });
            placed = true;
          }
        }
      }
    }
  }

  // Grid boyutunu hesapla
  let minR = gridSize, maxR = 0, minC = gridSize, maxC = 0;
  for (let r = 0; r < gridSize; r++)
    for (let c = 0; c < gridSize; c++)
      if (grid[r][c]) { minR = Math.min(minR, r); maxR = Math.max(maxR, r); minC = Math.min(minC, c); maxC = Math.max(maxC, c); }

  minR = Math.max(0, minR - 1); minC = Math.max(0, minC - 1);
  maxR = Math.min(gridSize - 1, maxR + 1); maxC = Math.min(gridSize - 1, maxC + 1);

  const sortedWords = words
    .map(w => ({ ...w, row: w.row - minR, col: w.col - minC }))
    .sort((a, b) => a.row !== b.row ? a.row - b.row : a.col - b.col);
  sortedWords.forEach((w, i) => { w.number = i + 1; });

  return { gridRows: Math.min(15, maxR - minR + 1), gridCols: Math.min(15, maxC - minC + 1), words: sortedWords };
}

// AI Bulmaca durumu
app.get('/ai/status', (req, res) => {
  res.json({ aiEnabled: AI_ENABLED, model: FIXED_MODEL });
});

function ensureAIEnabled(req, res, next) {
  if (!AI_ENABLED) {
    return res.status(503).json({ error: 'AI özellikleri şu an kapalı' });
  }
  next();
}

// AI Bulmaca oluşturma endpoint'i
// ==================== AI JOB STORE ====================
// Cloudflare'ın 100s timeout'unu aşmak için async job pattern.
// POST → jobId döner (hemen), GET /ai/puzzle-result/:jobId → sonucu poll et.
const aiJobs = new Map(); // jobId -> { status, puzzle, error, createdAt }

// Her 10 dakikada eski job'ları temizle (15 dakikadan eskiler)
setInterval(() => {
  const cutoff = Date.now() - 15 * 60 * 1000;
  for (const [jobId, job] of aiJobs.entries()) {
    if (job.createdAt < cutoff) aiJobs.delete(jobId);
  }
}, 10 * 60 * 1000);

// AI Bulmaca oluşturma endpoint'i — hemen jobId döner, arka planda üretir
app.post('/ai/generate-puzzle', ensureAIEnabled, authenticateToken, (req, res) => {
  const userId = req.user.id;
  const rateCheck = checkAIRateLimit(userId);
  if (!rateCheck.allowed) {
    return res.status(429).json({ error: `Çok sık istek. ${rateCheck.remainingSeconds} saniye bekleyin.`, remainingSeconds: rateCheck.remainingSeconds });
  }

  // Rate limit'i hemen kaydet (paralel istekleri önle)
  recordAIGeneration(userId);

  const { topic, mode } = req.body;
  const jobId = uuidv4();
  aiJobs.set(jobId, { status: 'pending', puzzle: null, error: null, createdAt: Date.now() });

  console.log(`🤖 AI Job başlatıldı: ${jobId} - Kullanıcı: ${req.user.username}, Konu: ${topic || 'Serbest'}`);

  // Arka planda üret (response'u bekletme)
  (async () => {
    try {
      const questions = await generateAIPuzzle(topic, mode);
      const gridData = generateCrosswordGrid(questions);
      const puzzleId = `ai_${uuidv4().substring(0, 8)}`;
      const puzzle = {
        id: puzzleId,
        title: topic ? `AI: ${topic}` : 'AI Bulmaca',
        difficulty: 2,
        description: `Yapay zeka tarafından oluşturuldu${topic ? ` - Konu: ${topic}` : ''}`,
        gridRows: gridData.gridRows, gridCols: gridData.gridCols, words: gridData.words,
        isAIGenerated: true, generatedAt: new Date().toISOString(),
      };
      console.log(`✅ AI Job tamamlandı: ${jobId} → ${puzzleId} (${gridData.words.length} kelime)`);
      const job = aiJobs.get(jobId);
      if (job) { job.status = 'completed'; job.puzzle = puzzle; }
    } catch (error) {
      console.error(`❌ AI Job hatası: ${jobId} → ${error.message}`);
      const job = aiJobs.get(jobId);
      if (job) { job.status = 'failed'; job.error = error.message || 'Bulmaca oluşturulamadı'; }
    }
  })();

  // Cloudflare'ı bekletmeden hemen jobId dön
  res.status(202).json({ jobId });
});

// AI Job sonucunu poll et
app.get('/ai/puzzle-result/:jobId', ensureAIEnabled, authenticateToken, (req, res) => {
  const { jobId } = req.params;
  const job = aiJobs.get(jobId);
  if (!job) return res.status(404).json({ error: 'Job bulunamadı veya süresi doldu' });

  if (job.status === 'pending') return res.json({ status: 'pending' });
  if (job.status === 'completed') {
    // Teslim edildikten sonra job'ı sil (tek seferlik)
    aiJobs.delete(jobId);
    return res.json({ status: 'completed', message: 'Bulmaca başarıyla oluşturuldu', puzzle: job.puzzle });
  }
  // failed
  aiJobs.delete(jobId);
  return res.status(500).json({ status: 'failed', error: job.error });
});

// Rate limit durumu
app.get('/ai/rate-limit-status', ensureAIEnabled, authenticateToken, (req, res) => {
  const rateCheck = checkAIRateLimit(req.user.id);
  res.json({ canGenerate: rateCheck.allowed, remainingSeconds: rateCheck.remainingSeconds });
});

// ==================== STATIK DOSYALAR (API rotalarından sonra) ====================
// Üst dizindeki dosyaları serve et (logolar, assets için)
app.use(express.static(path.join(__dirname, '..')));

// ==================== SAĞLIK KONTROLÜ ====================
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ==================== SUNUCUYU BAŞLAT ====================
// Açılışta veri migration'ını çalıştır (idempotent — her çalıştırmada güvenli)
try {
  migrateUserDataIfNeeded();
} catch (e) {
  console.error('[MIGRATION] Hata:', e);
}

server.listen(PORT, async () => {
  const timestamp = new Date().toISOString();
  console.log(`\n${'='.repeat(60)}`);
  console.log(`🚀 Edebi Çengel Sunucu BAŞLADI`);
  console.log(`${'='.repeat(60)}`);
  console.log(`⏰ Zaman: ${timestamp}`);
  console.log(`🔌 Port: ${PORT}`);
  console.log(`📡 Transport: REST API + Long Polling`);
  console.log(`🔄 Çoklu Oyuncu: REST API aktif`);
  console.log(`🌍 Public URL: https://app.cayadev.com/edebi-cengel-server`);
  console.log(`📊 Sıralama: http://localhost:${PORT}/leaderboard`);
  console.log(`🎮 Çoklu Oyuncu: REST API + Long Polling aktif (${activeRooms.size} rooms)`);
  console.log(`❤️  Sağlık: http://localhost:${PORT}/health`);
  console.log(`🤖 AI Bulmaca: ${AI_ENABLED ? 'Aktif' : 'Kapalı'}`);
  console.log(`${'='.repeat(60)}\n`);
});

