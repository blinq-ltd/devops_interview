const { Pool } = require("pg");

// Standard libpq env vars (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD) are
// used if DATABASE_URL isn't set - either works depending on how the
// candidate wires the Secret into the pod.
const pool = new Pool(
  process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {}
);

module.exports = { pool };
