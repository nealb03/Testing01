import express from "express";
import cors from "cors";
import pkg from "pg";
import bcrypt from "bcryptjs";

const { Pool } = pkg;

const app = express();
const PORT = process.env.PORT || 8080;

// CORS: allow single origin or comma-separated list in CORS_ORIGIN
const rawOrigins = process.env.CORS_ORIGIN || "http://localhost:3000";
const allowedOrigins = rawOrigins.split(",").map(s => s.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, cb) => {
    // allow no origin (curl) or if in list
    if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
    return cb(new Error("CORS not allowed"), false);
  },
  credentials: false
}));

app.use(express.json());

// DB config
const dbHost = process.env.DB_HOST || "app_db";
const dbPort = parseInt(process.env.DB_PORT || "5432", 10);
const dbUser = process.env.DB_USER || "appuser";
const dbPass = process.env.DB_PASSWORD || "apppassword";
const dbName = process.env.DB_NAME || "appdb";

const pool = new Pool({
  host: dbHost,
  port: dbPort,
  user: dbUser,
  password: dbPass,
  database: dbName,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000
});

pool.on("error", (err) => {
  console.error("Unexpected PG pool error:", err);
});

// Simple root route
app.get("/", (_req, res) => {
  res.json({
    name: "App Backend",
    ok: true,
    health: "/health",
    health_db: "/healthz/db",
    login: "POST /login"
  });
});

// App-only health (does not touch DB)
app.get("/health", (_req, res) => res.json({ ok: true }));

// DB health (pings the database)
app.get("/healthz/db", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, db: "up" });
  } catch (e) {
    console.error("DB health check failed:", e.message);
    res.status(500).json({ ok: false, db: "down", error: e.message });
  }
});

// Login route
app.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res.status(400).json({ error: "username and password required" });
    }

    // First-time lazy DB readiness: retry a few times if DB is still starting
    let attempts = 0;
    const maxAttempts = 5;
    const delay = (ms) => new Promise(r => setTimeout(r, ms));
    while (attempts < maxAttempts) {
      try {
        const { rows } = await pool.query(
          "SELECT password_hash FROM users WHERE username = $1",
          [username]
        );
        if (rows.length === 0) return res.status(401).json({ error: "invalid credentials" });

        const ok = await bcrypt.compare(password, rows[0].password_hash);
        if (!ok) return res.status(401).json({ error: "invalid credentials" });

        return res.json({ success: true, user: username });
      } catch (err) {
        attempts++;
        // Retry on connection/startup errors
        if (attempts < maxAttempts) {
          console.warn(`DB not ready (attempt ${attempts}/${maxAttempts}): ${err.message}`);
          await delay(1000 * attempts);
          continue;
        }
        throw err;
      }
    }
  } catch (e) {
    console.error("Login error:", e);
    return res.status(500).json({ error: "server error" });
  }
});

// Graceful shutdown
const server = app.listen(PORT, () => {
  console.log(`Backend listening on port ${PORT}`);
  console.log(`Allowed CORS origins: ${allowedOrigins.join(", ") || "(none)"}`);
  console.log(`DB target: ${dbUser}@${dbHost}:${dbPort}/${dbName}`);
});

const shutdown = async (signal) => {
  try {
    console.log(`Received ${signal}, shutting down...`);
    server.close(() => console.log("HTTP server closed"));
    await pool.end();
    console.log("PG pool closed");
  } catch (e) {
    console.error("Error during shutdown:", e);
  } finally {
    process.exit(0);
  }
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));