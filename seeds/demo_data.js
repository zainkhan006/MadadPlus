/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.seed = async function (knex) {
  await knex.transaction(async (trx) => {
    await trx("emergency_requests").del();
    await trx("ambulances").del();
    await trx("organizations").del();

    const [organization] = await trx("organizations")
      .insert({ name: "City Emergency Services" })
      .returning("id");

    const ambulances = [
      { label: "A-01", status: "AVAILABLE", lat: 24.8152, lng: 67.0321 },
      { label: "A-02", status: "AVAILABLE", lat: 24.8148, lng: 67.0315 },
      { label: "A-03", status: "AVAILABLE", lat: 24.8170, lng: 67.0340 },
      { label: "A-04", status: "AVAILABLE", lat: 24.8118, lng: 67.0288 },
      // This is closest to the scripted pickup point but cannot be assigned.
      { label: "A-05", status: "BUSY", lat: 24.8138, lng: 67.0307 }
    ];

    await trx("ambulances").insert(
      ambulances.map(({ label, status, lat, lng }) => ({
        organization_id: organization.id,
        label,
        status,
        location: trx.raw(
          "ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography",
          [lng, lat]
        )
      }))
    );
  });
};
