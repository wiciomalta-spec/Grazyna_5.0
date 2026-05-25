@echo off
:: =============================================
:: GRAŻYNA 5.0 - Skrypt uruchomieniowy
:: Uruchamia:
:: 1. Serwer WebSocket (port 7070)
:: 2. Interfejs Vite (port 5173)
:: =============================================

:: Sprawdź, czy jesteśmy w odpowiednim katalogu
cd /d "%~dp0"

:: Wyczyść ekran
cls

:: Sprawdź, czy node_modules istnieje, jeśli nie - zainstaluj zależności
if not exist "node_modules" (
    echo [GRAŻYNA] Instalowanie zależności (pnpm)...
    pnpm install --shamefully-hoist
    if errorlevel 1 (
        echo [BŁĄD] Nie udało się zainstalować zależności.
        pause
        exit /b 1
    )
)

:: Sprawdź, czy prisma/schema.prisma istnieje
if not exist "prisma\schema.prisma" (
    echo [BŁĄD] Brak pliku prisma\schema.prisma!
    echo Utwórz plik schema.prisma lub przywróć go z backupu.
    pause
    exit /b 1
)

:: Wygeneruj klienta Prisma (jeśli to konieczne)
echo [GRAŻYNA] Generowanie klienta Prisma...
npx prisma generate
if errorlevel 1 (
    echo [OSTRZEŻENIE] Prisma generate nie powiodło się, ale kontynuuję...
)

:: Uruchom serwer WebSocket (7070) w tle
echo [GRAŻYNA] Uruchamianie serwera WebSocket (port 7070)...
start "GRAŻYNA - WebSocket Server" cmd /k "pnpm start"

:: Poczekaj 2 sekundy, aby serwer WebSocket zdążył wystartować
timeout /t 2 >nul

:: Uruchom interfejs Vite (5173) w nowym oknie
echo [GRAŻYNA] Uruchamianie interfejsu Vite (port 5173)...
start "GRAŻYNA - Vite UI" cmd /k "pnpm dev"

:: Wyświetl informacje o uruchomionych serwerach
echo.
echo =============================================
echo [GRAŻYNA 5.0] Serwery uruchomione:
echo   - WebSocket: http://localhost:7070
echo   - Interfejs: http://localhost:5173
echo.
echo [LOGOWANIE]
echo   Admin:    admin@grazyna.local / admin123
echo   Operator: operator@grazyna.local / operator123
echo =============================================
echo.
echo [INFO] Możesz teraz zamknąć to okno.
pause