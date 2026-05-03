# 🎯 Edebî Çengel — Flutter Uygulaması

Türk edebiyatı ve kültürü temalı modern çengel bulmaca oyununun Flutter kaynak kodu.

## 🚀 Özellikler

### Oyun Özellikleri
- **Cross-platform**: Windows, Android, iOS, Web desteği
- **Offline çalışma**: İnternet bağlantısı gerektirmez
- **Çoklu konu desteği**: Farklı konularda bulmacalar
- **Zorluk seviyeleri**: Kolay / Orta / Zor
- **Çengel bulmaca sistemi**: Belirli harfler görünür, diğerleri gizli
- **Ses desteği**: Tuş sesleri ve efektler
- **Skor sistemi**: Zorluk seviyesine göre puan hesaplama
- **İlerleme takibi**: Oyun oturumları ve istatistikler

### Çevrimiçi Özellikler
- **Kullanıcı kaydı / girişi** (JWT tabanlı)
- **CaYaDev OAuth** ile giriş
- **Çok oyunculu mod** (REST API tabanlı)
- **Liderlik tablosu**
- **AI destekli bulmaca üretimi**
- **Konu bazlı başarı sistemi**

## 📁 Klasör Yapısı

```
cengel_bulmaca/
├── lib/
│   ├── main.dart            # Uygulama giriş noktası
│   ├── config/              # Sabitler ve yapılandırma
│   ├── models/              # Veri modelleri
│   ├── providers/           # State yönetimi (Provider)
│   ├── screens/             # Uygulama ekranları
│   ├── services/            # API, auth, yerel depolama
│   ├── utils/               # Yardımcı fonksiyonlar
│   └── widgets/             # Yeniden kullanılabilir UI bileşenleri
├── assets/
│   ├── data/                # JSON veri dosyaları (bulmacalar, ipuçları)
│   ├── media/               # Görseller ve logolar
│   └── sounds/              # Ses efektleri
└── pubspec.yaml             # Flutter bağımlılıkları
```

## 🛠️ Kurulum

### Gereksinimler
- Flutter SDK (3.9.0+)
- Dart SDK
- Visual Studio (Windows için)
- Android Studio (Android için)
- Xcode (iOS için)

### Adımlar

1. **Bağımlılıkları yükle:**
```bash
cd cengel_bulmaca
flutter pub get
```

2. **Sunucuyu yapılandır** (çevrimiçi özellikler için):
   - `server/` klasöründe `.env.example` → `.env` kopyala ve düzenle
   - `lib/services/api_service.dart` içindeki `_baseUrl` değerini güncelle

3. **Uygulamayı başlat:**
```bash
flutter run
```

## 📝 Veri Formatı

### Bulmaca Seti (crossword_clues.json)
```json
{
  "id": "tanzimat_edebiyati_1",
  "name": "Tanzimat Edebiyatı 1",
  "difficulty": 1,
  "clues": [
    {
      "question": "Şinasi'nin ilk Türkçe tiyatro eseri",
      "answer": "Şair Evlenmesi"
    }
  ]
}
```

### Konular (topics.json)
```json
{
  "id": "edebiyat",
  "name": "Türk Edebiyatı",
  "description": "Türk edebiyatından ünlü eserler ve yazarlar",
  "puzzleSets": []
}
```

## 🔧 Build İşlemleri

```bash
# Android APK
flutter build apk --release

# Windows
flutter build windows --release

# Web
flutter build web --release

# iOS (macOS gerekli)
flutter build ios --release
```

## 📱 Platform Desteği

| Platform | Durum  | Notlar                        |
|----------|--------|-------------------------------|
| Windows  | ✅ Tam | Native Windows uygulaması     |
| Android  | ✅ Tam | APK ve AAB formatları         |
| Web      | ✅ Tam | Modern tarayıcılar            |
| iOS      | 🔄 Kısmi | Mevcut kısıtlamalar mevcut  |

## 🎨 Tema Sistemi

7 farklı tema: Teal (varsayılan), Turuncu, Mor, Mavi, Pembe, Yeşil, Indigo.  
`lib/providers/theme_provider.dart` dosyasından yönetilir.

## 🔗 Bağlantılı Kaynaklar

- [Ana Proje README](../README.md) — Uygulama hakkında genel bilgi
- [Sunucu Kurulumu](../server/.env.example) — Backend ortam değişkenleri
