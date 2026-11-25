const crypto = require("crypto");

const codeLifeMs = 5000;
const nearMetres = 200;

function reading(lat, lng) {
  if (lat == null || lng == null || lat === "" || lng === "") return null;
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  return { lat: latitude, lng: longitude };
}

function distanceMetres(from, to) {
  const radians = Math.PI / 180;
  const latGap = (to.lat - from.lat) * radians;
  const lngGap = (to.lng - from.lng) * radians;
  const arc = Math.sin(latGap / 2) ** 2
    + Math.cos(from.lat * radians) * Math.cos(to.lat * radians) * Math.sin(lngGap / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(arc), Math.sqrt(1 - arc));
}

// A code lives for one window, then stays valid as the previous code for one
// more window so a scan that crosses a refresh still counts.
function refreshCode(entry, now, userReading, makeCode = () => crypto.randomBytes(16).toString("hex")) {
  let next = entry;
  if (!next || now - next.current.at >= codeLifeMs) {
    next = {
      previous: next && now - next.current.at < codeLifeMs * 2 ? next.current : null,
      current: { code: makeCode(), at: now, user: null }
    };
  }
  if (userReading) next.current.user = userReading;
  return next;
}

function checkScan(entry, job, body, now) {
  const jobPoint = reading(job?.lat, job?.lng);
  if (!jobPoint) return { ok: false, reason: "This job has no saved location" };
  if (!entry || !body || typeof body.code !== "string") {
    return { ok: false, reason: "No live code for this job" };
  }

  let window = null;
  if (body.code === entry.current.code && now - entry.current.at < codeLifeMs * 2) {
    window = entry.current;
  }
  else if (entry.previous && body.code === entry.previous.code
    && now - entry.current.at < codeLifeMs) {
    window = entry.previous;
  }
  if (!window) return { ok: false, reason: "The code is no longer live" };

  const worker = reading(body.lat, body.lng);
  if (!worker || !window.user) return { ok: false, reason: "A location reading is missing" };
  if (distanceMetres(worker, jobPoint) > nearMetres
    || distanceMetres(window.user, jobPoint) > nearMetres) {
    return { ok: false, reason: "Both phones need to be at the job" };
  }
  return { ok: true };
}

module.exports = { codeLifeMs, nearMetres, reading, distanceMetres, refreshCode, checkScan };
