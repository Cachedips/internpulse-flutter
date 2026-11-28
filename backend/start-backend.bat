@echo off
title InternPulse Backend Server
cd /d "%~dp0"

set "PHP_BIN=C:\winnmp\bin\PHP\64bit-php-8.2\php.exe"

echo ===================================================
echo [InternPulse] Memulai Backend Server (PHP 8.2.6)...
echo ===================================================

:: Periksa apakah MariaDB WinNMP aktif di port 3307
netstat -ano | findstr 3307 >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [InternPulse] Memulai database MariaDB WinNMP di background...
    start "" /b "C:\winnmp\bin\mariadb\bin\mysqld.exe" --defaults-file="C:\winnmp\conf\mysql.ini"
    timeout /t 3 /nobreak >nul
)

echo [InternPulse] Menjalankan Database Seeder (CustomJobSeeder)...
"%PHP_BIN%" -d disable_functions="" artisan db:seed --class=CustomJobSeeder --force

echo [InternPulse] Menjalankan server Laravel di http://127.0.0.1:8000 ...
"%PHP_BIN%" -d disable_functions="" artisan serve --host=127.0.0.1 --port=8000

pause
