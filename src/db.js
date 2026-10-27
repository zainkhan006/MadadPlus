const knex = require("knex");

const db = knex({
  client: "pg",
  connection: {
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  },
  pool: {
    min: 0,
    max: 5
  }
});

module.exports = db;
