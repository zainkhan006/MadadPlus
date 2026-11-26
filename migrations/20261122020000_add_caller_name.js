/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  const exists = await knex.schema.hasColumn("emergency_requests", "caller_name");
  if(exists) {
    return;
  }
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.string("caller_name");
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  const exists = await knex.schema.hasColumn("emergency_requests", "caller_name");
  if(!exists) {
    return;
  }
  await knex.schema.alterTable("emergency_requests", (table) => {
    table.dropColumn("caller_name");
  });
};
