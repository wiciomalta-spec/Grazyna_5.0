import { createClient, type RedisClientType } from "redis";

const REDIS_URL = process.env.REDIS_URL || "redis://127.0.0.1:6379";

type AnyRedis = RedisClientType<any, any, any>;

let pubClient: AnyRedis | null = null;
let subClient: AnyRedis | null = null;
let queueClient: AnyRedis | null = null;
let initPromise: Promise<void> | null = null;

function onRedisError(name: string) {
  return (err: unknown) => {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(`[redis] ${name} error: ${message}`);
  };
}

async function connectClient(name: string, client: AnyRedis): Promise<AnyRedis | null> {
  client.on("error", onRedisError(name));

  try {
    if (!client.isOpen) {
      await client.connect();
    }
    return client;
  } catch (err) {
    console.warn(`[redis] ${name} unavailable — fallback mode`);
    try {
      if (client.isOpen) {
        await client.quit();
      }
    } catch {
      // ignore
    }
    return null;
  }
}

export async function initRedis(): Promise<void> {
  if (initPromise) return initPromise;

  initPromise = (async () => {
    const base = createClient({ url: REDIS_URL });
    const sub = base.duplicate();
    const queue = base.duplicate();

    pubClient = await connectClient("pub", base);
    subClient = await connectClient("sub", sub);
    queueClient = await connectClient("queue", queue);
  })();

  return initPromise;
}

void initRedis();

export function getRedisPubClient() {
  return pubClient;
}

export function getRedisSubClient() {
  return subClient;
}

export function getRedisQueueClient() {
  return queueClient;
}

/**
 * Publikuje event do kanału socket:broadcast.
 * Zakładamy sygnaturę: publishSocketEvent(eventName, payload)
 */
export async function publishSocketEvent(event: string, payload: unknown): Promise<boolean> {
  try {
    await initRedis();

    if (!pubClient || !pubClient.isOpen) {
      console.warn("[redis] pub unavailable — fallback mode");
      return false;
    }

    await pubClient.publish("socket:broadcast", JSON.stringify({ event, payload }));
    return true;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(`[redis] publish failed — fallback mode (${message})`);
    return false;
  }
}

/**
 * Podpina bridge Redis -> Socket.IO
 */
export async function attachSocketBridge(io: { emit: (event: string, payload: any) => void }) {
  try {
    await initRedis();

    if (!subClient || !subClient.isOpen) {
      console.warn("[redis] socket bridge disabled");
      return;
    }

    await subClient.subscribe("socket:broadcast", (message: string) => {
      try {
        const parsed = JSON.parse(message);
        if (parsed?.event) {
          io.emit(parsed.event, parsed.payload);
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.warn(`[redis] socket bridge parse error: ${msg}`);
      }
    });

    console.log("[redis-broadcast] attached");
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(`[redis] socket bridge disabled (${message})`);
  }
}

export async function closeRedis() {
  const clients = [pubClient, subClient, queueClient].filter(Boolean) as AnyRedis[];

  for (const client of clients) {
    try {
      if (client.isOpen) {
        await client.quit();
      }
    } catch {
      // ignore close errors
    }
  }

  pubClient = null;
  subClient = null;
  queueClient = null;
  initPromise = null;
}
