import { Pool } from "pg";

const DATABASE_URL =
  process.env.DATABASE_URL ||
  "postgres://postgres:postgres@localhost:5433/postgres";

export const pool = new Pool({
  connectionString: DATABASE_URL,
  max: 10,              // max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// ✅ logi
pool.on("connect", () => {
  console.log("✅ DB pool connected");
});

pool.on("error", (err) => {
  console.error("❌ DB pool error", err.message);
});

// ✅ test connection
export async function initDatabase() {
  try {
    await pool.query("SELECT 1");
    console.log("✅ DB ready");
  } catch (err) {
    console.warn("⚠️ DB unavailable — running in fallback mode");
  }
}

// ✅ helper do query
export async function dbQuery(text: string, params?: any[]) {
  try {
    const res = await pool.query(text, params);
    return res;
  } catch (err) {
    console.error("DB query error:", err.message);
    throw err;
  }
}
