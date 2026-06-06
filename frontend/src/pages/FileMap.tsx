import React, { useEffect, useState } from \"react\";

type FileEntry = { Name: string; Path: string; Size: number; Modified: string };

const PAGE_SIZE = 25;

const Toast: React.FC<{ message: string | null }> = ({ message }) => {
  if (!message) return null;
  return (
    <div style={{
      position: \"fixed\", right: 20, bottom: 20, background: \"#111\", color: \"#fff\",
      padding: \"10px 14px\", borderRadius: 8, boxShadow: \"0 6px 18px rgba(0,0,0,0.4)\", zIndex: 9999
    }}>
      {message}
    </div>
  );
};

const FileMap: React.FC = () => {
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState(\"\");

  const fetchMap = async () => {
    try {
      const r = await fetch(\"/api/filemap\");
      if (!r.ok) { setFiles([]); return; }
      const data = await r.json();
      setFiles(Array.isArray(data) ? data : []);
      setPage(1);
    } catch {
      setFiles([]);
    }
  };

  useEffect(() => { fetchMap(); }, []);

  const runAction = async (endpoint: string, successMsg: string) => {
    setLoading(true);
    setToast(\"Wykonywanie...\");
    try {
      const r = await fetch(/api/run/, { method: \"POST\" });
      const json = await r.json();
      if (r.ok) {
        setToast(successMsg);
        await fetchMap();
      } else {
        setToast(Błąd: );
      }
    } catch (e) {
      setToast(Błąd: );
    } finally {
      setLoading(false);
      setTimeout(() => setToast(null), 6000);
    }
  };

  const fetchReport = async () => {
    try {
      const r = await fetch(\"/api/report/path_healer\");
      if (!r.ok) { setToast(\"Brak raportu\"); return; }
      const txt = await r.text();
      const blob = new Blob([txt], { type: \"text/plain\" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement(\"a\");
      a.href = url;
      a.download = \"GRAZYNA_PATH_HEALER_REPORT.txt\";
      a.click();
      URL.revokeObjectURL(url);
      setToast(\"Raport pobrany\");
      setTimeout(() => setToast(null), 4000);
    } catch (e) {
      setToast(Błąd pobierania raportu: );
      setTimeout(() => setToast(null), 6000);
    }
  };

  const filtered = files.filter(f => !filter || f.Name.toLowerCase().includes(filter.toLowerCase()) || f.Path.toLowerCase().includes(filter.toLowerCase()));
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageFiles = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  return (
    <div>
      <h1>Mapa Plików</h1>

      <div style={{ marginBottom: 12, display: \"flex\", gap: 8, alignItems: \"center\" }}>
        <button onClick={() => runAction(\"scan\", \"Skanowanie zakończone\")} disabled={loading}>Skanuj pliki</button>
        <button onClick={() => runAction(\"fixpaths\", \"Naprawa ścieżek zakończona\")} disabled={loading}>Napraw ścieżki</button>
        <button onClick={fetchReport} disabled={loading}>Pobierz raport</button>

        <input
          placeholder=\"Filtruj po nazwie lub ścieżce...\"
          value={filter}
          onChange={(e) => { setFilter(e.target.value); setPage(1); }}
          style={{ marginLeft: 12, padding: 6, flex: 1 }}
        />
      </div>

      <div style={{ marginBottom: 8 }}>
        <strong>Wyników:</strong> {filtered.length} • <strong>Strona:</strong> {page}/{totalPages}
      </div>

      <table style={{ width: \"100%\", borderCollapse: \"collapse\" }}>
        <thead>
          <tr>
            <th style={{ textAlign: \"left\", padding: 6 }}>Nazwa</th>
            <th style={{ textAlign: \"left\", padding: 6 }}>Ścieżka</th>
            <th style={{ textAlign: \"right\", padding: 6 }}>Rozmiar</th>
            <th style={{ textAlign: \"left\", padding: 6 }}>Modyfikacja</th>
          </tr>
        </thead>
        <tbody>
          {pageFiles.map((f, i) => (
            <tr key={i}>
              <td style={{ padding: 6 }}>{f.Name}</td>
              <td style={{ padding: 6, fontFamily: \"monospace\", fontSize: 12 }}>{f.Path}</td>
              <td style={{ padding: 6, textAlign: \"right\" }}>{f.Size}</td>
              <td style={{ padding: 6 }}>{f.Modified}</td>
            </tr>
          ))}
          {pageFiles.length === 0 && (
            <tr>
              <td colSpan={4} style={{ padding: 12 }}>Brak danych na tej stronie.</td>
            </tr>
          )}
        </tbody>
      </table>

      <div style={{ marginTop: 12, display: \"flex\", gap: 8, alignItems: \"center\" }}>
        <button onClick={() => setPage(1)} disabled={page === 1}>« Pierwsza</button>
        <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>‹ Poprzednia</button>
        <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}>Następna ›</button>
        <button onClick={() => setPage(totalPages)} disabled={page === totalPages}>Ostatnia »</button>
        <div style={{ marginLeft: 12 }}>
          Przejdź do strony:
          <input type=\"number\" min={1} max={totalPages} value={page} onChange={(e) => {
            const v = Number(e.target.value) || 1;
            setPage(Math.min(Math.max(1, v), totalPages));
          }} style={{ width: 70, marginLeft: 8 }} />
        </div>
      </div>

      <Toast message={toast} />
    </div>
  );
};

export default FileMap;
