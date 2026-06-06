#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GRAŻYNA 5.0 Enterprise — Agent Sync Check
Wersja: 7.0.0 sync (naprawiona)
Naprawione błędy:
  - Exception zamiast exception (Python case-sensitive)
  - socket.AF_INET zamiast socket.af_inet
  - psutil.NoSuchProcess zamiast psutil.nosuchprocess
  - Dodano obsługę encoding UTF-8
"""

import os
import sys
import json
import time
import socket
import urllib.request
import urllib.error
from datetime import datetime

# Opcjonalne importy
try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False
    print("⚠️  psutil niedostępny — pomijam sprawdzanie procesów")

class GrazynaAgentSyncCheck:
    """Sprawdzanie synchronizacji z agentem GRAŻYNA"""

    def __init__(self):
        self.version = "7.0.0 sync"
        self.start_time = time.time()

        self.check_config = {
            'agent_endpoints': [
                'http://localhost:3001',        # Backend Express (główny)
                'http://localhost:3001/health', # Health check
                'http://localhost:3001/api',    # API root
                'http://localhost:5173',        # Frontend Vite
                'http://localhost:5174',        # Frontend Vite (alt)
                'http://localhost:5000',
                'http://localhost:5001',
            ],
            'target_ports': {
                3001: "Backend Express",
                5173: "Frontend Vite",
                5174: "Frontend Vite (alt)",
                6379: "Redis",
                5432: "PostgreSQL",
                4001: "Cluster Control",
                1883: "MQTT Broker",
                8080: "HTTP Alt",
            },
            'system_locations': [
                r'E:\Grazyna_5.0',
                r'C:\Grazyna_5.0',
                r'C:\grazyna_unified_system',
                r'C:\grazyna_5.0_enterprise',
            ],
            'config_files': [
                'backend/.env',
                'backend/package.json',
                'frontend/package.json',
                'docker-compose.yml',
            ]
        }

        self.sync_results = {
            'agent_status': {},
            'system_status': {},
            'process_status': {},
            'network_status': {},
            'file_status': {},
            'overall_health': 'unknown',
            'issues': [],
            'recommendations': []
        }

        print("""
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🔍 GRAŻYNA 5.0 Enterprise — Agent Sync Check 🔍         ║
║                                                              ║
║    Wersja: 7.0.0 sync (naprawiona)                          ║
║    Sprawdzanie synchronizacji z agentem                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
""")

    def check_port(self, port, timeout=1):
        """Sprawdza czy port jest otwarty"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # FIX: AF_INET nie af_inet
            sock.settimeout(timeout)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            return result == 0
        except Exception:  # FIX: Exception nie exception
            return False

    def check_http(self, url, timeout=5):
        """Sprawdza endpoint HTTP"""
        try:
            req = urllib.request.Request(
                url,
                headers={
                    'User-Agent': 'GRAZYNA-SyncCheck/7.0',
                    'Accept': 'application/json, text/plain, */*'
                }
            )
            with urllib.request.urlopen(req, timeout=timeout) as response:
                body = response.read(1000).decode('utf-8', errors='replace')  # FIX: encoding
                return response.status, body
        except urllib.error.HTTPError as e:
            return e.code, str(e)
        except Exception as e:  # FIX: Exception nie exception
            return None, str(e)

    def run_full_check(self):
        """Uruchamia pełne sprawdzenie synchronizacji"""
        print("🔍 Rozpoczynanie pełnego sprawdzenia synchronizacji...")
        print("=" * 70)

        try:
            self.check_network_ports()
            self.check_agent_endpoints()
            if HAS_PSUTIL:
                self.check_system_processes()
            self.check_system_locations()
            self.check_config_files()
            self.analyze_results()
            self.generate_report()

            print("\n" + "=" * 70)
            print("✅ Sprawdzenie synchronizacji zakończone!")

        except Exception as e:  # FIX: Exception nie exception
            print(f"❌ Błąd podczas sprawdzania: {e}")
            self.sync_results['overall_health'] = 'error'

        return self.sync_results

    def check_network_ports(self):
        """Sprawdza porty sieciowe"""
        print("\n🌐 KROK 1: Sprawdzanie portów sieciowych...")

        active_ports = []
        for port, name in self.check_config['target_ports'].items():
            is_open = self.check_port(port)
            if is_open:
                active_ports.append(port)
                self.sync_results['network_status'][port] = {'status': 'open', 'name': name}
                print(f"   ✅ OTWARTY  :{port} — {name}")
            else:
                self.sync_results['network_status'][port] = {'status': 'closed', 'name': name}
                print(f"   ⚪ zamknięty :{port} — {name}")

        total = len(self.check_config['target_ports'])
        print(f"\n   📊 Aktywne porty: {len(active_ports)}/{total}")

        # Sprawdź krytyczne porty
        if 3001 not in active_ports:
            self.sync_results['issues'].append("Backend :3001 niedostępny")
            self.sync_results['recommendations'].append(
                "Uruchom backend: cd /e/Grazyna_5.0/backend && "
                "node --max-old-space-size=512 --expose-gc "
                "node_modules/tsx/dist/cli.mjs src/express-server.ts &"
            )
        if 6379 not in active_ports:
            self.sync_results['issues'].append("Redis :6379 niedostępny")
            self.sync_results['recommendations'].append(
                "Uruchom Redis: docker-compose up -d redis"
            )

    def check_agent_endpoints(self):
        """Sprawdza dostępność endpointów agenta"""
        print("\n🔌 KROK 2: Sprawdzanie endpointów agenta...")

        endpoints_to_check = [
            ('http://localhost:3001/health',          'Backend /health'),
            ('http://localhost:3001/api',             'Backend /api'),
            ('http://localhost:3001/api/system/ping', 'Backend /ping'),
            ('http://localhost:3001/metrics',         'Prometheus metrics'),
            ('http://localhost:5173',                 'Frontend Vite :5173'),
            ('http://localhost:5174',                 'Frontend Vite :5174'),
        ]

        active_count = 0
        for url, name in endpoints_to_check:
            status_code, body = self.check_http(url)
            if status_code and status_code < 500:
                active_count += 1
                preview = body[:60].replace('\n', ' ') if body else ''
                print(f"   ✅ HTTP {status_code} — {name}")
                if preview:
                    print(f"      → {preview}")
                self.sync_results['agent_status'][url] = {
                    'status': 'active',
                    'code': status_code,
                    'preview': preview
                }
            else:
                err = body[:50] if body else 'brak odpowiedzi'
                print(f"   ❌ OFFLINE — {name}")
                print(f"      → {err}")
                self.sync_results['agent_status'][url] = {
                    'status': 'offline',
                    'error': err
                }

        print(f"\n   📊 Aktywne endpointy: {active_count}/{len(endpoints_to_check)}")

    def check_system_processes(self):
        """Sprawdza procesy systemowe GRAŻYNA"""
        print("\n⚙️  KROK 3: Sprawdzanie procesów systemowych...")

        grazyna_procs = []
        node_procs = []

        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent', 'memory_info']):
            try:
                info = proc.info
                name = (info['name'] or '').lower()
                cmdline = ' '.join(info['cmdline'] or []).lower()

                if 'grazyna' in name or 'grazyna' in cmdline:
                    grazyna_procs.append({
                        'pid': info['pid'],
                        'name': info['name'],
                        'cpu': info['cpu_percent'],
                        'ram_mb': round(info['memory_info'].rss / 1024 / 1024, 1) if info['memory_info'] else 0
                    })

                if name in ('node.exe', 'node') and ('grazyna' in cmdline or 'express' in cmdline or 'vite' in cmdline):
                    node_procs.append({
                        'pid': info['pid'],
                        'name': info['name'],
                        'cmdline': cmdline[-80:],
                        'cpu': info['cpu_percent'],
                        'ram_mb': round(info['memory_info'].rss / 1024 / 1024, 1) if info['memory_info'] else 0
                    })

            except (psutil.NoSuchProcess, psutil.AccessDenied):  # FIX: poprawna kapitalizacja
                continue

        self.sync_results['process_status'] = {
            'grazyna_processes': grazyna_procs,
            'node_processes': node_procs,
        }

        print(f"   🔍 Procesy GRAŻYNA: {len(grazyna_procs)}")
        for p in grazyna_procs:
            print(f"      ✅ PID {p['pid']}: {p['name']} (CPU: {p['cpu']:.1f}%, RAM: {p['ram_mb']}MB)")

        print(f"   ⬡  Procesy Node.js: {len(node_procs)}")
        for p in node_procs:
            print(f"      ✅ PID {p['pid']}: {p['name']} (CPU: {p['cpu']:.1f}%, RAM: {p['ram_mb']}MB)")
            print(f"         → {p['cmdline'][-60:]}")

        if not grazyna_procs and not node_procs:
            print("   ⚠️  Brak aktywnych procesów GRAŻYNA/Node.js")

    def check_system_locations(self):
        """Sprawdza lokalizacje systemu"""
        print("\n📁 KROK 4: Sprawdzanie lokalizacji systemu...")

        for location in self.check_config['system_locations']:
            exists = os.path.exists(location)
            status = "✅ ZNALEZIONY" if exists else "⚪ nie istnieje"
            print(f"   {status}: {location}")
            if exists:
                self.sync_results['system_status'][location] = 'found'
                # Sprawdź zawartość
                try:
                    items = os.listdir(location)
                    key_items = [i for i in items if i in ('backend', 'frontend', 'package.json', '.env')]
                    if key_items:
                        print(f"      → Kluczowe pliki: {', '.join(key_items)}")
                except Exception:
                    pass
            else:
                self.sync_results['system_status'][location] = 'not_found'

    def check_config_files(self):
        """Sprawdza pliki konfiguracyjne"""
        print("\n📋 KROK 5: Sprawdzanie plików konfiguracyjnych...")

        # Znajdź główny katalog projektu
        base_dirs = [loc for loc in self.check_config['system_locations'] if os.path.exists(loc)]

        if not base_dirs:
            print("   ⚠️  Nie znaleziono katalogu projektu")
            return

        base = base_dirs[0]
        print(f"   📂 Katalog projektu: {base}")

        for cfg_file in self.check_config['config_files']:
            full_path = os.path.join(base, cfg_file)
            exists = os.path.exists(full_path)
            size = os.path.getsize(full_path) if exists else 0
            status = f"✅ {size}B" if exists else "❌ brak"
            print(f"   {status} — {cfg_file}")
            self.sync_results['file_status'][cfg_file] = {
                'exists': exists,
                'size': size,
                'path': full_path
            }

    def analyze_results(self):
        """Analizuje wyniki i określa ogólny stan"""
        print("\n📊 KROK 6: Analiza wyników...")

        backend_ok  = self.sync_results['network_status'].get(3001, {}).get('status') == 'open'
        frontend_ok = (self.sync_results['network_status'].get(5173, {}).get('status') == 'open' or
                      self.sync_results['network_status'].get(5174, {}).get('status') == 'open')
        redis_ok    = self.sync_results['network_status'].get(6379, {}).get('status') == 'open'

        if backend_ok and frontend_ok:
            self.sync_results['overall_health'] = 'healthy'
            print("   ✅ System ZDROWY — Backend + Frontend aktywne")
        elif backend_ok:
            self.sync_results['overall_health'] = 'degraded'
            print("   ⚠️  System ZDEGRADOWANY — Backend OK, Frontend niedostępny")
        elif frontend_ok:
            self.sync_results['overall_health'] = 'degraded'
            print("   ⚠️  System ZDEGRADOWANY — Frontend OK, Backend niedostępny")
        else:
            self.sync_results['overall_health'] = 'critical'
            print("   🔴 System KRYTYCZNY — Backend i Frontend niedostępne")

        if not redis_ok:
            print("   ⚠️  Redis niedostępny — niektóre funkcje mogą nie działać")

    def generate_report(self):
        """Generuje raport końcowy"""
        elapsed = round(time.time() - self.start_time, 2)
        active_ports = sum(1 for s in self.sync_results['network_status'].values() if s['status'] == 'open')
        active_eps   = sum(1 for s in self.sync_results['agent_status'].values() if s['status'] == 'active')

        print(f"""
📋 RAPORT KOŃCOWY:
   Status ogólny:      {self.sync_results['overall_health'].upper()}
   Aktywne porty:      {active_ports}/{len(self.sync_results['network_status'])}
   Aktywne endpointy:  {active_eps}/{len(self.sync_results['agent_status'])}
   Czas sprawdzania:   {elapsed}s
   Timestamp:          {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}""")

        if self.sync_results['issues']:
            print("\n   ⚠️  Problemy:")
            for issue in self.sync_results['issues']:
                print(f"      • {issue}")

        if self.sync_results['recommendations']:
            print("\n   💡 Rekomendacje:")
            for rec in self.sync_results['recommendations']:
                print(f"      → {rec}")

        # Zapisz JSON
        report = {
            'timestamp': datetime.now().isoformat(),
            'version': self.version,
            'elapsed_s': elapsed,
            'results': self.sync_results,
        }

        # Spróbuj zapisać w katalogu projektu
        save_paths = [
            r'E:\Grazyna_5.0\logs\sync_report.json',
            '/e/Grazyna_5.0/logs/sync_report.json',
            '/tmp/grazyna_sync_report.json',
        ]
        for path in save_paths:
            try:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'w', encoding='utf-8') as f:
                    json.dump(report, f, indent=2, ensure_ascii=False)
                print(f"\n   💾 Raport zapisany: {path}")
                break
            except Exception:
                continue


if __name__ == '__main__':
    checker = GrazynaAgentSyncCheck()
    results = checker.run_full_check()
    # Exit code: 0=healthy, 1=degraded/critical
    sys.exit(0 if results['overall_health'] == 'healthy' else 1)