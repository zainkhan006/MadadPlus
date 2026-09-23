/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  await knex.schema.createTable("drivers", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("organization_id").notNullable()
      .references("id").inTable("organizations").onDelete("CASCADE");
    table.string("name", 150).notNullable();
    table.string("phone", 40).notNullable();
    table.string("status", 20).notNullable().defaultTo("ONLINE");
    table.timestamps(true, true);

    table.index(["organization_id"]);
    table.index(["status"]);
  });

  await knex.schema.alterTable("ambulances", (table) => {
    table.uuid("driver_id")
      .references("id").inTable("drivers").onDelete("SET NULL");
    table.string("unavailable_reason", 255);
    table.timestamp("last_location_at", { useTz: true });
  });

  await knex.schema.alterTable("emergency_requests", (table) => {
    table.string("caller_phone", 40);
    table.string("pickup_address", 255);
    table.text("emergency_description");
    table.string("hospital_address", 255);
    table.specificType("hospital_location", "geography(Point, 4326)");
    table.specificType("dispatch_location", "geography(Point, 4326)");
    table.specificType("breakdown_location", "geography(Point, 4326)");
    table.string("current_phase", 30).notNullable().defaultTo("PICKUP");
    table.timestamp("queued_at", { useTz: true });
    table.timestamp("picked_up_at", { useTz: true });
    table.timestamp("arrived_hospital_at", { useTz: true });
    table.timestamp("completed_at", { useTz: true });

    table.index(["current_phase"]);
  });

  await knex.schema.createTable("request_assignments", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("request_id").notNullable()
      .references("id").inTable("emergency_requests").onDelete("CASCADE");
    table.uuid("ambulance_id").notNullable()
      .references("id").inTable("ambulances").onDelete("RESTRICT");
    table.uuid("driver_id")
      .references("id").inTable("drivers").onDelete("SET NULL");
    table.integer("sequence").notNullable();
    table.string("phase", 30).notNullable();
    table.string("status", 20).notNullable().defaultTo("ACTIVE");
    table.string("reason", 100).notNullable().defaultTo("AUTOMATIC");
    table.timestamp("assigned_at", { useTz: true }).notNullable().defaultTo(knex.fn.now());
    table.timestamp("released_at", { useTz: true });
    table.string("release_reason", 255);
    table.timestamps(true, true);

    table.index(["request_id", "status"]);
    table.index(["ambulance_id", "status"]);
  });

  await knex.schema.createTable("request_ambulance_blocks", (table) => {
    table.uuid("request_id").notNullable()
      .references("id").inTable("emergency_requests").onDelete("CASCADE");
    table.uuid("ambulance_id").notNullable()
      .references("id").inTable("ambulances").onDelete("CASCADE");
    table.string("reason", 255);
    table.timestamp("created_at", { useTz: true }).notNullable().defaultTo(knex.fn.now());
    table.primary(["request_id", "ambulance_id"]);
  });

  await knex.schema.createTable("ambulance_location_updates", (table) => {
    table.uuid("id").primary().defaultTo(knex.raw("gen_random_uuid()"));
    table.uuid("ambulance_id").notNullable()
      .references("id").inTable("ambulances").onDelete("CASCADE");
    table.uuid("driver_id")
      .references("id").inTable("drivers").onDelete("SET NULL");
    table.specificType("location", "geography(Point, 4326)").notNullable();
    table.timestamp("recorded_at", { useTz: true }).notNullable().defaultTo(knex.fn.now());

    table.index(["ambulance_id", "recorded_at"]);
  });

  await knex("ambulances")
    .where("status", "AVAILABLE")
    .update({ status: "FREE" });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function (knex) {
  await knex.schema.dropTableIfExists("ambulance_location_updates");
  await knex.schema.dropTableIfExists("request_ambulance_blocks");
  await knex.schema.dropTableIfExists("request_assignments");
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.dropColumn("caller_phone");
    table.dropColumn("pickup_address");
    table.dropColumn("emergency_description");
    table.dropColumn("hospital_address");
    table.dropColumn("hospital_location");
    table.dropColumn("dispatch_location");
    table.dropColumn("breakdown_location");
    table.dropColumn("current_phase");
    table.dropColumn("queued_at");
    table.dropColumn("picked_up_at");
    table.dropColumn("arrived_hospital_at");
    table.dropColumn("completed_at");
  });
  await knex.schema.alterTable("ambulances", (table) => {
    table.dropColumn("driver_id");
    table.dropColumn("unavailable_reason");
    table.dropColumn("last_location_at");
  });
  await knex.schema.dropTableIfExists("drivers");
};
