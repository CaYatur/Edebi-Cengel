@echo off
chcp 65001 > nul
echo.
echo ================================================
echo      Edebi Çengel - Sunucular Başlatılıyor
echo ================================================
echo.
echo [1] API Sunucusu başlatılıyor: http://localhost:3000
echo [2] Web Sunucusu başlatılıyor: http://localhost:9999
echo.
echo Sunucuları durdurmak için: Ctrl + C
echo.
pause

:: API Sunucusu başlat (arka planda)
start "Edebi Çengel API" cmd /c "cd /d "%~dp0server" && node server.js"

:: Web sunucusu başlat
cd /d "%~dp0cengel_bulmaca\build\web"
python -m http.server 9999

pause
