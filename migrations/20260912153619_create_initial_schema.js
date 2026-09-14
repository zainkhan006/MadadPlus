/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.raw("create extension if not exists pgcrypto")
    .then(() => knex.raw("create extension if not exists postgis"))
    .then(() => knex.schema.createTable("organizations", (table) => {
      table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
      table.string("name", 150).notNullable();
      table.timestamps(true, true);
    }))
    .then(() => knex.schema.createTable("ambulances", (table) => {
      table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
      table.uuid("organization_id").notNullable()
        .references("id").inTable("organizations").onDelete("CASCADE");
      table.string("label", 50).notNullable();
      table.string("status", 20).notNullable().defaultTo("AVAILABLE");
      table.specificType("location", "geography(Point, 4326)").notNullable();
      table.timestamps(true, true);

      table.index(["organization_id"]);
      table.index(["status"]);
    }))
    .then(() => knex.raw(
      "create index ambulances_location_gist on ambulances using gist (location)"
    ))
    .then(() => knex.schema.createTable("emergency_requests", (table) => {
      table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
      table.uuid("organization_id").notNullable()
        .references("id").inTable("organizations").onDelete("RESTRICT");
      table.uuid("assigned_ambulance_id")
        .references("id").inTable("ambulances").onDelete("SET NULL");
      table.string("type", 30).notNullable().defaultTo("ambulance");
      table.string("status", 20).notNullable().defaultTo("QUEUED");
      table.specificType("pickup_location", "geography(Point, 4326)").notNullable();
      table.timestamps(true, true);

      table.index(["organization_id"]);
      table.index(["status"]);
    }));
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.dropTableIfExists("emergency_requests")
    .then(() => knex.schema.dropTableIfExists("ambulances"))
    .then(() => knex.schema.dropTableIfExists("organizations"));
};
