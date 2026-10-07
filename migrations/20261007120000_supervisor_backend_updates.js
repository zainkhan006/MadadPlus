/**
 * Add request fields needed for voice/manual emergency intake and hospital routing.
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.integer("people_count");
    table.text("additional_details");
    table.string("input_method", 20).notNullable().defaultTo("MANUAL");
  });
  await knex.raw(
    "alter table emergency_requests add constraint emergency_requests_people_count_positive check (people_count is null or people_count > 0)"
  );
  await knex.raw(
    "alter table emergency_requests add constraint emergency_requests_input_method_valid check (input_method in ('MANUAL','VOICE'))"
  );
};

/** @param { import("knex").Knex } knex */
exports.down = async function (knex) {
  await knex.raw("alter table emergency_requests drop constraint if exists emergency_requests_people_count_positive");
  await knex.raw("alter table emergency_requests drop constraint if exists emergency_requests_input_method_valid");
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.dropColumn("people_count");
    table.dropColumn("additional_details");
    table.dropColumn("input_method");
  });
};
