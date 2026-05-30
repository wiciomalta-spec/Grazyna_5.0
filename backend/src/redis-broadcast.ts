import { createClient } from "redis";

const redisUrl = process.env.REDIS_URL || "redis://127.0.0.1:6379";
const broadcastChannel = "grazyna:broadcast";
const jobsKey = "grazyna:jobs";

let pub: any = null;
let sub: any = null;
let queueClient: any = null;
let started = false;
let queueStarted = false;
let emitter: ((event: string, payload: any) => void) | null = null;

async function safeConnect(kind: string) {
  try {
    const c = createClient({ url: redisUrl, socket: { reconnectStrategy: false } });
    c.on("error", () => {});
    await c.connect();
    return c;
  } catch {
    console.warn(`[redis] ${kind} unavailable — fallback mode`);
    return null;
  }
}

async function ensureClients() {
  if (!pub) pub = await safeConnect("pub");
  if (!sub) sub = await safeConnect("sub");
  if (!queueClient) queueClient = await safeConnect("queue");
}

export async function attachSocketBridge(ioLike: any) {
  emitter = (event: string, payload: any) => {
    ioLike.emit(event, payload);
  };

  if (started) return;
  await ensureClients();

  if (!sub) {
    console.warn("[redis] socket bridge disabled");
    return;
  }

  await sub.subscribe(broadcastChannel, (message: string) => {
    try {
      const msg = JSON.parse(message);
      if (emitter) emitter(msg.event, msg.payload);
    } catch {}
  });

  started = true;
  console.log("[redis-broadcast] attached");
}

export async function publishSocketEvent(event: string, payload: any) {
  await ensureClients();
  if (!pub) return false;

  await pub.publish(broadcastChannel, JSON.stringify({ event, payload }));
  return true;
}

// ===== Redis queue (jobs) =====
export async function enqueueJob(type: string, payload: any) {
  await ensureClients();
  if (!queueClient) {
    console.warn("[redis-queue] unavailable — queue disabled");
    return false;
  }
  await queueClient.lPush(jobsKey, JSON.stringify({ type, payload, ts: Date.now() }));
  return true;
}

export async function consumeJobs(handler: (job: any) => Promise<void>) {
  await ensureClients();
  if (!queueClient || queueStarted) return;

  queueStarted = true;
  console.log("[redis-queue] consumer started");

  while (true) {
    try {
      const result = await queueClient.brPop(jobsKey, 5);
      if (!result) continue;

      const item = Array.isArray(result) ? result[1] : result.element;
      const job = JSON.parse(item);
      await handler(job);
    } catch {
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
}
