import { Router } from "express";
import { ECUService, IMMAOService } from "../services/ecu_immo_services.js";
import { authenticateToken } from "../middleware/auth.js";
import { blockWritesInReadOnly, policyMiddleware, requireMFA } from "../middleware/policy_and_audit.js";

const router = Router();
const ecu = new ECUService();
const immo = new IMMAOService();

router.use(authenticateToken);
router.use(policyMiddleware());
router.use(blockWritesInReadOnly());

router.get("/hardware/status", async (_req, res) => {
  res.json(await ecu.hardwareStatus());
});

router.get("/ecu/vin", async (_req, res) => {
  res.json(await ecu.readVIN());
});

router.get("/ecu/full", async (_req, res) => {
  res.json(await ecu.readECUFull());
});

router.get("/immo/status", async (_req, res) => {
  res.json(await ecu.readIMMOStatus());
});

router.post("/immo/reset/plan", async (req, res) => {
  res.json(immo.planIMMOReset(String(req.body?.vehicleId ?? "")));
});

router.post("/immo/reset/execute", requireMFA(), async (req, res) => {
  const result = await immo.executeIMMOReset(
    {
      userId: req.user?.id,
      role: req.user?.role,
      mfaVerified: req.headers["x-grazyna-mfa"] === "verified",
      managerApproved: req.headers["x-grazyna-manager"] === "approved",
      hardwareVerified: req.headers["x-grazyna-hardware"] === "verified",
      checksumVerified: req.headers["x-grazyna-checksum"] === "verified",
    },
    String(req.body?.vehicleId ?? ""),
  );
  res.status(result.ok ? 200 : 403).json(result);
});

export default router;
