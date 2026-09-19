import mqtt, { MqttClient } from "mqtt";
import crypto from "node:crypto";
import type { CommandBusAdapter } from "./ecu_immo_services.js";

export class MqttCommandBusAdapter implements CommandBusAdapter {
  private client?: MqttClient;

  private async connect(): Promise<MqttClient> {
    if (this.client?.connected) return this.client;
    const url = process.env.GRAZYNA_MQTT_URL || "mqtt://127.0.0.1:1883";
    this.client = mqtt.connect(url, {
      username: process.env.GRAZYNA_MQTT_USERNAME,
      password: process.env.GRAZYNA_MQTT_PASSWORD,
      reconnectPeriod: 0,
      connectTimeout: 3000,
    });
    await new Promise<void>((resolve, reject) => {
      const c = this.client!;
      const timer = setTimeout(() => reject(new Error("MQTT_CONNECT_TIMEOUT")), 3500);
      c.once("connect", () => { clearTimeout(timer); resolve(); });
      c.once("error", (err) => { clearTimeout(timer); reject(err); });
    });
    return this.client;
  }

  async request(command: string, payload: Record<string, unknown>, timeoutMs = 5000) {
    const requestId = crypto.randomUUID();
    const commandTopic = process.env.GRAZYNA_MQTT_COMMAND_TOPIC || "grazyna/command";
    const responseTopic = process.env.GRAZYNA_MQTT_RESPONSE_TOPIC || "grazyna/response";

    try {
      const client = await this.connect();
      return await new Promise<Record<string, unknown>>((resolve) => {
        const timer = setTimeout(() => {
          client.unsubscribe(responseTopic);
          resolve({
            ok: false,
            status: "MQTT_TIMEOUT",
            requestId,
            command,
            writePerformed: false,
            reason: "No response received from MPPS backend within timeout",
          });
        }, timeoutMs);

        client.subscribe(responseTopic, { qos: 1 }, (subErr) => {
          if (subErr) {
            clearTimeout(timer);
            resolve({ ok: false, status: "MQTT_SUBSCRIBE_ERROR", requestId, writePerformed: false });
            return;
          }
          const onMessage = (topic: string, raw: Buffer) => {
            if (topic !== responseTopic) return;
            try {
              const msg = JSON.parse(raw.toString("utf8")) as Record<string, unknown>;
              if (msg.requestId !== requestId) return;
              clearTimeout(timer);
              client.off("message", onMessage);
              client.unsubscribe(responseTopic);
              resolve(msg);
            } catch {
              // Ignore malformed/unrelated messages.
            }
          };
          client.on("message", onMessage);
          client.publish(commandTopic, JSON.stringify({
            requestId,
            command,
            payload,
            timestamp: new Date().toISOString(),
            safety: { mode: "READ_ONLY", writeAllowed: false },
          }), { qos: 1 });
        });
      });
    } catch (error) {
      return {
        ok: false,
        status: "MQTT_CONNECT_ERROR",
        requestId,
        writePerformed: false,
        reason: error instanceof Error ? error.message : "MQTT connection failed",
      };
    }
  }

  async hardwareStatus() {
    try {
      const client = await this.connect();
      return { connected: client.connected, transport: "MQTT", device: "MPPS/KTAG", broker: process.env.GRAZYNA_MQTT_URL || "mqtt://127.0.0.1:1883" };
    } catch {
      return { connected: false, transport: "MQTT", device: "MPPS/KTAG" };
    }
  }
}
