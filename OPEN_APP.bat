@echo off
chcp 65001 > nul
echo.
echo ================================================
echo      Edebi Çengel - Uygulamayı Açıyorum
echo ================================================
echo.
echo Not: Sunucu çalışıyor olmalıdır!
echo Sunucuyu başlatmadıysanız START_SERVER.bat'ı çalıştırın.
echo.
pause

timeout /t 2 /nobreak > nul

start http://localhost:9999

echo Tarayıcı açılıyor...
