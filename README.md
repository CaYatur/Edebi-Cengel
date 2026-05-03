# Edebî Çengel

- Edebî Çengel: Edebiyat Öğretiminde Dijital Bulmacalar
- **Edebî Çengel**, Türk edebiyatı ve kültürü temalı **modern bir çengel bulmaca** uygulamasıdır. Tek oyunculu deneyimin yanında arkadaşlarınla yarışabileceğin **çok oyunculu** mod sunar. **Offline-first** mimarisi sayesinde internet olmadan da tam oyun deneyimi sağlar; çevrimiçi olunduğunda ise profil, puan ve istatistikler **senkronize** edilebilir.

> **Amaç:** Türk edebiyatını oyunlaştırarak daha eğlenceli, erişilebilir ve sürdürülebilir bir öğrenme/tekrar deneyimine dönüştürmek.

---

## ✨ Öne Çıkan Özellikler

- Türk edebiyatı temalı çengel bulmaca sistemi
- CaYaDev yetkilendirmesiyle giriş deneyimi
- Konu Bazlı Başarı, zayıf konu tespiti ve gelişim analizi
- AI destekli bulmaca üretimi
- Konu Bazlı Başarı ekranından zayıf konulara özel AI destekli soru ve bulmaca oluşturma
- REST API tabanlı çok oyunculu oyun altyapısı
- Profil, rozet, puan, unvan ve liderlik sistemi
- Offline-first mimari
- Windows, Android ve Web desteği
- Modern, mobil uyumlu ve tema destekli arayüz

---

## 🧩 Çengel Bulmaca Sistemi

Edebî Çengel’in temel oyun yapısı, Türk edebiyatı odaklı çengel bulmacalar üzerine kuruludur. Kullanıcılar farklı edebiyat dönemleri, yazarlar, eserler, kavramlar ve kültürel başlıklar üzerinden hazırlanmış bulmacaları çözerek hem bilgilerini tekrar eder hem de yeni içeriklerle karşılaşır.

- Kısmi harf gösterimiyle **tahmin + tamamlama** mekanikleri
- Kolay, orta ve zor seviyelerle **kademeli zorluk yapısı**
- Türk edebiyatı dönemleri, eserleri, yazarları ve kavramlarına uygun kategori sistemi
- Türkçe karakter desteği: **Ç, Ğ, İ, Ö, Ş, Ü**
- Otomatik Türkçe karakter normalizasyonu
- Öğrenme odaklı tekrar ve çözüm akışı
- Kategori bazlı bulmaca deneyimi
- Tekrar oynanabilir içerik yapısı

---

## 👤 Giriş, Hesap ve CaYaDev Yetkilendirmesi

Edebî Çengel, kullanıcıların ilerlemelerini güvenli şekilde saklayabilmesi ve çevrim içi özelliklerden yararlanabilmesi için hesap sistemiyle çalışır. Kullanıcılar klasik giriş/kayıt ekranları üzerinden uygulamaya erişebildiği gibi CaYaDev yetkilendirme altyapısı üzerinden de giriş yapabilir.

### 🔐 Hesap Sistemi

- Kullanıcı adı ve şifre ile giriş/kayıt desteği
- Profil, istatistik ve puan bilgilerinin kullanıcı hesabına bağlanması
- Oturum yönetimi
- Çevrim içi modlarda kullanıcı kimliği doğrulama
- Hesaba bağlı başarı, istatistik ve gelişim takibi
- Profil verilerinin sunucu tarafında yönetilmesi

### 🛡️ CaYaDev ile Giriş

CaYaDev yetkilendirmesi, kullanıcıların CaYaDev ekosistemiyle uyumlu şekilde uygulamaya giriş yapmasını sağlar. Bu yapı; merkezi kullanıcı doğrulama, güvenli oturum yönetimi ve hesap bütünlüğü açısından daha düzenli bir kullanım deneyimi oluşturur.

- CaYaDev hesabı ile giriş desteği
- Harici yetkilendirme mantığı
- Daha güvenli kullanıcı doğrulama süreci
- Kullanıcı kimliği ve oturum bütünlüğü
- Web ve çevrim içi sistemlerle uyumlu giriş akışı
- Uygulama içi profil, istatistik ve puan verileriyle bağlantılı hesap yapısı

---

## 📊 Konu Bazlı Başarı Sistemi

Edebî Çengel’de kullanıcı başarısı yalnızca toplam puanla ölçülmez. Uygulama, kullanıcının hangi konularda güçlü olduğunu, hangi konularda daha fazla çalışması gerektiğini ve kategori bazında nasıl ilerlediğini ayrı ayrı takip eder.

Bu sistem, uygulamayı yalnızca bir bulmaca oyunu olmaktan çıkarıp kişiselleştirilmiş bir edebiyat çalışma aracına dönüştürür.

### 📌 Genel Başarı Ortalaması

Konu Bazlı Başarı ekranında kullanıcının genel performansını gösteren özet bir alan bulunur.

- Genel başarı yüzdesi
- Oynanan kategori sayısı
- Toplam doğru kelime sayısı
- Toplam yanlış kelime sayısı
- Kullanıcının genel edebiyat performansını gösteren özet kart
- Gelişim durumunu hızlı anlamayı sağlayan sade gösterim

### 📚 Edebiyat Kategorileri

Her edebiyat kategorisi ayrı bir başarı kartı olarak gösterilir. Kullanıcı her başlıkta kendi performansını bağımsız şekilde takip edebilir.

Örnek kategori başlıkları:

- Âşık Tekke Edebiyatı
- Divan Edebiyatı
- İslamiyet Öncesi Türk Edebiyatı
- 13. ve 14. Yüzyıl Türk Edebiyatı
- Cumhuriyet Dönemi
- Divan Edebiyatı alt başlıkları
- Diğer dönem, tür, yazar ve eser kategorileri

Her kategori için:

- Oynanan bulmaca sayısı
- Doğru kelime sayısı
- Yanlış kelime sayısı
- Başarı yüzdesi
- Görsel ilerleme çubuğu
- Kategori durum rengi
- Henüz oynanmamış kategoriler için ayrı durum görünümü

bulunur.

### ⚠️ Çalışılması Gereken Konular

Konu Bazlı Başarı sistemi, düşük başarı oranına sahip kategorileri otomatik olarak öne çıkarır. Böylece kullanıcı yalnızca başarılı olduğu alanları değil, geliştirmesi gereken konuları da net şekilde görebilir.

- Zayıf olunan konuların belirlenmesi
- Düşük başarı yüzdesine sahip kategoriler için uyarı kartı
- Kullanıcıyı ilgili konuya yönlendiren çalışma butonu
- Eksik konulara odaklanmayı kolaylaştıran öğrenme akışı
- Hedefli tekrar yapma imkânı
- Sınav ve konu tekrarı için daha verimli çalışma deneyimi

### 🤖 AI Destekli Çalışma ve Soru Oluşturma

Konu Bazlı Başarı ekranı, kullanıcının performansını yalnızca göstermenin ötesine geçerek doğrudan çalışma aksiyonuna dönüştürür. AI Destekli Çalışma alanı, kullanıcının en zayıf olduğu konuyu öne çıkarır ve bu konuya özel çengel bulmaca/soru çalışması başlatmayı sağlar.

Bu yapı sayesinde kullanıcı, hangi konuda eksik olduğunu gördüğü anda aynı ekrandan yapay zekâ destekli yeni bir çalışma oluşturabilir. Böylece başarı analizi ile kişiselleştirilmiş içerik üretimi tek bir öğrenme akışında birleşir.

- En zayıf konunun otomatik olarak öne çıkarılması
- En zayıf konuya özel AI destekli bulmaca oluşturma
- Çalışılması gereken her konu için ayrı AI çalışma butonu
- Seçilen kategoriye özel 5 soruluk çengel bulmaca hazırlama
- Konu başarısı düşük alanlarda hedefli tekrar yapma imkânı
- Edebiyat dönemi, yazar, eser ve kavramlara uygun soru-cevap üretimi
- Başarı ekranından doğrudan çalışma akışına geçiş
- Kullanıcının eksik olduğu başlıklara göre kişiselleştirilmiş çalışma deneyimi

Örneğin kullanıcı bir kategoride düşük başarı oranına sahipse, sistem bu kategoriyi “çalışılması gereken konu” olarak gösterebilir ve kullanıcı aynı kart üzerindeki AI butonuyla o konuya özel yeni sorular oluşturabilir. Bu sayede uygulama, yalnızca sonuç gösteren bir istatistik ekranı değil; eksikleri tamamlamaya yardımcı olan aktif bir öğrenme aracına dönüşür.

### 📈 Görsel Performans Takibi

Başarı ekranı sade, okunabilir ve hızlı anlaşılır bir yapıya sahiptir.

- Yeşil tonlar güçlü performansı gösterir
- Kırmızı tonlar çalışılması gereken alanları belirtir
- Henüz oynanmamış kategoriler nötr şekilde gösterilir
- İlerleme çubuklarıyla başarı oranı görsel olarak izlenir
- Mobil kullanım için kart tabanlı düzen kullanılır

---

## 👥 Çok Oyunculu Deneyim — REST API Tabanlı

Edebî Çengel’in çok oyunculu altyapısı, REST API tabanlı bir mimariyle çalışır. Bu yaklaşım, farklı ağ koşullarında daha kolay yönetilebilir, daha uyumlu ve daha stabil bir sunucu iletişimi sağlar.

### 🎮 Multiplayer İçeriği

- Oda oluşturma
- Odaya katılma
- Odadan ayrılma
- Herkese açık / özel oda seçimi
- Oda sahibi yönetimi
- Hazır durumu sistemi
- Oyuncu listesi senkronizasyonu
- Oda durumunun düzenli olarak güncellenmesi
- Skor ve ilerleme senkronizasyonu
- Oyun sonunda sıralama ve sonuç ekranı
- İsteğe bağlı sohbet altyapısı

### 🧑‍✈️ Host Kontrolü

Oda sahibi, oyun ayarlarını ve başlatma sürecini yönetebilir.

- Oyun başlatma kontrolü
- Oda ayarlarını yönetme
- Oyuncu hazır durumlarını takip etme
- Oyun akışını merkezi şekilde yönetme

---

## 🤖 AI Destekli Bulmaca Üretimi

Edebî Çengel, yapay zekâ destekli bulmaca üretim sistemiyle dinamik ve tekrar oynanabilir içerikler sunar. Bu yapı, sabit veriyle sınırlı kalmayan daha geniş bir bulmaca deneyimi oluşturur.

### 🧠 Yapay Zekâ Algoritması

AI sistemi; kategori, konu, edebiyat dönemi ve kullanıcı girdilerine göre uygun içerik üretmeye odaklanır. Bulmaca üretim mantığı, Türk edebiyatı bağlamına uygun soru-cevap ilişkileri kuracak şekilde tasarlanmıştır.

- Dinamik bulmaca üretimi
- Kategori/tema uyumlu içerik oluşturma
- Serbest konu girişiyle özel bulmaca üretme
- Tekrarsız oynanış hissi
- Türkçe dil yapısına uygun içerik üretme yaklaşımı
- Edebiyat kavramları, yazarlar, eserler ve dönemlere göre özelleştirilebilir üretim
- Sunucu tarafında daha güçlü AI üretim akışı
- Bulmaca verilerinin kategori ve başarı sistemiyle uyumlu çalışması

### ⚙️ AI Bulmaca Modu

Kullanıcılar AI Bulmaca modunda farklı şekillerde içerik oluşturabilir:

- Üretimi tamamen yapay zekâya bırakabilir
- Belirli bir kategori seçebilir
- Belirli bir tema seçebilir
- Kendi belirlediği konuyu serbest metin olarak yazabilir
- Belirli bir edebiyat başlığına yönelik özel bulmaca oluşturabilir

> **Not:** AI Bulmaca özelliği, sunucu maliyetleri veya sistem yoğunluğu gibi nedenlerle bazı dönemlerde görünür olmayabilir. Özellik aktif olmadığında kullanıcı arayüzünde gösterilmez.

### 📊 Konu Başarısına Göre AI Soru Üretimi

AI destekli içerik üretimi, Konu Bazlı Başarı sistemiyle birlikte çalışarak kullanıcının eksik olduğu alanlara göre daha hedefli çalışmalar oluşturabilir. Kullanıcı, başarı ekranında düşük performans gösterdiği bir kategori için doğrudan AI destekli soru/bulmaca çalışması başlatabilir.

- Başarı oranı düşük konulara göre içerik önerme
- Seçili kategoriye özel soru-cevap üretimi
- En zayıf konu için hızlı AI bulmaca başlatma
- Konu tekrarını oyunlaştırılmış bir çalışma akışına dönüştürme
- Her konu kartından AI destekli çalışma oluşturabilme
- Kullanıcının gelişim verileriyle daha uyumlu öğrenme deneyimi sunma

Bu entegrasyon, yapay zekâyı yalnızca rastgele içerik üreten bir sistem olmaktan çıkarır; kullanıcının gerçek başarı verilerine göre yönlenen kişisel bir çalışma yardımcısına dönüştürür.

---

## 🧑‍💻 Profil, İstatistikler ve Gelişim

Edebî Çengel, kullanıcıların oyun içi gelişimini çok yönlü şekilde takip eder. Bu sistem, kullanıcının yalnızca kaç bulmaca çözdüğünü değil, öğrenme sürecindeki ilerlemesini de ölçmeyi hedefler.

### 📌 Oyuncu Profili

- Hesaba bağlı kullanıcı profili
- Puan, unvan ve başarı bilgileri
- Rozet ve istatistik görüntüleme
- Çevrim içi verilerle senkronize edilebilir profil yapısı
- Kullanıcıya özel gelişim takibi

### 📊 Detaylı İstatistikler

- Çözülen bulmaca sayısı
- Tamamlanan kelime sayısı
- Doldurulan hücre sayısı
- Kullanılan ipucu sayısı
- En hızlı çözüm süresi
- En iyi seri / streak değeri
- Doğru ve yanlış kelime sayıları
- Kategori bazlı başarı yüzdeleri
- Genel başarı ortalaması
- Kullanıcının eksik olduğu konu alanları
- Eksik konulara göre AI destekli soru ve bulmaca çalışmaları

### 🏅 Rozetler ve Başarı Sistemi

- Belirli hedefler tamamlandıkça açılan rozetler
- Kullanıcı motivasyonunu artıran görev/ödül döngüsü
- Profil ekranında görüntülenebilir başarılar
- Oyun içi ilerlemeyi destekleyen koleksiyon mantığı

### ⭐ Puan ve Unvan Sistemi

- Oyun içi aksiyonlara göre puan kazanımı
- Başarıya göre değişen unvan/rütbe görünümü
- Kullanıcı seviyesini yansıtan ilerleme yapısı
- Rekabet ve motivasyonu artıran puanlama sistemi

---

## 🏆 Liderlik Tablosu

Liderlik tablosu, kullanıcıların performanslarını diğer oyuncularla karşılaştırmasına olanak tanır.

- Tüm zamanlar sıralaması
- Aylık sıralama
- Haftalık sıralama
- Oyuncu puanı ve sıralama bilgisi
- Madalya sistemi
- Seviye ve rütbe bazlı görünüm
- Rekabet odaklı oyun motivasyonu

---

## 🎨 Tema, Arayüz ve Kişiselleştirme

Edebî Çengel, sade, modern ve mobil uyumlu bir arayüzle tasarlanmıştır. Arayüz; öğrenme, oyun ve istatistik ekranlarında okunabilirliği koruyacak şekilde kart tabanlı bir yapıya sahiptir.

### 🎨 Tema Seçenekleri

- Teal / Orijinal tema
- Turuncu tema
- Mor tema
- Mavi tema
- Pembe tema
- Yeşil tema
- Indigo tema

### 🖥️ Arayüz Yapısı

- Modern kart tabanlı tasarım
- Mobil cihazlara uygun ekran düzeni
- Okunabilir metin ve ikon kullanımı
- Giriş/kayıt ekranlarında sade kullanıcı deneyimi
- Başarı ekranlarında renklerle desteklenen görsel geri bildirim
- Form alanlarında anlaşılır giriş deneyimi
- Ekranlar arası tutarlı tasarım dili
- Kararlı ve hataya dayanıklı arayüz davranışı

### 🔊 Kişiselleştirme

- Ses ayarları
- Animasyon ayarları
- Tema tercihi
- Kullanıcı deneyimini kişiye göre uyarlayan seçenekler

---

## 🔌 Offline-First Deneyim

Edebî Çengel, internet bağlantısı olmadan da kullanılabilecek şekilde tasarlanmıştır.

- İnternet olmadan oynanabilir temel oyun deneyimi
- Offline çözülen bulmacalar
- Yerel istatistik ve ilerleme takibi
- Çevrim içi olunduğunda senkronizasyon imkânı
- Okul, ev, yolculuk ve internetin sınırlı olduğu ortamlarda kullanılabilir yapı

> Çok oyunculu mod, AI destekli bulmaca üretimi, çevrim içi profil senkronizasyonu ve web tabanlı bazı özellikler internet bağlantısı gerektirir.

---

## 🖥️ Platform Desteği

Edebî Çengel, Flutter tabanlı çok platformlu yapısıyla tek kod tabanından farklı cihazlarda çalışabilecek şekilde geliştirilmiştir.

- Windows
- Android
- Web
- iOS *(mevcut kısıtlamalar nedeniyle aktif kullanımda değildir)*

---

## 🧱 Teknik Özet

### Frontend

- Flutter / Dart tabanlı çok platformlu geliştirme
- Modern ve modüler ekran yapısı
- Kart tabanlı arayüz bileşenleri
- Tema destekli kullanıcı arayüzü
- Mobil ve masaüstü uyumlu responsive yapı
- Oyun, profil, giriş, istatistik ve başarı ekranları için ayrılmış modüler yapı

### Backend

- Node.js / Express altyapısı
- REST API tabanlı multiplayer ve kullanıcı işlemleri
- JWT tabanlı kimlik doğrulama
- CaYaDev yetkilendirme entegrasyonu
- Kullanıcı, profil, puan ve istatistik verileri için sunucu taraflı veri yönetimi
- AI bulmaca üretimi için sunucu taraflı işlem akışı
- Konu bazlı başarıya göre AI destekli soru/bulmaca oluşturma akışı
- Konu bazlı başarı verilerini destekleyen veri kolonları
- Sunucu sistemi: **1.0.2**
- Offline-first yapı ile uyumlu senkronizasyon mantığı

### Veri ve İstatistik Yapısı

- Kullanıcı hesap verileri
- Profil ve oturum bilgileri
- Bulmaca çözüm geçmişi
- Doğru / yanlış kelime kayıtları
- Kategori bazlı başarı oranları
- Genel başarı ortalaması
- Çalışılması gereken konu alanları
- Zayıf konuya göre oluşturulan AI çalışma/bulmaca verileri
- Liderlik tablosu verileri
- Rozet, unvan ve puan bilgileri

---

## 🎯 Hedef Kitle

- Türk edebiyatı meraklıları
- Lise öğrencileri
- Sınavlara hazırlanan öğrenciler
- Bulmaca seven kullanıcılar
- Okullar ve eğitim kurumları
- Arkadaşlarıyla rekabet etmek isteyen oyuncular
- Edebiyat konularını oyunlaştırılmış şekilde tekrar etmek isteyen herkes

---

## ✅ Neden Edebî Çengel?

- **Edebiyat odaklı oyunlaştırma:** Türk edebiyatını bulmaca mantığıyla öğretir.
- **Konu bazlı başarı takibi:** Kullanıcının güçlü ve zayıf olduğu konuları ayrı ayrı gösterir.
- **CaYaDev ile giriş:** Daha bütünleşik ve güvenli kullanıcı doğrulama deneyimi sunar.
- **AI destekli içerik:** Tekrarsız ve kişiselleştirilebilir bulmaca üretimi sağlar.
- **Zayıf konulara özel AI çalışma:** Kullanıcının eksik olduğu konularda doğrudan soru ve bulmaca oluşturmayı kolaylaştırır.
- **Offline-first yapı:** İnternet olmadan da temel oyun deneyimi sunar.
- **Çok oyunculu rekabet:** Arkadaşlarla yarışmayı mümkün kılar.
- **Profil, rozet ve liderlik sistemi:** Kullanıcı motivasyonunu artırır.
- **Tam Türkçe uyumu:** Türkçe karakterler ve edebiyat içeriği için özel olarak tasarlanmıştır.
- **Çok platformlu kullanım:** Windows, Android ve Web üzerinde çalışabilir.
- **Modern arayüz:** Mobil uyumlu, okunabilir ve kullanıcı dostu ekranlar sunar.

---

## 📌 Kısa Tanıtım

**Edebî Çengel**, Türk edebiyatını oyunlaştırılmış çengel bulmacalarla öğreten; konu bazlı başarı takibi, zayıf konulara göre AI destekli soru/bulmaca oluşturma, CaYaDev yetkilendirmesi, yapay zekâ destekli içerik üretimi, çok oyunculu rekabet, profil/istatistik sistemi ve offline-first mimarisiyle desteklenen modern bir eğitim oyunudur.

Kullanıcılar edebiyat dönemlerini, yazarları, eserleri ve kavramları bulmacalar üzerinden tekrar ederken; hangi konularda güçlü olduklarını, hangi alanlarda daha fazla çalışmaları gerektiğini ve bu eksik konular için AI destekli yeni çalışma içerikleri oluşturabileceklerini uygulama içinden takip edebilir.

---

## 🛠️ Geliştirici Kılavuzu

Flutter uygulamasını kurmak ve geliştirmek için: 👉 [cengel_bulmaca/README.md](cengel_bulmaca/README.md)

### Proje Yapısı

```
GameKelime/
├── cengel_bulmaca/        # Flutter uygulaması (kaynak kod)
├── server/                # Node.js backend (REST API + Socket.IO)
│   └── .env.example       # Gerekli ortam değişkenleri şablonu
├── content_manager/       # Web tabanlı içerik editörü
└── bulmacalar/            # Veri üretici araçlar
```

### Sunucuyu Başlatmak

```bash
cd server
cp .env.example .env   # .env dosyasını oluştur ve düzenle
npm install
npm start
```
