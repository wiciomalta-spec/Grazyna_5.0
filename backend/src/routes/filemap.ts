import { Router } from "express";
import { exec } from "child_process";
import path from "path";
import fs from "fs";

const router = Router();
const ROOT = "E:\\\\Grazyna_5.0";
const MAP_PATH = path.join(ROOT, "tools", "mapa", "filemap.json");
const SCAN_SCRIPT = path.join(ROOT, "tools", "mapa", "scan.ps1");
const FIX_SCRIPT = path.join(ROOT, "tools", "mapa", "fix_paths.ps1");
const PATH_HEALER_REPORT = path.join(ROOT, "GRAZYNA_PATH_HEALER_REPORT.txt");

function runPowerShell(scriptPath: string): Promise<{ ok: boolean; out: string; err: string }> {
  return new Promise((resolve) => {
    const cmd = powershell -NoProfile -ExecutionPolicy Bypass -File "";
    exec(cmd, { windowsHide: true, maxBuffer: 20 * 1024 * 1024 }, (error, stdout, stderr) => {
      resolve({ ok: !error, out: stdout || "", err: stderr || (error ? error.message : "") });
    });
  });
}

router.get("/filemap", (req, res) => {
  if (!fs.existsSync(MAP_PATH)) {
    return res.status(404).json({ error: "filemap not generated" });
  }
  try {
    const raw = fs.readFileSync(MAP_PATH, "utf8");
    return res.json(JSON.parse(raw));
  } catch (e) {
    return res.status(500).json({ error: "cannot read filemap", detail: String(e) });
  }
});

router.post("/run/scan", async (req, res) => {
  const result = await runPowerShell(SCAN_SCRIPT);
  if (!result.ok) return res.status(500).json({ ok: false, out: result.out, err: result.err });
  return res.json({ ok: true, out: result.out });
});

router.post("/run/fixpaths", async (req, res) => {
  const result = await runPowerShell(FIX_SCRIPT);
  if (!result.ok) return res.status(500).json({ ok: false, out: result.out, err: result.err });
  return res.json({ ok: true, out: result.out });
});

router.get("/report/path_healer", (req, res) => {
  if (!fs.existsSync(PATH_HEALER_REPORT)) {
    return res.status(404).json({ error: "report not found" });
  }
  try {
    const raw = fs.readFileSync(PATH_HEALER_REPORT, "utf8");
    return res.type("text/plain").send(raw);
  } catch (e) {
    return res.status(500).json({ error: "cannot read report", detail: String(e) });
  }
});

export default router;
