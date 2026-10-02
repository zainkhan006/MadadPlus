/**
 * Expand the emergency schema and add the domestic-services MVP data model.
 * Credentials are managed by Supabase Auth; this migration stores auth user IDs,
 * never passwords or password hashes.
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  await knex.schema.alterTable("organizations", (table) => {
    table.string("branch_code", 50).unique();
    table.string("phone", 40);
  });

  await knex.schema.createTable("dispatcher_accounts", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("organization_id").notNullable()
      .references("id").inTable("organizations").onDelete("CASCADE");
    // UUID from Supabase Auth; intentionally no dependency on its private schema.
    table.uuid("auth_user_id").notNullable().unique();
    table.string("name", 150).notNullable();
    table.string("role", 30).notNullable().defaultTo("DISPATCHER");
    table.timestamps(true, true);
    table.index(["organization_id"]);
  });

  await knex.schema.alterTable("drivers", (table) => {
    table.string("cnic", 30).unique();
    table.string("email", 254).unique();
    table.uuid("auth_user_id").unique();
  });

  await knex.schema.alterTable("ambulances", (table) => {
    table.string("vehicle_id", 80).unique();
    table.specificType("unavailable_location", "geography(Point, 4326)");
  });

  await knex.schema.createTable("hospitals", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.string("name", 180).notNullable();
    table.string("phone", 40);
    table.string("address", 255).notNullable();
    table.specificType("location", "geography(Point, 4326)").notNullable();
    table.boolean("active").notNullable().defaultTo(true);
    table.timestamps(true, true);
    table.index(["active"]);
  });
  await knex.raw("create index hospitals_location_gist on hospitals using gist (location)");

  await knex.schema.alterTable("emergency_requests", (table) => {
    table.uuid("hospital_id").references("id").inTable("hospitals").onDelete("SET NULL");
    table.uuid("caller_user_id");
  });
  await knex.schema.alterTable("ambulance_location_updates", (table) => {
    table.uuid("request_id").references("id").inTable("emergency_requests").onDelete("SET NULL");
    table.index(["request_id", "recorded_at"]);
  });

  await knex.schema.createTable("specialisations", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.string("name", 100).notNullable().unique();
    table.boolean("active").notNullable().defaultTo(true);
    table.timestamps(true, true);
  });

  await knex.schema.createTable("users", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("auth_user_id").notNullable().unique();
    table.string("name", 150).notNullable();
    table.string("phone", 40).notNullable().unique();
    table.string("email", 254).unique();
    table.boolean("verified").notNullable().defaultTo(false);
    table.timestamps(true, true);
  });
  await knex.schema.createTable("saved_addresses", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("user_id").notNullable().references("id").inTable("users").onDelete("CASCADE");
    table.string("label", 80);
    table.string("address", 255).notNullable();
    table.specificType("location", "geography(Point, 4326)");
    table.boolean("is_default").notNullable().defaultTo(false);
    table.timestamps(true, true);
    table.index(["user_id"]);
  });
  await knex.raw("create index saved_addresses_location_gist on saved_addresses using gist (location)");
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.foreign("caller_user_id").references("users.id").onDelete("SET NULL");
  });

  await knex.schema.createTable("providers", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("auth_user_id").notNullable().unique();
    table.string("name", 150).notNullable();
    table.string("phone", 40).notNullable().unique();
    table.string("cnic", 30).notNullable().unique();
    table.string("email", 254).unique();
    table.string("status", 20).notNullable().defaultTo("OFFLINE");
    table.specificType("location", "geography(Point, 4326)");
    table.string("designation", 100);
    table.uuid("specialisation_id").notNullable()
      .references("id").inTable("specialisations").onDelete("RESTRICT");
    table.decimal("rating", 3, 2).notNullable().defaultTo(0);
    table.integer("services_provided_count").notNullable().defaultTo(0);
    // Provider's standard inspection/service-call fee; copied to each quote.
    table.decimal("inspection_fee", 10, 2).notNullable().defaultTo(0);
    table.timestamps(true, true);
    table.index(["status", "specialisation_id"]);
  });
  await knex.raw("create index providers_location_gist on providers using gist (location)");

  await knex.schema.createTable("domestic_requests", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.text("description").notNullable();
    table.uuid("specialisation_id").notNullable()
      .references("id").inTable("specialisations").onDelete("RESTRICT");
    table.string("address", 255).notNullable();
    table.specificType("location", "geography(Point, 4326)");
    table.string("status", 30).notNullable().defaultTo("OPEN");
    table.uuid("user_id").notNullable().references("id").inTable("users").onDelete("RESTRICT");
    table.uuid("provider_id").references("id").inTable("providers").onDelete("SET NULL");
    table.timestamps(true, true);
    table.index(["status", "specialisation_id"]);
    table.index(["user_id", "created_at"]);
    table.index(["provider_id", "status"]);
  });
  await knex.raw("create index domestic_requests_location_gist on domestic_requests using gist (location)");

  await knex.schema.createTable("receipts", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("request_id").notNullable().references("id").inTable("domestic_requests").onDelete("RESTRICT");
    table.uuid("provider_id").notNullable().references("id").inTable("providers").onDelete("RESTRICT");
    table.uuid("user_id").notNullable().references("id").inTable("users").onDelete("RESTRICT");
    table.decimal("inspection_fee", 10, 2).notNullable();
    table.decimal("quoted_total", 10, 2).notNullable();
    table.decimal("final_total", 10, 2);
    table.string("status", 20).notNullable().defaultTo("NEGOTIABLE");
    table.timestamp("responded_at", { useTz: true });
    table.timestamps(true, true);
    table.index(["request_id", "status"]);
  });

  await knex.schema.createTable("receipt_components", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("receipt_id").notNullable().references("id").inTable("receipts").onDelete("CASCADE");
    table.string("component_name", 150).notNullable();
    table.decimal("component_price", 10, 2).notNullable();
    table.string("charge_type", 30).notNullable().defaultTo("EXTRA");
    table.timestamps(true, true);
    table.index(["receipt_id"]);
  });
};

/** @param { import("knex").Knex } knex */
exports.down = async function (knex) {
  await knex.schema.dropTableIfExists("receipt_components");
  await knex.schema.dropTableIfExists("receipts");
  await knex.schema.dropTableIfExists("domestic_requests");
  await knex.schema.dropTableIfExists("providers");
  await knex.raw("drop index if exists domestic_requests_location_gist");
  await knex.schema.alterTable("ambulance_location_updates", (table) => {
    table.dropIndex(["request_id", "recorded_at"]);
    table.dropForeign("request_id");
    table.dropColumn("request_id");
  });
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.dropForeign("caller_user_id");
    table.dropColumn("caller_user_id");
    table.dropColumn("hospital_id");
  });
  await knex.schema.dropTableIfExists("saved_addresses");
  await knex.schema.dropTableIfExists("users");
  await knex.schema.dropTableIfExists("specialisations");
  await knex.raw("drop index if exists providers_location_gist");
  await knex.raw("drop index if exists hospitals_location_gist");
  await knex.schema.dropTableIfExists("hospitals");
  await knex.schema.alterTable("ambulances", (table) => {
    table.dropColumn("vehicle_id");
    table.dropColumn("unavailable_location");
  });
  await knex.schema.alterTable("drivers", (table) => {
    table.dropColumn("cnic");
    table.dropColumn("email");
    table.dropColumn("auth_user_id");
  });
  await knex.schema.dropTableIfExists("dispatcher_accounts");
  await knex.schema.alterTable("organizations", (table) => {
    table.dropColumn("branch_code");
    table.dropColumn("phone");
  });
};
