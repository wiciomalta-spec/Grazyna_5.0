import { PrismaClient } from "@prisma/client";
import { Pool } from "pg";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

export const prisma = new PrismaClient();

export const pool = new Pool({
  connectionString: databaseUrl,
  max: Number(process.env.DB_POOL_MAX || 10),
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on("connect", () => console.log("DB pool connected"));
pool.on("error", (err) => console.error("DB pool error:", err.message));

export async function initDatabase(): Promise<void> {
  await prisma.$queryRaw`SELECT 1`;
}

export async function dbQuery(text: string, params: unknown[] = []) {
  return pool.query(text, params);
}

export async function closeDatabase(): Promise<void> {
  await Promise.allSettled([prisma.$disconnect(), pool.end()]);
}