@echo off
cd /d D:\Projects\internpulse-backend
C:\winnmp\bin\PHP\64bit-php-8.2\php.exe -d disable_functions="" artisan serve --host=127.0.0.1 --port=8000
pause
