import { Request, Response, NextFunction } from "express";

const BLOCKED_TERMS = /\b(flash|write|erase|program)\s+(ecu|eeprom|bin|immobilizer|immo)\b/i;

export function policyMiddleware() {
  return (req: Request, res: Response, next: NextFunction): void => {
    const operation = String(req.headers["x-grazyna-operation"] ?? "");
    const body = JSON.stringify(req.body ?? {});
    const target = operation + " " + body;

    if (BLOCKED_TERMS.test(target)) {
      res.status(403).json({
        ok: false,
        status: "POLICY_BLOCK",
        reason: "Operation blocked by GRAŻYNA safety policy",
        writePerformed: false,
      });
      return;
    }
    next();
  };
}

export function blockWritesInReadOnly() {
  return (req: Request, res: Response, next: NextFunction): void => {
    const readOnly = process.env.GRAZYNA_READ_ONLY !== "false";
    const method = req.method.toUpperCase();
    const writeLike = /^(POST|PUT|PATCH|DELETE)$/.test(method) && /execute|write|flash|erase|program/i.test(req.path);

    if (readOnly && writeLike) {
      res.status(403).json({
        ok: false,
        status: "READ_ONLY_BLOCK",
        reason: "READ_ONLY mode blocks write/execute operations",
        writePerformed: false,
      });
      return;
    }
    next();
  };
}

export function requireMFA() {
  return (req: Request, res: Response, next: NextFunction): void => {
    const verified = req.headers["x-grazyna-mfa"] === "verified";
    if (!verified) {
      res.status(403).json({ ok: false, status: "MFA_REQUIRED", writePerformed: false });
      return;
    }
    next();
  };
}

export function auditMiddleware() {
  return (req: Request, res: Response, next: NextFunction): void => {
    const started = Date.now();
    res.on("finish", () => {
      const record = {
        timestamp: new Date().toISOString(),
        method: req.method,
        path: req.path,
        status: res.statusCode,
        durationMs: Date.now() - started,
        requestId: req.headers["x-request-id"] ?? null,
      };
      console.log("[GRAZYNA_AUDIT]", JSON.stringify(record));
    });
    next();
  };
}
