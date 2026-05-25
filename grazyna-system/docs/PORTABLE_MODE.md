# Portable Mode

Tryb portable uruchamia system w możliwie lekkiej konfiguracji:
- instaluje zależności tylko jeśli ich brakuje,
- tworzy minimalny backend `.env`,
- startuje frontend i backend bez pełnego stacku produkcyjnego,
- utrzymuje zgodność z offline-first i fallback logic.

## Linux / macOS
```bash
chmod +x scripts/portable-start.sh
./scripts/portable-start.sh
```

## Windows
```powershell
./scripts/portable-start.ps1
```
