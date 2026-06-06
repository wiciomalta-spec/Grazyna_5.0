import { createAdapter } from "@socket.io/redis-adapter";
import { createClient } from "ioredis";
const pub = createClient({ url: process.env.REDIS_URL });
const sub = pub.duplicate();
await Promise.all([pub.connect(), sub.connect()]);
io.adapter(createAdapter(pub, sub));
