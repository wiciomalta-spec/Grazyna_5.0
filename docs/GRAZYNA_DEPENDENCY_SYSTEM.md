# GRAŻYNA — Autoadaptive Dependency & Catalog System

## Cel
Warstwa utrzymuje żywy katalog zależności na podstawie rzeczywistego drzewa projektu. System może sam wykrywać nowe manifesty, dokumentować ich stan i budować plan synchronizacji, ale nie wybiera sam nowych wersji ani nie instaluje nieznanych pakietów.

## Przepływ
INVENTORY → CATALOG → PLAN → CONTROLLED APPLY

## Źródła
- npm: package.json + package-lock.json
- Python: requirements.txt / pyproject.toml (wykrywanie i katalogowanie; bez automatycznej instalacji w V1)

## Kontrakty bezpieczeństwa
- ROOT jest jawny i izolowany.
- Katalog jest generowany z faktów z filesystemu.
- Zmiana wersji zależności i dodanie nowego pakietu wymagają osobnego planu.
- APPLY wymaga plan_id, zgodnego ROOT oraz `GRAZYNA-DEPENDENCY-APPLY`.
- Brak automatycznego ECU/FLASH, driverów, zatrzymywania MPPS, git pull/merge i pobierania modeli Ollama.
- `npm ci --ignore-scripts` jest jedyną akcją APPLY V1.

## Modernizacja V2 — przygotowanie
Katalog powinien docelowo otrzymywać: właściciela modułu, krytyczność, źródło, wersję runtime, zgodność Node/Python, lockfile status, checksum, datę ostatniej obserwacji, status zdrowia oraz zależności między modułami. Mechanizm autouzupełniania ma dopisywać tylko elementy wykryte, nie wymyślone.

## Test akceptacyjny
1. Inventory nie modyfikuje ROOT.
2. Catalog tworzy `runtime/dependencies/dependency_catalog.json`.
3. Plan tworzy `dependency_plan.json` i zawiera tylko wykryte akcje.
4. Apply odrzuca brak potwierdzenia, obcy ROOT i obcy plan_id.
5. Apply nie dotyka ECU/FLASH/MPPS.
