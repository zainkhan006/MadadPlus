const assert = require("node:assert/strict");
const test = require("node:test");
const { requestPayload } = require("../src/dispatch");

function mockTransaction(row) {
  const trx = () => {
    const query = {
      leftJoin() {
        return query;
      },
      select() {
        return query;
      },
      where() {
        return query;
      },
      async first() {
        return row;
      }
    };
    return query;
  };
  trx.raw = (sql) => sql;
  return trx;
}

test("request payload includes caller details and the current dispatch target", async () => {
  const payload = await requestPayload(mockTransaction({
    request_id: "request-1",
    status: "TRANSFER_EN_ROUTE",
    current_phase: "TRANSFER",
    type: "ambulance",
    caller_phone: "03000000000",
    pickup_address: "Caller address",
    emergency_description: "Injury",
    people_count: 3,
    additional_details: "I am burnt",
    input_method: "MANUAL",
    dispatch_lat: "24.8700",
    dispatch_lng: "67.0100",
    hospital_id: "hospital-1",
    hospital_name: "City Hospital",
    hospital_address: "Hospital address",
    hospital_lat: "24.9000",
    hospital_lng: "67.0500",
    assigned_ambulance_id: "ambulance-2",
    ambulance_label: "A-02",
    driver_id: "driver-2",
    driver_name: "Driver Two",
    driver_phone: "03111111111",
    pickup_lat: "24.8600",
    pickup_lng: "67.0000",
    ambulance_lat: "24.8800",
    ambulance_lng: "67.0200"
  }), "request-1");

  assert.equal(payload.additionalDetails, "I am burnt");
  assert.equal(payload.phase, "TRANSFER");
  assert.deepEqual(payload.dispatchLocation, { lat: 24.87, lng: 67.01 });
  assert.deepEqual(payload.pickupLocation, { lat: 24.86, lng: 67 });
});
