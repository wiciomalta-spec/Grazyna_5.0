import crypto from "node:crypto";

export type RiskLevel = "R0" | "R1" | "R4" | "R5";

export interface CommandBusAdapter {
  request(command: string, payload: Record<string, unknown>, timeoutMs?: number): Promise<Record<string, unknown>>;
  hardwareStatus(): Promise<{ connected: boolean; transport: string; device?: string }>;
}

export class SafeCommandBusAdapter implements CommandBusAdapter {
  async request(command: string, payload: Record<string, unknown>, timeoutMs = 5000) {
    const enabled = process.env.GRAZYNA_MQTT_ENABLED === "true";
    if (!enabled) {
      return {
        ok: false,
        status: "TRANSPORT_DISABLED",
        command,
        payload,
        reason: "MQTT/ECU transport is disabled; READ_ONLY safety baseline remains active",
      };
    }
    return {
      ok: false,
      status: "TRANSPORT_NOT_IMPLEMENTED",
      command,
      payload,
      timeoutMs,
      reason: "MPPS runtime command adapter is not yet proven against a live ECU",
    };
  }

  async hardwareStatus() {
    return {
      connected: false,
      transport: "MPPS/KTAG",
      device: undefined,
    };
  }
}

export interface OperatorContext {
  userId?: string;
  role?: string;
  mfaVerified?: boolean;
  managerApproved?: boolean;
  hardwareVerified?: boolean;
  checksumVerified?: boolean;
}

export class ECUService {
  constructor(private readonly adapter: CommandBusAdapter = new SafeCommandBusAdapter()) {}

  async readVIN() {
    return this.adapter.request("ECU_READ_VIN", {}, 5000);
  }

  async readECUFull() {
    return this.adapter.request("ECU_READ_FULL", {}, 15000);
  }

  async readIMMOStatus() {
    return this.adapter.request("IMMO_READ_STATUS", {}, 5000);
  }

  async hardwareStatus() {
    return this.adapter.hardwareStatus();
  }
}

export class IMMAOService {
  constructor(private readonly adapter: CommandBusAdapter = new SafeCommandBusAdapter()) {}

  planIMMOReset(vehicleId?: string) {
    return {
      ok: true,
      operation: "PLAN_IMMO_RESET",
      risk: "R4" as RiskLevel,
      mode: "READ_ONLY",
      vehicleId: vehicleId ?? null,
      planId: crypto.randomUUID(),
      actions: [
        "identify vehicle/ECU",
        "read current immobilizer status",
        "verify security prerequisites",
        "prepare reset transaction",
        "require MFA and manager approval",
        "verify hardware and checksum before any execution",
      ],
      writePerformed: false,
    };
  }

  async executeIMMOReset(ctx: OperatorContext, vehicleId?: string) {
    const readOnly = process.env.GRAZYNA_READ_ONLY !== "false";
    if (readOnly) {
      return { ok: false, status: "POLICY_BLOCK", reason: "GRAZYNA_READ_ONLY is active", writePerformed: false };
    }
    if (!ctx.mfaVerified) return { ok: false, status: "MFA_REQUIRED", writePerformed: false };
    if (!ctx.managerApproved) return { ok: false, status: "MANAGER_APPROVAL_REQUIRED", writePerformed: false };
    if (!ctx.hardwareVerified) return { ok: false, status: "HARDWARE_VERIFICATION_REQUIRED", writePerformed: false };
    if (!ctx.checksumVerified) return { ok: false, status: "CHECKSUM_VERIFICATION_REQUIRED", writePerformed: false };

    const hardware = await this.adapter.hardwareStatus();
    if (!hardware.connected) {
      return { ok: false, status: "HARDWARE_NOT_CONNECTED", vehicleId: vehicleId ?? null, writePerformed: false };
    }

    return this.adapter.request("IMMO_RESET_EXECUTE", { vehicleId: vehicleId ?? null }, 15000);
  }
}
