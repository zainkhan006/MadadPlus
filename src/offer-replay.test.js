const test = require("node:test");
const assert = require("node:assert");
const Module = require("module");
const path = require("path");

// server.js needs a database, express and socket.io. These stand-ins let
// the ring offers run without any of them. The ambulance rows carry the
// same distance_m field countSearch reads.
let ambulanceRows = [];
const roomEmits = [];
const offerPayload = { requestId: "req-1", status: "QUEUED" };

function stubApp() {}
["use", "get", "post", "patch", "put", "delete"].forEach((method) => {
  stubApp[method] = () => {};
});

const stubs = {
  dotenv: { config: () => {} },
  express: Object.assign(() => stubApp, { json: () => () => {} }),
  cors: () => () => {},
  "socket.io": {
    Server: function () {
      return {
        on: () => {},
        to: (room) => ({ emit: (event, payload) => roomEmits.push({ room, event, payload }) })
      };
    }
  },
  "./db": () => {},
  "./dispatch": {
    QUEUED_STATUSES: ["QUEUED", "TRANSFER_QUEUED"],
    freeAmbulancesByDistance: async () => ambulanceRows,
    assignSpecific: async () => false,
    closeActiveAssignment: async () => {},
    dispatchQueuedForAmbulance: async () => null,
    getRequest: async () => null,
    requestPayload: async () => offerPayload
  }
};

const realLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (Object.prototype.hasOwnProperty.call(stubs, request)) return stubs[request];
  return realLoad.call(this, request, parent, isMain);
};
const { replayOffers, offerWhenReached, searches } = require(path.join(__dirname, "server.js"));
Module._load = realLoad;

// radius is where the edge ends, ringFrom is where it started, and
// grownMs is how long ago the ring began growing.
function openSearch({ radius, ringFrom = 0, grownMs = 15000 }) {
  const search = {
    requestId: "req-1",
    center: { lat: 0, lng: 0 },
    radius,
    ringFrom,
    ringStartedAt: Date.now() - grownMs,
    offering: true,
    coveredOnce: false,
    offered: new Map(),
    pending: new Set(),
    offerTimers: [],
    declined: new Set(),
    timer: null
  };
  searches.clear();
  searches.set(search.requestId, search);
  roomEmits.length = 0;
  return search;
}

function fakeSocket() {
  return {
    rooms: [],
    emitted: [],
    join(room) {
      this.rooms.push(room);
    },
    emit(event, payload) {
      this.emitted.push({ event, payload });
    }
  };
}

function driverOffers() {
  return roomEmits.filter((entry) => entry.event === "request.offered");
}

test("a driver inside the ring who has not declined gets the offer on join", async () => {
  const search = openSearch({ radius: 800, ringFrom: 300 });
  ambulanceRows = [{ id: "amb-2", driver_id: "driver-2", distance_m: 450 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-2");

  assert.deepStrictEqual(socket.rooms, ["driver:driver-2"]);
  assert.deepStrictEqual(socket.emitted, [{ event: "request.offered", payload: offerPayload }]);
  assert.strictEqual(search.offered.get("amb-2"), "driver-2");
});

test("a driver who declined does not get the offer again", async () => {
  const search = openSearch({ radius: 800, ringFrom: 300 });
  search.offered.set("amb-5", "driver-5");
  search.declined.add("amb-5");
  ambulanceRows = [{ id: "amb-5", driver_id: "driver-5", distance_m: 200 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-5");

  assert.deepStrictEqual(socket.emitted, []);
  assert.deepStrictEqual([...search.declined], ["amb-5"]);
});

test("a driver outside the ring does not get the offer early", async () => {
  const search = openSearch({ radius: 300 });
  ambulanceRows = [{ id: "amb-1", driver_id: "driver-1", distance_m: 1200 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-1");

  assert.deepStrictEqual(socket.emitted, []);
  assert.strictEqual(search.offered.has("amb-1"), false);
});

test("a driver who signs in before the growing edge arrives gets nothing yet", async () => {
  const search = openSearch({ radius: 300, grownMs: 3000 });
  ambulanceRows = [{ id: "amb-6", driver_id: "driver-6", distance_m: 199 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-6");

  assert.deepStrictEqual(socket.emitted, []);
  assert.strictEqual(search.offered.has("amb-6"), false);
});

test("an ambulance 199 m away is offered when the edge reaches it, not when the ring starts", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"] });
  const search = openSearch({ radius: 300, grownMs: 0 });
  const ambulance = { id: "amb-6", driver_id: "driver-6", distance_m: 199 };

  offerWhenReached(search, ambulance, offerPayload);

  t.mock.timers.tick(9000);
  assert.strictEqual(driverOffers().length, 0);
  t.mock.timers.tick(1000);
  assert.strictEqual(driverOffers().length, 1);
  assert.strictEqual(driverOffers()[0].room, "driver:driver-6");
  assert.strictEqual(search.offered.get("amb-6"), "driver-6");
});

test("an ambulance the edge has already passed is offered at once", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"] });
  const search = openSearch({ radius: 800, ringFrom: 300, grownMs: 0 });
  const ambulance = { id: "amb-3", driver_id: "driver-3", distance_m: 250 };

  offerWhenReached(search, ambulance, offerPayload);

  assert.strictEqual(driverOffers().length, 1);
});

test("an ambulance on the line is offered when the ring finishes, and a declined one never is", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"] });
  const search = openSearch({ radius: 300, grownMs: 0 });
  search.declined.add("amb-9");

  offerWhenReached(search, { id: "amb-4", driver_id: "driver-4", distance_m: 300 }, offerPayload);
  offerWhenReached(search, { id: "amb-9", driver_id: "driver-9", distance_m: 100 }, offerPayload);

  t.mock.timers.tick(14999);
  assert.strictEqual(driverOffers().length, 0);
  t.mock.timers.tick(1);
  assert.deepStrictEqual(driverOffers().map((entry) => entry.room), ["driver:driver-4"]);
});
