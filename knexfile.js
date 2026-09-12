require("dotenv").config();

/** @type {import("knex").Knex.Config} */
module.exports = {
  development: {
    client: "pg",
    connection: {
      connectionString: process.env.DIRECT_URL,
      ssl: { rejectUnauthorized: false }
    },
    pool: {
      min: 0,
      max: 5
    },
    migrations: {
      directory: "./migrations",
      tableName: "knex_migrations"
    },
    seeds: {
      directory: "./seeds"
    }
  },

  production: {
    client: "pg",
    connection: {
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false }
    },
    pool: {
      min: 0,
      max: 5
    },
    migrations: {
      directory: "./migrations",
      tableName: "knex_migrations"
    },
    seeds: {
      directory: "./seeds"
    }
  }
};
