import test from "node:test";
import assert from "node:assert/strict";
import { IMMAOService, ECUService } from "../src/services/ecu_immo_services.js";

test("READ_VIN stays read-only when transport is disabled", async () => {
  delete process.env.GRAZYNA_MQTT_ENABLED;
  const result = await new ECUService().readVIN();
  assert.equal(result.writePerformed, undefined);
  assert.equal(result.status, "TRANSPORT_DISABLED");
});

test("IMMO reset planning never writes", () => {
  const result = new IMMAOService().planIMMOReset("test");
  assert.equal(result.ok, true);
  assert.equal(result.writePerformed, false);
  assert.equal(result.risk, "R4");
});

test("IMMO execute is blocked by READ_ONLY", async () => {
  process.env.GRAZYNA_READ_ONLY = "true";
  const result = await new IMMAOService().executeIMMOReset({
    mfaVerified: true,
    managerApproved: true,
    hardwareVerified: true,
    checksumVerified: true,
  });
  assert.equal(result.status, "POLICY_BLOCK");
  assert.equal(result.writePerformed, false);
});

test("IMMO execute requires MFA", async () => {
  process.env.GRAZYNA_READ_ONLY = "false";
  const result = await new IMMAOService().executeIMMOReset({});
  assert.equal(result.status, "MFA_REQUIRED");
});

test("IMMO execute requires manager approval", async () => {
  const result = await new IMMAOService().executeIMMOReset({ mfaVerified: true });
  assert.equal(result.status, "MANAGER_APPROVAL_REQUIRED");
});

test("IMMO execute requires hardware verification", async () => {
  const result = await new IMMAOService().executeIMMOReset({
    mfaVerified: true,
    managerApproved: true,
  });
  assert.equal(result.status, "HARDWARE_VERIFICATION_REQUIRED");
});

test("IMMO execute requires checksum verification", async () => {
  const result = await new IMMAOService().executeIMMOReset({
    mfaVerified: true,
    managerApproved: true,
    hardwareVerified: true,
  });
  assert.equal(result.status, "CHECKSUM_VERIFICATION_REQUIRED");
});

test("IMMO execute still refuses without connected hardware", async () => {
  const result = await new IMMAOService().executeIMMOReset({
    mfaVerified: true,
    managerApproved: true,
    hardwareVerified: true,
    checksumVerified: true,
  });
  assert.equal(result.status, "HARDWARE_NOT_CONNECTED");
  assert.equal(result.writePerformed, false);
});
