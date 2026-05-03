@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM ======================================
REM Edebi Çengel - Derleme Aracı
REM APK, Windows ve Web versiyonlarını derler
REM ======================================

cd /d "%~dp0"

REM Flutter PATH ayarı
set "FLUTTER_BIN=C:\Users\cagan\AppData\Local\flutter\bin"
if not exist "%FLUTTER_BIN%\flutter.bat" (
    echo ✗ Flutter bulunamadı: %FLUTTER_BIN%
    echo   Lütfen Flutter kurulum yolunu BUILD_ALL.bat içindeki FLUTTER_BIN değişkenine yazın.
    pause
    exit /b 1
)
set "PATH=%FLUTTER_BIN%;%PATH%"

echo.
echo ╔════════════════════════════════════════════╗
echo ║  Edebi Çengel - Derleme Aracı              ║
echo ║  APK + Windows + Web Derlemesi             ║
echo ╚════════════════════════════════════════════╝
echo.

REM ---- Sürüm Bilgisi ----
:ask_version
set "BUILD_NAME="
set /p BUILD_NAME=Uygulama surumu (orn: 1.2.0): 
if "%BUILD_NAME%"=="" (
    echo   X Surum bos birakilamaz!
    goto ask_version
)
REM Nokta var mi kontrolu: noktayi kaldir, esit mi bak
set "CHECK_DOT=%BUILD_NAME:.=%"
if "%CHECK_DOT%"=="%BUILD_NAME%" (
    echo   X Gecersiz format. Lutfen x.y.z seklinde girin ^(orn: 1.2.0^)
    goto ask_version
)

:ask_build_number
set "BUILD_NUMBER="
set /p BUILD_NUMBER=Build numarasi (orn: 5): 
if "%BUILD_NUMBER%"=="" (
    echo   X Build numarasi bos birakilamaz!
    goto ask_build_number
)

echo.
echo   + Surum: %BUILD_NAME%+%BUILD_NUMBER%
echo.

REM BuildedREADY klasörünü oluştur
if exist BuildedREADY (
    echo [1/7] BuildedREADY klasörü temizleniyor...
    rmdir /s /q BuildedREADY
) else (
    echo [1/7] BuildedREADY klasörü oluşturuluyor...
)

mkdir BuildedREADY
mkdir BuildedREADY\apk
mkdir BuildedREADY\windows
mkdir BuildedREADY\web

cd cengel_bulmaca

echo.
echo [2/7] Flutter pub get çalıştırılıyor...
call flutter pub get
if %errorlevel% neq 0 (
    echo ✗ Flutter pub get başarısız!
    pause
    exit /b 1
)

echo.
echo [3/7] APK derlemesi başlanıyor (bu biraz zaman alabilir)...
call flutter build apk --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%
if %errorlevel% neq 0 (
    echo ✗ APK derleme başarısız!
    pause
    exit /b 1
)
echo ✓ APK derleme tamamlandı

REM APK'yı kopyala ve adlandır
if exist build\app\outputs\flutter-apk\app-release.apk (
    echo   APK dosyası kopyalanıyor ve yeniden adlandırılıyor...
    copy build\app\outputs\flutter-apk\app-release.apk ..\BuildedREADY\apk\EdebiCengelAndroid.apk
    echo   ✓ APK başarıyla kopyalandı: EdebiCengelAndroid.apk
) else (
    echo   ✗ APK dosyası bulunamadı!
    pause
    exit /b 1
)

echo.
echo [4/7] Windows derlemesi başlanıyor...
call flutter build windows --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%
if %errorlevel% neq 0 (
    echo ✗ Windows derleme başarısız!
    pause
    exit /b 1
)
echo ✓ Windows derleme tamamlandı

REM Windows dosyalarını kopyala ve exe'yi adlandır
if exist build\windows\x64\runner\Release\ (
    echo   Windows dosyaları kopyalanıyor...
    xcopy build\windows\x64\runner\Release ..\BuildedREADY\windows\EdebiCengel_Bulmaca_Windows /e /i /y > nul
    
    REM exe'yi yeniden adlandır
    if exist ..\BuildedREADY\windows\EdebiCengel_Bulmaca_Windows\cengel_bulmaca.exe (
        ren ..\BuildedREADY\windows\EdebiCengel_Bulmaca_Windows\cengel_bulmaca.exe EdebiCengel.exe
    )
    
    echo   ✓ Windows dosyaları başarıyla kopyalandı
    
    REM Zip paketi oluştur
    echo   Windows klasörü zip'leniyor...
    cd ..\BuildedREADY\windows
    powershell -NoProfile -Command "Compress-Archive -Path 'EdebiCengel_Bulmaca_Windows' -DestinationPath 'EdebiCengel_Bulmaca_Windows.zip' -Force"
    if exist EdebiCengel_Bulmaca_Windows.zip (
        echo   ✓ Zip paketi oluşturuldu: EdebiCengel_Bulmaca_Windows.zip
        REM Klasörü sil, sadece zip bırak
        rmdir /s /q EdebiCengel_Bulmaca_Windows
    )
    cd ..\..\cengel_bulmaca
) else (
    echo   ✗ Windows dosyaları bulunamadı!
    echo   Beklenen path: build\windows\x64\runner\Release\
    pause
    exit /b 1
)

echo.
echo [5/7] Web derlemesi başlanıyor...
call flutter build web --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%
if %errorlevel% neq 0 (
    echo ✗ Web derleme başarısız!
    pause
    exit /b 1
)
echo ✓ Web derleme tamamlandı

REM Web dosyalarını kopyala
if exist build\web\ (
    echo   Web dosyaları kopyalanıyor...
    xcopy build\web ..\BuildedREADY\web /e /i /y > nul
    echo   ✓ Web dosyaları başarıyla kopyalandı
) else (
    echo   ✗ Web dosyaları bulunamadı!
    pause
    exit /b 1
)

cd ..

echo [6/7] README.txt oluşturuluyor...
(
    echo Edebi Çengel - Derlenmiş Sürümler
    echo ==================================
    echo Sürüm: %BUILD_NAME%+%BUILD_NUMBER%
    echo.
    echo apk/
    echo   - EdebiCengelAndroid.apk: Android uygulaması (telefonlara yüklenebilir^)
    echo.
    echo windows/
    echo   - EdebiCengel_Bulmaca_Windows.zip: Windows masaüstü uygulaması ZIP paketi
    echo   - Zip dosyasını açtıktan sonra EdebiCengel.exe dosyasını çalıştırın
    echo.
    echo web/
    echo   - Tarayıcıda çalıştırılacak web versiyonu (tüm dosyalar bu klasörde^)
    echo   - index.html dosyasını tarayıcıda açmak için çift-tıklayın
    echo.
) > BuildedREADY\README.txt

echo   ✓ README.txt oluşturuldu

echo.
echo [7/7] İşlem tamamlandı!
echo.
echo ╔════════════════════════════════════════════╗
echo ║  ✓ Tüm versiyonlar başarıyla derlendi!     ║
echo ║  Sürüm: %BUILD_NAME%+%BUILD_NUMBER%
echo ║                                            ║
echo ║  BuildedREADY klasörü içinde bulunur:     ║
echo ║  - apk/                                    ║
echo ║    EdebiCengelAndroid.apk                  ║
echo ║                                            ║
echo ║  - windows/                                ║
echo ║    EdebiCengel_Bulmaca_Windows.zip         ║
echo ║    (Zip'i açınca EdebiCengel.exe'yi        ║
echo ║     çalıştırabilirsiniz)                   ║
echo ║                                            ║
echo ║  - web/                                    ║
echo ║    (Tüm web dosyaları, index.html çift    ║
echo ║     tıkla ile açabilirsiniz)               ║
echo ╚════════════════════════════════════════════╝
echo.

pause
