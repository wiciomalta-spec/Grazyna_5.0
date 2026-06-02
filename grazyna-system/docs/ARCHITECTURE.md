# GRAŻYNA 5.0 — Hybrid Kernel Architecture

## Warstwy

1. **Adaptive Shell** — UI dopasowujący gęstość, animacje i intensywność renderowania.
2. **Capability Registry** — katalog aktywnych zdolności środowiska.
3. **Driver Fabric** — warstwa abstrakcji dla sterowników i narzędzi systemowych.
4. **Kernel Service** — profilowanie hosta, dobór trybu pracy i tuning runtime.
5. **Self-Healing State** — odzyskiwanie stanu po restartach i pracy offline.
6. **Transport Layer** — HTTP + WebSocket + fallback portable.

## Tryby rdzenia

- `minimal`
- `balanced`
- `turbo`
- `portable`
- `autonomous`

## Cel

Budowa lekkiego, samodzielnego i adaptacyjnego systemu, który potrafi działać lokalnie, sieciowo i w trybie degradacji bez utraty podstawowej logiki sterowania.
