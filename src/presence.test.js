const test = require("node:test");
const assert = require("node:assert/strict");
const { refreshCode, checkScan } = require("./presence");

const job = { lat: 24.8138, lng: 67.03 };
const atJob = { lat: 24.8139, lng: 67.0301 };
const farAway = { lat: 24.8238, lng: 67.03 };

function codes() {
  let count = 0;
  return () => `code-${++count}`;
}

test("the current code is accepted when both phones are inside 100 metres", () => {
  const entry = refreshCode(null, 0, atJob, codes());
  const result = checkScan(entry, job, { code: "code-1", ...atJob }, 1000);
  assert.equal(result.ok, true);
});

test("the previous code still counts for one window after a refresh", () => {
  const make = codes();
  let entry = refreshCode(null, 0, atJob, make);
  entry = refreshCode(entry, 5000, atJob, make);
  const result = checkScan(entry, job, { code: "code-1", ...atJob }, 6000);
  assert.equal(result.ok, true);
});

test("a code from two refreshes back is rejected", () => {
  const make = codes();
  let entry = refreshCode(null, 0, atJob, make);
  entry = refreshCode(entry, 5000, atJob, make);
  entry = refreshCode(entry, 10000, atJob, make);
  const result = checkScan(entry, job, { code: "code-1", ...atJob }, 11000);
  assert.equal(result.ok, false);
});

test("a worker reading beyond 100 metres is rejected", () => {
  const entry = refreshCode(null, 0, atJob, codes());
  const result = checkScan(entry, job, { code: "code-1", ...farAway }, 1000);
  assert.equal(result.ok, false);
});

test("a user reading beyond 100 metres is rejected", () => {
  const entry = refreshCode(null, 0, farAway, codes());
  const result = checkScan(entry, job, { code: "code-1", ...atJob }, 1000);
  assert.equal(result.ok, false);
});

test("a job with no saved location is rejected", () => {
  const entry = refreshCode(null, 0, atJob, codes());
  const result = checkScan(entry, { lat: null, lng: null }, { code: "code-1", ...atJob }, 1000);
  assert.equal(result.ok, false);
});

test("a user location sent with the scan is ignored", () => {
  const entry = refreshCode(null, 0, farAway, codes());
  const result = checkScan(entry, job, {
    code: "code-1",
    ...atJob,
    userLat: atJob.lat,
    userLng: atJob.lng,
    user: atJob
  }, 1000);
  assert.equal(result.ok, false);
});
