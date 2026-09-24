# GRAŻYNA 5.0 — Controlled Update Console

## Cel
Jedna konsola ma pokazywać rzeczywisty stan procesów i prowadzić aktualizację w kontrolowanym cyklu:

1. INVENTORY — tylko odczyt.
2. PLAN — generowanie planu i plan_id.
3. APPLY — jawne potwierdzenie GRAZYNA-APPLY i wykonanie wyłącznie pozycji z planu.
4. HEALTH — weryfikacja backendu po instalacji.
5. LOG — zapis przebiegu do logs/updates.

## Zakres aktualnego kontrolera
- backend: npm ci --ignore-scripts z lokalnego package-lock.json
- frontend: npm ci --ignore-scripts z lokalnego package-lock.json

## Izolacja ROOT
Kontroler nie używa już stałej ścieżki repozytorium. Domyślnie wyznacza ROOT na podstawie lokalizacji skryptu: dwa poziomy nad runtime/update. Można jawnie podać `-Root`, co jest wymagane w testach izolowanego worktree, aby INVENTORY/PLAN/APPLY nie dotknęły głównego drzewa.

## Poza automatycznym APPLY
- ECU / FLASH
- MPPS i procesy Python
- sterowniki USB/KTAG
- git pull / merge
- pobieranie modeli Ollama
- zatrzymywanie procesów

## API lokalne
- GET /api/system/update/inventory
- POST /api/system/update/plan
- POST /api/system/update/apply

Backend nasłuchuje na 127.0.0.1. API wymaga `confirm=GRAZYNA-APPLY` oraz aktualnego `plan_id`; backend przekazuje zweryfikowane potwierdzenie do kontrolera PowerShell, który również wymaga go przy bezpośrednim APPLY.

## Zasada bezpieczeństwa
Kontroler nie jest narzędziem ECU. Aktualizacje zależności aplikacji są oddzielone od diagnostyki i zapisu ECU. INVENTORY i PLAN są bezpieczne tylko wtedy, gdy ROOT wskazuje właściwe drzewo. APPLY nie może być wykonywany na planie utworzonym dla innego ROOT.

## Stan
Implementacja przygotowana na osobnej gałęzi. Przed scaleniem wymagany lokalny test: syntax PowerShell, TypeScript compile/load, INVENTORY, PLAN, brak zmian po INVENTORY/PLAN, kontrolowany APPLY na zależnościach, /health HTTP 200 oraz test procesów MPPS bez zatrzymywania. Należy osobno potwierdzić, że test worktree nie zapisuje do głównego ROOT.
