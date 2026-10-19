const express = require("express");
const { pool } = require("./db");

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get("/livez", (_req, res) => res.status(200).send("ok"));

app.get("/readyz", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.status(200).send("ok");
  } catch (err) {
    res.status(503).json({ error: err.message });
  }
});

// GET /items - list all items
app.get("/items", async (_req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT id, name, value, updated_at FROM items ORDER BY id"
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /items/:id - view one item
app.get("/items/:id", async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT id, name, value, updated_at FROM items WHERE id = $1",
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "not found" });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /items - add an item
app.post("/items", async (req, res) => {
  const { name, value } = req.body;
  if (!name) return res.status(400).json({ error: "name is required" });
  try {
    const { rows } = await pool.query(
      "INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value, updated_at",
      [name, value ?? null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /items/:id - modify an item
app.put("/items/:id", async (req, res) => {
  const { name, value } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE items SET name = COALESCE($1, name), value = COALESCE($2, value), updated_at = now()
       WHERE id = $3 RETURNING id, name, value, updated_at`,
      [name ?? null, value ?? null, req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "not found" });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const server = app.listen(PORT, () => {
  console.log(`devops-interview-api listening on :${PORT}`);
});

// Graceful shutdown - candidate's deployment/probe config should account for this.
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down");
  server.close(() => pool.end(() => process.exit(0)));
});
