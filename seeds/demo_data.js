/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.seed = async function (knex) {
  await knex.transaction(async (trx) => {
    await trx("request_ambulance_blocks").del();
    await trx("request_assignments").del();
    await trx("ambulance_location_updates").del();
    await trx("emergency_requests").del();
    await trx("ambulances").del();
    await trx("drivers").del();
    await trx("organizations").del();

    const [organization] = await trx("organizations")
      .insert({ name: "City Emergency Services" })
      .returning("id");

    const drivers = await trx("drivers").insert([
      { organization_id: organization.id, name: "Muhammad Ahmed", phone: "+92 300 1234567" },
      { organization_id: organization.id, name: "Hassan Ali", phone: "+92 301 1234567" },
      { organization_id: organization.id, name: "Bilal Khan", phone: "+92 302 1234567" },
      { organization_id: organization.id, name: "Usman Raza", phone: "+92 303 1234567" },
      { organization_id: organization.id, name: "Kamran Shah", phone: "+92 304 1234567" },
      { organization_id: organization.id, name: "Saad Ahmed", phone: "+92 305 1234567" },
      { organization_id: organization.id, name: "Fahad Iqbal", phone: "+92 306 1234567" }
    ]).returning(["id", "name"]);

    const ambulances = [
      { label: "A-01", driver: "Muhammad Ahmed", status: "FREE", lat: 24.8152, lng: 67.0321 },
      { label: "A-02", driver: "Hassan Ali", status: "FREE", lat: 24.8148, lng: 67.0315 },
      { label: "A-03", driver: "Bilal Khan", status: "FREE", lat: 24.8195, lng: 67.0380 },
      { label: "A-04", driver: "Usman Raza", status: "FREE", lat: 24.8075, lng: 67.0240 },
      // This is closest to the scripted pickup point but cannot be assigned.
      { label: "A-05", driver: "Kamran Shah", status: "BUSY", lat: 24.8138, lng: 67.0307 },
      { label: "A-06", driver: "Saad Ahmed", status: "FREE", lat: 24.8220, lng: 67.0260 },
      { label: "A-07", driver: "Fahad Iqbal", status: "FREE", lat: 24.8050, lng: 67.0375 }
    ];

    const driverByName = Object.fromEntries(drivers.map((driver) => [driver.name, driver.id]));

    await trx("ambulances").insert(
      ambulances.map(({ label, driver, status, lat, lng }) => ({
        organization_id: organization.id,
        driver_id: driverByName[driver],
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
