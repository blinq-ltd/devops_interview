const { Pool } = require("pg");

// Standard libpq env vars (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD) are
// used if DATABASE_URL isn't set - either works depending on how the
// candidate wires the Secret into the pod.
// PG_POOL_MAX: max connections this single instance's pool will open
// (pg's own default is 10).
const pool = new Pool({
  ...(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {}),
  max: parseInt(process.env.PG_POOL_MAX || "10", 10),
});

module.exports = { pool };
