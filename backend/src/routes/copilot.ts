import { Router } from "express";
import { authenticateToken } from "../middleware/auth.js";
import { policyMiddleware } from "../middleware/policy_and_audit.js";
import { ECUService, IMMAOService } from "../services/ecu_immo_services.js";

function classify(message: string) {
  const text = message.toLowerCase();
  if (/vin/.test(text) && /(read|show|get|odczyt|pokaż|sprawdź)/.test(text)) return "READ_VIN";
  if (/(ecu|sterownik).*(full|pełn|read|odczyt)/.test(text)) return "READ_ECU_FULL";
  if (/(immo|immobiliz).*(status|stan|read|odczyt)/.test(text)) return "READ_IMMO_STATUS";
  if (/(plan|zaplan).*(immo|immobiliz|reset)/.test(text)) return "PLAN_IMMO_RESET";
  if (/(execute|wykon|reset).*(immo|immobiliz)/.test(text)) return "EXECUTE_IMMO_RESET";
  return "UNKNOWN";
}

const router = Router();
router.use(authenticateToken);
router.use(policyMiddleware());

router.post("/copilot/chat", async (req, res) => {
  const message = String(req.body?.message ?? "");
  const intent = classify(message);
  const ecu = new ECUService();
  const immo = new IMMAOService();

  if (intent === "READ_VIN") return res.json({ ok: true, intent, result: await ecu.readVIN() });
  if (intent === "READ_ECU_FULL") return res.json({ ok: true, intent, result: await ecu.readECUFull() });
  if (intent === "READ_IMMO_STATUS") return res.json({ ok: true, intent, result: await ecu.readIMMOStatus() });
  if (intent === "PLAN_IMMO_RESET") return res.json({ ok: true, intent, result: immo.planIMMOReset() });
  if (intent === "EXECUTE_IMMO_RESET") {
    return res.status(403).json({
      ok: false,
      intent,
      status: "POLICY_REQUIRES_EXPLICIT_GATES",
      required: ["READ_ONLY=false", "MFA", "MANAGER_APPROVAL", "HARDWARE", "CHECKSUM"],
      writePerformed: false,
    });
  }
  return res.status(400).json({ ok: false, intent, status: "UNKNOWN_INTENT" });
});

export default router;
