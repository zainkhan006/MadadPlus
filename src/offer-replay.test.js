const test = require("node:test");
const assert = require("node:assert");
const Module = require("module");
const path = require("path");

// server.js needs a database, express and socket.io. These stand-ins let
// the join replay run without any of them. The ambulance rows carry the
// same distance_m field countSearch reads.
let ambulanceRows = [];
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
      return { on: () => {}, to: () => ({ emit: () => {} }) };
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
const { replayOffers, searches } = require(path.join(__dirname, "server.js"));
Module._load = realLoad;

function openSearch(radius) {
  const search = {
    requestId: "req-1",
    center: { lat: 0, lng: 0 },
    radius,
    offering: true,
    coveredOnce: false,
    offered: new Map(),
    declined: new Set(),
    timer: null
  };
  searches.clear();
  searches.set(search.requestId, search);
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

test("a driver inside the ring who has not declined gets the offer on join", async () => {
  const search = openSearch(800);
  ambulanceRows = [{ id: "amb-2", driver_id: "driver-2", distance_m: 450 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-2");

  assert.deepStrictEqual(socket.rooms, ["driver:driver-2"]);
  assert.deepStrictEqual(socket.emitted, [{ event: "request.offered", payload: offerPayload }]);
  assert.strictEqual(search.offered.get("amb-2"), "driver-2");
});

test("a driver who declined does not get the offer again", async () => {
  const search = openSearch(800);
  search.offered.set("amb-5", "driver-5");
  search.declined.add("amb-5");
  ambulanceRows = [{ id: "amb-5", driver_id: "driver-5", distance_m: 200 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-5");

  assert.deepStrictEqual(socket.emitted, []);
  assert.deepStrictEqual([...search.declined], ["amb-5"]);
});

test("a driver outside the ring does not get the offer early", async () => {
  const search = openSearch(300);
  ambulanceRows = [{ id: "amb-1", driver_id: "driver-1", distance_m: 1200 }];
  const socket = fakeSocket();

  await replayOffers(socket, "driver-1");

  assert.deepStrictEqual(socket.emitted, []);
  assert.strictEqual(search.offered.has("amb-1"), false);
});
