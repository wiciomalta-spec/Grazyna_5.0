import os
import psutil
from pathlib import Path
from flask import Flask, render_template_string

ROOT = Path(r"E:\Grazyna_5.0")
LOG_FILE = ROOT / "logs" / "system.log"

app = Flask(__name__)

TEMPLATE = r"""
<!doctype html>
<html lang="pl">
<head>
  <meta charset="utf-8">
  <title>GRAZYNA 5.0 – Panel Webowy PRO</title>
  <style>
    body { font-family: Consolas, monospace; background: #111; color: #eee; }
    h1 { color: #0ff; }
    h2 { color: #ff0; }
    pre { background: #000; padding: 10px; border-radius: 4px; max-height: 300px; overflow: auto; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #444; padding: 4px; font-size: 12px; }
    th { background: #222; }
    .ok { color: #0f0; }
    .warn { color: #ff0; }
    .err { color: #f00; }
  </style>
  <meta http-equiv="refresh" content="2">
</head>
<body>
  <h1>GRAZYNA 5.0 – Panel Webowy PRO</h1>

  <h2>Ostatnie logi</h2>
  {% if logs %}
    <pre>{{ logs }}</pre>
  {% else %}
    <p class="warn">Brak logów.</p>
  {% endif %}

  <h2>Procesy powiązane (python / pwsh / gra)</h2>
  <table>
    <tr><th>Nazwa</th><th>PID</th><th>CPU %</th><th>RAM MB</th></tr>
    {% for p in processes %}
      <tr>
        <td>{{ p.name }}</td>
        <td>{{ p.pid }}</td>
        <td>{{ "%.1f"|format(p.cpu) }}</td>
        <td>{{ "%.1f"|format(p.ram) }}</td>
      </tr>
    {% endfor %}
  </table>

  <h2>Ostatnie zmiany plików</h2>
  <table>
    <tr><th>Plik</th><th>Czas modyfikacji</th></tr>
    {% for f in files %}
      <tr>
        <td>{{ f.path }}</td>
        <td>{{ f.time }}</td>
      </tr>
    {% endfor %}
  </table>

  <h2>Użycie dysku (E:)</h2>
  {% if disk %}
    <pre>
Użyte: {{ disk.used_gb }} GB
Wolne: {{ disk.free_gb }} GB
Procent: {{ "%.1f"|format(disk.percent) }} %
    </pre>
  {% else %}
    <p class="err">Brak informacji o dysku E:</p>
  {% endif %}

</body>
</html>
"""

def get_logs():
    if not LOG_FILE.exists():
        return ""
    try:
        lines = LOG_FILE.read_text(encoding="utf-8", errors="ignore").splitlines()
        return "\n".join(lines[-100:])
    except Exception:
        return ""

def get_processes():
    procs = []
    for p in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
        name = (p.info.get("name") or "").lower()
        if any(x in name for x in ["python", "pwsh", "gra"]):
            try:
                procs.append({
                    "name": p.info["name"],
                    "pid": p.info["pid"],
                    "cpu": p.info["cpu_percent"],
                    "ram": p.info["memory_info"].rss / (1024 * 1024),
                })
            except Exception:
                continue
    return procs

def get_files():
    files = []
    if not ROOT.exists():
        return files
    try:
        for p in ROOT.rglob("*"):
            if p.is_file():
                files.append((str(p), p.stat().st_mtime))
    except Exception:
        pass
    files = sorted(files, key=lambda x: x[1], reverse=True)[:20]
    import datetime
    out = []
    for path, ts in files:
        out.append({
            "path": path,
            "time": datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S"),
        })
    return out

def get_disk():
    try:
        usage = psutil.disk_usage("E:\\")
        return {
            "used_gb": usage.used / (1024**3),
            "free_gb": usage.free / (1024**3),
            "percent": usage.percent,
        }
    except Exception:
        return None

@app.route("/")
def index():
    return render_template_string(
        TEMPLATE,
        logs=get_logs(),
        processes=get_processes(),
        files=get_files(),
        disk=get_disk(),
    )

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)