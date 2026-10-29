/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  const exists = await knex.schema.hasColumn("providers", "address_line1");
  if(exists) {
    return;
  }
  await knex.schema.alterTable("providers", (table) => {
    table.string("address_line1");
    table.string("address_line2");
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  const exists = await knex.schema.hasColumn("providers", "address_line1");
  if(!exists) {
    return;
  }
  await knex.schema.alterTable("providers", (table) => {
    table.dropColumn("address_line1");
    table.dropColumn("address_line2");
  });
};
