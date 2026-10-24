/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.seed = async function (knex) {
  await knex.transaction(async (trx) => {
    await trx("receipt_components").del();
    await trx("receipts").del();
    await trx("domestic_requests").del();
    await trx("providers").del();
    await trx("saved_addresses").del();
    await trx("users").del();
    await trx("specialisations").del();
    await trx("request_ambulance_blocks").del();
    await trx("request_assignments").del();
    await trx("ambulance_location_updates").del();
    await trx("emergency_requests").del();
    await trx("ambulances").del();
    await trx("drivers").del();
    await trx("hospitals").del();
    await trx("organizations").del();

    const [organization] = await trx("organizations")
      .insert({ name: "City Emergency Services", phone: "+92 21 111 000 000" })
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

    // Supervisor demo setup: five ambulances FREE, two deliberately BUSY.
    const ambulances = [
      { label: "A-01", driver: "Muhammad Ahmed", status: "FREE", lat: 24.8152, lng: 67.0321 },
      { label: "A-02", driver: "Hassan Ali", status: "FREE", lat: 24.8148, lng: 67.0315 },
      { label: "A-03", driver: "Bilal Khan", status: "BUSY", lat: 24.8195, lng: 67.0380 },
      { label: "A-04", driver: "Usman Raza", status: "FREE", lat: 24.8075, lng: 67.0240 },
      { label: "A-05", driver: "Kamran Shah", status: "FREE", lat: 24.8138, lng: 67.0307 },
      { label: "A-06", driver: "Saad Ahmed", status: "FREE", lat: 24.8220, lng: 67.0260 },
      { label: "A-07", driver: "Fahad Iqbal", status: "BUSY", lat: 24.8050, lng: 67.0375 }
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

    // Named hospitals from the demo map screenshots (approximate demo pins in
    // DHA/Clifton near the seeded ambulances; refine exact pins as needed).
    const hospitals = [
      { name: "Parklane Hospital", address: "Parklane Hospital, Clifton, Karachi", lat: 24.8146, lng: 67.0298 },
      { name: "Clifton Kidney & General Hospital", address: "Clifton Kidney & General Hospital, Clifton, Karachi", lat: 24.8162, lng: 67.0335 },
      { name: "South City Hospital", address: "South City Hospital, Clifton, Karachi", lat: 24.8095, lng: 67.0295 },
      { name: "Infinity Eye Care Centre", address: "Infinity Eye Care Centre, DHA Phase 5, Karachi", lat: 24.8205, lng: 67.0248 },
      { name: "Clifton Hospital", address: "Clifton Hospital, Clifton, Karachi", lat: 24.8135, lng: 67.0275 },
      { name: "KKT Orthopedic Spine Center", address: "KKT Orthopedic Spine Center, DHA, Karachi", lat: 24.8125, lng: 67.0355 },
      { name: "Niazi Hospital", address: "Niazi Hospital, Tauheed Commercial, DHA Phase 5, Karachi", lat: 24.8062, lng: 67.0368 },
      { name: "Medi Life Clinics", address: "Medi Life Clinics, DHA Phase 5, Karachi", lat: 24.8235, lng: 67.0285 },
      { name: "Doctors Plaza", address: "Doctors Plaza (The Plaza), DHA Phase 5, Karachi", lat: 24.8182, lng: 67.0368 }
    ];

    await trx("hospitals").insert(
      hospitals.map(({ name, address, lat, lng }) => ({
        name,
        address,
        location: trx.raw(
          "ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography",
          [lng, lat]
        )
      }))
    );

    const specialisations = await trx("specialisations")
      .insert([
        { name: "Plumber" },
        { name: "Electrician" },
        { name: "AC Technician" },
        { name: "Mechanic" }
      ])
      .returning(["id", "name"]);
    const specialisationByName = Object.fromEntries(
      specialisations.map((row) => [row.name, row.id])
    );

    // Demo users/providers use placeholder auth IDs; real sign-ups come from Supabase Auth.
    const demoUsers = await trx("users").insert([
      {
        auth_user_id: "00000000-0000-0000-0000-000000000001",
        name: "Demo User",
        phone: "+92 300 0000001",
        email: "demo.user@madadplus.test",
        verified: true
      }
    ]).returning(["id"]);

    await trx("providers").insert([
      {
        auth_user_id: "00000000-0000-0000-0000-000000000011",
        name: "Ali Plumbing Works",
        phone: "+92 300 0000011",
        cnic: "42101-0000011-1",
        status: "ONLINE",
        designation: "Plumber",
        specialisation_id: specialisationByName.Plumber,
        rating: 4.2,
        inspection_fee: 500,
        services_provided_count: 37
      },
      {
        auth_user_id: "00000000-0000-0000-0000-000000000012",
        name: "City Electricians",
        phone: "+92 300 0000012",
        cnic: "42101-0000012-1",
        status: "ONLINE",
        designation: "Electrician",
        specialisation_id: specialisationByName.Electrician,
        rating: 4.8,
        inspection_fee: 2500,
        services_provided_count: 64
      },
      {
        auth_user_id: "00000000-0000-0000-0000-000000000013",
        name: "CoolCare AC Services",
        phone: "+92 300 0000013",
        cnic: "42101-0000013-1",
        status: "ONLINE",
        designation: "AC Technician",
        specialisation_id: specialisationByName["AC Technician"],
        rating: 4.5,
        inspection_fee: 1000,
        services_provided_count: 52
      }
    ]);
  });
};
