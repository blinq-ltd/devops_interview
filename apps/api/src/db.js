const { Pool } = require("pg");

// Standard libpq env vars (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD) are
// used if DATABASE_URL isn't set - either works depending on how the
// candidate wires the Secret into the pod.
// PG_POOL_MAX: max connections this single instance's pool will open
// (pg's own default is 10). Deliberately configurable - scenario 3's
// connection-budget exercise depends on being able to size this per pod.
const pool = new Pool({
  ...(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {}),
  max: parseInt(process.env.PG_POOL_MAX || "10", 10),
});

module.exports = { pool };
