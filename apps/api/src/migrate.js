const fs = require("fs");
const path = require("path");
const { pool } = require("./db");

async function main() {
  const dir = path.join(__dirname, "..", "migrations");
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".sql")).sort();
  for (const file of files) {
    const sql = fs.readFileSync(path.join(dir, file), "utf8");
    console.log(`applying ${file}`);
    await pool.query(sql);
  }
  await pool.end();
  console.log("migrations complete");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
