@echo off
title PianoKustik Windows Build Tool
echo ========================================================
echo       PianoKustik - Windows Release Build Tool
echo ========================================================
echo.

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter SDK tidak ditemukan di PATH!
    echo Pastikan Flutter SDK sudah terpasang di Windows dan terdaftar di Environment Variables (PATH).
    echo.
    pause
    exit /b 1
)

echo [1/3] Memeriksa dependencies (flutter pub get)...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Gagal menjalankan flutter pub get!
    pause
    exit /b 1
)

echo.
echo [2/3] Meng-compile PianoKustik ke Windows Executable (Release Mode)...
echo Proses ini membutuhkan waktu beberapa menit...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build Windows gagal!
    echo Pastikan Visual Studio (2019/2022) dengan workload "Desktop development with C++" sudah terpasang.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo [3/3] BUILD SUKSES!
echo File EXE: build\windows\x64\runner\Release\PianoKustik.exe
echo ========================================================
echo.
echo Membuka folder output di Windows Explorer...
explorer build\windows\x64\runner\Release

pause
