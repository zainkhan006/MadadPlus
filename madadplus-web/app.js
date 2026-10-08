// =====================================================================
// Madad+ Dispatcher — driven entirely by Ibad's real backend (the
// version importing from ./dispatch: assignNearest/assignSpecific/
// closeActiveAssignment/dispatchQueuedForAmbulance/getRequest/
// requestPayload). Every booking on this board is a direct REST read
// or a reaction to a real Socket.IO event.
//
// Two supervisor-requested additions ARE simulated locally, because
// the backend never moves anything on its own (driver location ticks
// only exist while Zain's driver app is running and a driver taps):
//
//   1. Route animation — a newly assigned unit drives along a real
//      OSRM road route to the pickup point, then on to the hospital.
//   2. Incoming-request pin — a pulsing pin marks the pickup point of
//      every tracked request, so the dispatcher can see at a glance
//      where the call came from.
//
// Both need pickup/hospital COORDINATES, and they now ship: commit
// ecfe6ef on main extended requestPayload() (src/dispatch.js) with
// pickupLocation and hospital.location, so the pin and the full
// pickup-then-hospital drive run against real coordinates — verified
// against live production on 2026-10-09.
//
// Driver actions (pickup, dropoff, reporting unavailable) live ONLY on
// Zain's driver app. This board keeps four dispatcher overrides —
// Reassign (a nearest-free-driver picker, sorted from the pickup point,
// or from the breakdown point after a mid-booking failure), Bar this
// unit, Mark free, and Mark unavailable — and they call the REAL,
// CONFIRMED endpoints (see the contract note at the bottom of this
// file). Mark free sends force:true, because the backend 409s a plain
// FREE on a BUSY unit — and force is precisely what makes it cancel that
// unit's active booking instead of orphaning it. Mark unavailable uses
// the driver route during a booking, so the backend re-queues the call
// from the breakdown point and auto-assigns the nearest unit; the picker
// is then offered as a manual override.
//
// Driver-centric board: a driver is tied to exactly one ambulance for
// MVP scope (ambulances.driver_id). GET /api/v1/ambulances LEFT JOINs
// drivers and returns driverId/driverName/driverPhone per ambulance
// (nullable), so every card below is driver-first, ambulance-second,
// and any ambulance with driverId === null is flagged "No driver
// assigned." Map markers represent the driver's live position (which
// is really the one ambulance row they're tied to — there's no
// separate driver-location table, PATCH /drivers/:id/location writes
// straight onto the linked ambulance).
//
// Hospitals: the backend now HAS a hospitals table (seeded with the
// named demo-map hospitals near A-01..A-07) plus GET /api/v1/hospitals
// returning { id, name, address, lat, lng } for active rows. So this
// board keeps two separate hospital layers:
//   - Standing layer: loadHospitals() below pulls that endpoint at boot
//     and pins every hospital it returns — the endpoint is the source
//     of truth, no hand-pinned list in this file.
//   - Per-booking markers, plotted from an active booking's own
//     hospital.location whenever the payload carries coordinates.
// =====================================================================

// ---- Config ----
const BACKEND_URL = "https://madadplus.onrender.com";

// DHA Phase 5, Karachi — matches the seed coordinates.
const DEFAULT_CENTER = { lat: 24.8000, lng: 67.0500 };

const STATUS = { FREE: "FREE", BUSY: "BUSY", UNAVAILABLE: "UNAVAILABLE" };

const STATUS_COLOR = {
  FREE: "#16a34a",
  BUSY: "#b45309",
  UNAVAILABLE: "#dc2626"
};

// ---- State ----
let map = null;
const ambulanceMarkers = {};      // ambulance id -> L.Marker (represents the driver tied to that ambulance)
const hospitalMarkers = {};       // request id -> L.Marker (one per active booking that has hospital coords)
const staticHospitalMarkers = {}; // key -> L.Marker (standing hospital layer, see loadHospitals)
const requestMarkers = {};        // request id -> L.Marker (pulsing pin at the pickup point)
const routeLines = {};            // ambulance id -> L.Polyline (route currently being driven)
const animations = {};            // ambulance id -> { cancelled } (route animation token)
const ambulances = {};            // ambulance id -> { id, label, status, lat, lng, reason, currentRequestId, driverId, driverName, driverPhone }
const requests = {};              // request id -> whatever requestPayload()/queue.updated sent us

// Standing hospital layer: filled at boot by loadHospitals() from
// GET /api/v1/hospitals (the seeded demo-map hospitals), keyed by name.

// ---- Utilities ----
function haversineKm(a, b) {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

function shortId(id) {
  return `#${String(id).slice(0, 6)}`;
}

// The real backend's ambulance status column is already FREE / BUSY /
// UNAVAILABLE — matching this board's internal STATUS constants
// directly, no AVAILABLE->FREE translation needed any more. This stays
// as a single choke point anyway so a future drift can't silently
// break every status comparison in the file again.
function normalizeStatus(rawStatus) {
  const s = String(rawStatus || "").toUpperCase();
  return STATUS[s] || STATUS.FREE;
}

// Hospital coordinates: requestPayload() (src/dispatch.js, commit
// ecfe6ef) returns hospital: { id, name, address, location } and always
// returns pickupLocation. The older flat field names stay as fallbacks
// so a payload from an older backend still plots; nothing throws when a
// field is missing, it just doesn't plot.
function pickHospital(payload) {
  const hospital = payload.hospital || null;
  const lat =
    hospital?.location?.lat ?? payload.hospitalLat ?? payload.hospital_lat ?? payload.hospitalLocation?.lat ?? null;
  const lng =
    hospital?.location?.lng ?? payload.hospitalLng ?? payload.hospital_lng ?? payload.hospitalLocation?.lng ?? null;
  const address = hospital?.address ?? payload.hospitalAddress ?? payload.hospital_address ?? null;
  const name = hospital?.name ?? null;
  if (lat == null || lng == null) return null;
  const numLat = Number(lat);
  const numLng = Number(lng);
  if (!Number.isFinite(numLat) || !Number.isFinite(numLng)) return null;
  return { lat: numLat, lng: numLng, address, name };
}

// Who booked this call. requestPayload() does NOT send this yet — the
// emergency_requests table has no user/name captured on an ambulance
// booking (only domestic requests carry a user). Read the same shape the
// backend already uses for domestic requests (`user: { id, name, phone }`)
// plus flat fallbacks, so the card lights up the day Ibad adds it. Never
// hardcoded, never invented: no fields means no user line.
function pickUser(payload) {
  const user = payload.user || null;
  const id = (user && user.id) || payload.userId || payload.user_id || null;
  const name = (user && user.name) || payload.userName || payload.user_name || null;
  const phone = (user && user.phone) || payload.userPhone || payload.user_phone || null;
  if (!id && !name && !phone) return null;
  return { id, name, phone };
}

// Thin REST helper used by the settings panel (and anything else that
// needs a plain JSON call). Returns a result object instead of throwing,
// so a missing/offline backend endpoint degrades into a readable message
// rather than a broken UI.
async function apiCall(path, method = "GET", body) {
  try {
    const res = await fetch(`${BACKEND_URL}${path}`, {
      method,
      headers: body ? { "Content-Type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      return { ok: false, status: res.status, error: data.error || `Request failed: ${res.status}` };
    }
    return { ok: true, status: res.status, data };
  } catch (error) {
    return { ok: false, status: 0, error: error.message };
  }
}

// ---- Map ----
function initMap() {
  map = L.map("map", { zoomControl: true }).setView([DEFAULT_CENTER.lat, DEFAULT_CENTER.lng], 14);

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19
  }).addTo(map);
}

// Inline SVG ambulance, drawn as an actual ambulance: box body + cab,
// red cross, windscreen, two wheels, red/blue light bar, sitting on a
// status-colored road strip inside a status-colored chip. The point of
// the literal shape (supervisor's requirement) is that a first-time
// user reads "ambulance" off the icon alone, without the legend — the
// status is carried by the chip border + road strip (green / amber /
// red), not by the vehicle itself.
function ambulanceIconHtml(status) {
  const color = STATUS_COLOR[status] || STATUS_COLOR.UNAVAILABLE;
  return `
    <svg width="40" height="40" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
      <rect x="2.5" y="2.5" width="35" height="35" rx="9" fill="#ffffff" stroke="${color}" stroke-width="3" />
      <rect x="8" y="30.6" width="24" height="2.4" rx="1.2" fill="${color}" />
      <rect x="7.5" y="16" width="13.5" height="10.5" rx="1.6" fill="#f8fafc" stroke="#1f2937" stroke-width="1.5" />
      <path d="M21 18.5 h3.9 l4.6 5.2 V26.5 H21 Z" fill="#f8fafc" stroke="#1f2937" stroke-width="1.5" stroke-linejoin="round" />
      <path d="M22.6 19.8 h2.2 l3 3.4 h-5.2 Z" fill="#38bdf8" stroke="#1f2937" stroke-width="1" stroke-linejoin="round" />
      <g class="amb-lightbar">
        <rect x="21.4" y="15.9" width="3.2" height="2.6" rx="1.1" fill="#ef4444" />
        <rect x="24.6" y="15.9" width="3.2" height="2.6" rx="1.1" fill="#2563eb" />
      </g>
      <rect x="12.7" y="16.8" width="3" height="7" rx="0.6" fill="#dc2626" />
      <rect x="10.7" y="18.8" width="7" height="3" rx="0.6" fill="#dc2626" />
      <circle cx="12.5" cy="27.4" r="3.2" fill="#1f2937" />
      <circle cx="12.5" cy="27.4" r="1.3" fill="#e2e8f0" />
      <circle cx="26.4" cy="27.4" r="3.2" fill="#1f2937" />
      <circle cx="26.4" cy="27.4" r="1.3" fill="#e2e8f0" />
    </svg>`;
}

function ambulanceIcon(status) {
  return L.divIcon({
    className: "ambulance-marker",
    html: ambulanceIconHtml(status),
    iconSize: [40, 40],
    iconAnchor: [20, 20]
  });
}

// Small inline SVG hospital (H-in-a-cross) icon for per-booking
// hospital markers.
function hospitalIconHtml() {
  return `
    <svg width="26" height="26" viewBox="0 0 26 26" xmlns="http://www.w3.org/2000/svg">
      <circle cx="13" cy="13" r="12" fill="#2563eb" stroke="#ffffff" stroke-width="2.25" />
      <text x="13" y="18" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" font-weight="700" fill="#ffffff">H</text>
    </svg>`;
}

function hospitalIcon() {
  return L.divIcon({
    className: "hospital-marker",
    html: hospitalIconHtml(),
    iconSize: [26, 26],
    iconAnchor: [13, 13]
  });
}

// ---- Pulsing pin: "a call is coming from here" (supervisor request) ----
function requestPinHtml() {
  return `
    <div class="req-pin">
      <span class="req-pin__pulse"></span>
      <span class="req-pin__pulse req-pin__pulse--delay"></span>
      <span class="req-pin__dot"></span>
    </div>`;
}

function requestPinIcon() {
  return L.divIcon({
    className: "request-pin",
    html: requestPinHtml(),
    iconSize: [36, 36],
    iconAnchor: [18, 18]
  });
}

function upsertRequestPin(req) {
  if (!map || !req || !req.pickup) return;
  const latlng = [req.pickup.lat, req.pickup.lng];
  const tooltip = `Incoming request${req.pickupAddress ? ` — ${req.pickupAddress}` : ""}`;
  if (requestMarkers[req.id]) {
    requestMarkers[req.id].setLatLng(latlng);
  } else {
    requestMarkers[req.id] = L.marker(latlng, { icon: requestPinIcon(), zIndexOffset: 500 })
      .bindTooltip(tooltip)
      .addTo(map);
  }
  requestMarkers[req.id].setTooltipContent(tooltip);
}

function removeRequestPin(requestId) {
  if (requestMarkers[requestId]) {
    map.removeLayer(requestMarkers[requestId]);
    delete requestMarkers[requestId];
  }
}

// ---- Standing hospital layer (GET /api/v1/hospitals) ----
// Named upsertHospitalRow (not upsertHospitalMarker) on purpose: that
// name already belongs to the per-booking hospital marker below, and a
// later function declaration silently overrides an earlier one.
function upsertHospitalRow(key, hospital) {
  if (!map || !hospital || hospital.lat == null || hospital.lng == null) return;
  const tooltip =
    hospital.name && hospital.address
      ? `${hospital.name} — ${hospital.address}`
      : hospital.name || hospital.address || "Hospital";
  if (staticHospitalMarkers[key]) {
    staticHospitalMarkers[key].setLatLng([hospital.lat, hospital.lng]).bindTooltip(tooltip);
  } else {
    staticHospitalMarkers[key] = L.marker([hospital.lat, hospital.lng], { icon: hospitalIcon() })
      .bindTooltip(tooltip)
      .addTo(map);
  }
}

// Boot-time fetch of the hospital master list. No fallback list lives in
// this file: the endpoint is the source of truth, so the board shows
// exactly the hospitals the dispatcher backend knows about.
async function loadHospitals() {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/hospitals`);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    const hospitals = await res.json();
    hospitals.forEach((hospital) => upsertHospitalRow(hospital.name || String(hospital.id), hospital));
  } catch (error) {
    console.error("Could not load hospitals:", error);
  }
}

// ---- Route animation: assigned unit drives to pickup, then hospital ----
// Roads come from the free public OSRM demo server (no key); if routing
// fails we fall back to a straight line so a flaky network only makes
// the demo less pretty, never broken.
function driveDurationMs(from, to) {
  const km = haversineKm(from, to);
  return Math.min(45000, Math.max(8000, (km / 55) * 3600000));
}

function cancelAnimation(ambulanceId) {
  if (animations[ambulanceId]) animations[ambulanceId].cancelled = true;
  clearRouteLine(ambulanceId);
}

function drawRouteLine(ambulanceId, points) {
  clearRouteLine(ambulanceId);
  routeLines[ambulanceId] = L.polyline(
    points.map((p) => [p.lat, p.lng]),
    { color: "#5b6472", weight: 3, opacity: 0.6, dashArray: "4,6" }
  ).addTo(map);
}

function clearRouteLine(ambulanceId) {
  if (routeLines[ambulanceId]) {
    map.removeLayer(routeLines[ambulanceId]);
    delete routeLines[ambulanceId];
  }
}

async function fetchRoute(from, to) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    const url = `https://router.project-osrm.org/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}?overview=full&geometries=geojson`;
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) throw new Error(`OSRM request failed: ${res.status}`);
    const data = await res.json();
    if (!data.routes || !data.routes.length) throw new Error("No route found");
    return data.routes[0].geometry.coordinates.map(([lng, lat]) => ({ lat, lng }));
  } catch (err) {
    console.warn("Road routing unavailable, falling back to a straight line:", err);
    return [from, to];
  }
}

function animateAlongRoute(token, ambulanceId, routePoints, durationMs, onComplete) {
  const segDistances = [];
  let totalDist = 0;
  for (let i = 0; i < routePoints.length - 1; i++) {
    const d = haversineKm(routePoints[i], routePoints[i + 1]);
    segDistances.push(d);
    totalDist += d;
  }

  function pointAtFraction(f) {
    if (routePoints.length === 1 || totalDist === 0) return routePoints[0];
    const targetDist = f * totalDist;
    let covered = 0;
    for (let i = 0; i < segDistances.length; i++) {
      if (covered + segDistances[i] >= targetDist || i === segDistances.length - 1) {
        const segFrac = segDistances[i] === 0 ? 0 : (targetDist - covered) / segDistances[i];
        const a = routePoints[i];
        const b = routePoints[i + 1];
        return { lat: a.lat + (b.lat - a.lat) * segFrac, lng: a.lng + (b.lng - a.lng) * segFrac };
      }
      covered += segDistances[i];
    }
    return routePoints[routePoints.length - 1];
  }

  const start = performance.now();
  function step(now) {
    if (token.cancelled) return;
    const t = Math.min(1, (now - start) / durationMs);
    const pos = pointAtFraction(t);

    const amb = ambulances[ambulanceId];
    if (amb) {
      amb.lat = pos.lat;
      amb.lng = pos.lng;
    }
    const marker = ambulanceMarkers[ambulanceId];
    if (marker) marker.setLatLng([pos.lat, pos.lng]);

    if (t < 1) {
      requestAnimationFrame(step);
    } else {
      clearRouteLine(ambulanceId);
      if (animations[ambulanceId] === token) delete animations[ambulanceId];
      if (onComplete) onComplete();
    }
  }
  requestAnimationFrame(step);
}

async function driveAmbulanceTo(ambulanceId, destination, durationMs, onComplete) {
  const amb = ambulances[ambulanceId];
  if (!amb) return;
  const from = { lat: amb.lat, lng: amb.lng };
  const token = { cancelled: false };
  cancelAnimation(ambulanceId);
  animations[ambulanceId] = token; // registered BEFORE the await, so a cancel during routing is honoured
  const route = await fetchRoute(from, destination);
  if (token.cancelled || !ambulances[ambulanceId]) return;
  drawRouteLine(ambulanceId, route);
  animateAlongRoute(token, ambulanceId, route, durationMs, onComplete);
}

// Drives the assigned unit through the legs of its booking: to the
// pickup point first, then on to the hospital. One leg at a time per
// request; called again after each leg lands, and no-ops when there is
// nothing left to drive or no coordinates in the payload (a request
// booked without a hospital simply ends at the pickup).
function syncRequestAnimation(req) {
  if (!req || !req.anim || req.anim.running) return;
  if (!req.ambulanceId || !ambulances[req.ambulanceId]) return;

  const anim = req.anim;
  let leg = null;
  let target = null;

  if (req.phase === "TRANSFER" && req.hospital && !anim.hospitalDone) {
    anim.pickupDone = true; // patient is already aboard — don't drive back to the pickup
    leg = "hospital";
    target = req.hospital;
  } else if (!anim.pickupDone && req.pickup) {
    leg = "pickup";
    target = req.pickup;
  } else if (!anim.hospitalDone && req.hospital) {
    leg = "hospital";
    target = req.hospital;
  }
  if (!target) return;

  const amb = ambulances[req.ambulanceId];
  const from = { lat: amb.lat, lng: amb.lng };
  if (haversineKm(from, target) < 0.03) {
    // Already at the leg's destination — land it without animating.
    if (leg === "pickup") anim.pickupDone = true;
    else anim.hospitalDone = true;
    syncRequestAnimation(req);
    return;
  }

  anim.running = true;
  anim.leg = leg;
  driveAmbulanceTo(req.ambulanceId, target, driveDurationMs(from, target), () => {
    anim.running = false;
    anim.leg = null;
    if (leg === "pickup") anim.pickupDone = true;
    else anim.hospitalDone = true;
    if (requests[req.id]) syncRequestAnimation(req);
  });
}

function driverLabel(amb) {
  return amb.driverName || "No driver assigned";
}

function upsertAmbulanceMarker(amb) {
  if (!map) return;
  const latlng = [amb.lat, amb.lng];
  const tooltip = `${driverLabel(amb)} — ${amb.label} — ${amb.status}`;
  if (ambulanceMarkers[amb.id]) {
    ambulanceMarkers[amb.id].setLatLng(latlng);
    ambulanceMarkers[amb.id].setIcon(ambulanceIcon(amb.status));
  } else {
    ambulanceMarkers[amb.id] = L.marker(latlng, { icon: ambulanceIcon(amb.status) })
      .bindTooltip(tooltip)
      .addTo(map);
  }
  ambulanceMarkers[amb.id].setTooltipContent(tooltip);
}

function upsertHospitalMarker(requestId, hospital) {
  if (!map || !hospital) return;
  const latlng = [hospital.lat, hospital.lng];
  const tooltip = hospital.name || hospital.address || "Hospital";
  if (hospitalMarkers[requestId]) {
    hospitalMarkers[requestId].setLatLng(latlng);
  } else {
    hospitalMarkers[requestId] = L.marker(latlng, { icon: hospitalIcon() })
      .bindTooltip(tooltip)
      .addTo(map);
  }
  hospitalMarkers[requestId].setTooltipContent(tooltip);
}

function removeHospitalMarker(requestId) {
  if (hospitalMarkers[requestId]) {
    map.removeLayer(hospitalMarkers[requestId]);
    delete hospitalMarkers[requestId];
  }
}

// ---- Loading ambulances from the real backend ----
async function loadAmbulances() {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/ambulances`);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    const list = await res.json();
    list.forEach((a) => {
      ambulances[a.id] = {
        id: a.id,
        label: a.label,
        status: normalizeStatus(a.status),
        lat: Number(a.lat),
        lng: Number(a.lng),
        reason: a.unavailableReason || null,
        currentRequestId: null,
        driverId: a.driverId || null,
        driverName: a.driverName || null,
        driverPhone: a.driverPhone || null
      };
      upsertAmbulanceMarker(ambulances[a.id]);
    });
    renderAll();
  } catch (err) {
    console.error("Could not load ambulances:", err);
  }
}

// Periodic reconciliation for live tracking: driver phones push
// ambulance.updated (position ticks while free AND on a call), but a
// dropped socket would freeze the map. This re-reads the snapshot and
// updates positions/status — never touching a unit mid-drive, where the
// animation owns the marker until it lands.
async function syncAmbulanceSnapshot() {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/ambulances`);
    if (!res.ok) return;
    const list = await res.json();
    list.forEach((a) => {
      const amb = ambulances[a.id];
      if (!amb) return;
      if (!animations[a.id]) {
        if (a.lat != null) amb.lat = Number(a.lat);
        if (a.lng != null) amb.lng = Number(a.lng);
      }
      if (a.status) amb.status = normalizeStatus(a.status);
      if (a.unavailableReason !== undefined) amb.reason = a.unavailableReason || null;
      amb.driverId = a.driverId || null;
      amb.driverName = a.driverName || null;
      amb.driverPhone = a.driverPhone || null;
      upsertAmbulanceMarker(amb);
    });
    renderAll();
  } catch (err) {
    // Offline is fine — the socket and the next tick will retry.
  }
}

// ---- Dispatcher overrides — REAL, CONFIRMED backend calls ----
// Reassign        -> POST /api/v1/emergency-requests/:requestId/assign { ambulanceId }
// Bar             -> POST /api/v1/emergency-requests/:requestId/blocked-ambulances { ambulanceId, reason }
// Mark free       -> PATCH /api/v1/ambulances/:ambulanceId/status { status: "FREE", force: true }
// Mark unavailable-> PATCH /api/v1/drivers/:driverId/unavailable { reason, lat, lng }
//                    (falls back to PATCH /ambulances/:id/status when the
//                    unit has no driver). The backend cancels the active
//                    booking, re-queues it, and auto-assigns the nearest
//                    free unit; the dispatcher can still override via the
//                    nearest-driver picker.
async function dispatcherReassign(requestId, newAmbulanceId) {
  closeReassignModal();
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/emergency-requests/${requestId}/assign`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ambulanceId: newAmbulanceId })
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Reassign failed: ${res.status}`);
    }
    // Backend re-broadcasts request.reassigned + ambulance.updated over
    // the dispatch room — this board just waits for those rather than
    // optimistically updating itself.
  } catch (err) {
    console.error(err);
    window.alert(`Couldn't reassign this booking: ${err.message}`);
  }
}

async function dispatcherBar(requestId, ambulanceId) {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/emergency-requests/${requestId}/blocked-ambulances`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ambulanceId, reason: "Barred by dispatcher" })
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Bar failed: ${res.status}`);
    }
    window.alert("Unit barred from this request. Use Reassign to put another unit on it.");
  } catch (err) {
    console.error(err);
    window.alert(`Couldn't bar this unit: ${err.message}`);
  }
}

async function dispatcherMarkFree(ambulanceId) {
  const amb = ambulances[ambulanceId];
  // force:true is what the backend demands for a BUSY unit — and it is
  // also what makes the backend cancel that unit's ACTIVE booking in the
  // same transaction (otherwise the booking would keep pointing at a unit
  // that is now free). Warn before throwing a booking away.
  if (amb && amb.status === STATUS.BUSY) {
    const ok = window.confirm(
      `${amb.label} is BUSY. Marking it free also cancels the active booking it is holding. Continue?`
    );
    if (!ok) return;
  }
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/ambulances/${ambulanceId}/status`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status: "FREE", force: true })
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Mark free failed: ${res.status}`);
    }
    // The backend re-broadcasts ambulance.updated (and request.cancelled
    // for any booking it had to cancel) — this board waits for those
    // rather than optimistically flipping the card itself.
  } catch (err) {
    console.error(err);
    window.alert(`Couldn't mark this unit free: ${err.message}`);
  }
}

// Dispatcher-side "mark unavailable": works before, during, or after a
// booking. During a booking the backend detaches the call (re-queues it
// from the unit's current position, or auto-assigns the nearest free
// unit) and hands back replacementRequestId so we can open the picker.
async function dispatcherMarkUnavailable(ambulanceId) {
  const amb = ambulances[ambulanceId];
  if (!amb) return;
  const onBooking = amb.status === STATUS.BUSY && !!amb.currentRequestId;
  if (onBooking) {
    const ok = window.confirm(
      `${amb.label} is on an active booking. Marking it unavailable hands this call back for reassignment. Continue?`
    );
    if (!ok) return;
  }
  const reason = window.prompt(`Reason for marking ${amb.label} unavailable?`, "Vehicle breakdown");
  if (reason === null) return;
  const cleanReason = reason.trim() || "Marked unavailable by dispatcher";

  const coordinates =
    Number.isFinite(amb.lat) && Number.isFinite(amb.lng) ? { lat: amb.lat, lng: amb.lng } : {};

  try {
    let res;
    if (amb.driverId) {
      res = await fetch(`${BACKEND_URL}/api/v1/drivers/${amb.driverId}/unavailable`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reason: cleanReason, ...coordinates })
      });
    } else {
      res = await fetch(`${BACKEND_URL}/api/v1/ambulances/${ambulanceId}/status`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: "UNAVAILABLE", reason: cleanReason, force: true })
      });
    }
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Mark unavailable failed: ${res.status}`);
    }
    const body = await res.json().catch(() => ({}));
    // Backend already re-queued (and possibly auto-assigned) the call.
    // If it came back unassigned, surface the nearest-driver picker now.
    if (body && body.replacementRequestId && requests[body.replacementRequestId]) {
      requests[body.replacementRequestId].breakdownLocation =
        coordinates.lat != null ? { lat: coordinates.lat, lng: coordinates.lng } : requests[body.replacementRequestId].breakdownLocation || null;
      if (!requests[body.replacementRequestId].ambulanceId) {
        maybeAutoOpenPicker(body.replacementRequestId, { breakdown: true, reference: coordinates.lat != null ? coordinates : null });
      }
    }
  } catch (err) {
    console.error(err);
    window.alert(`Couldn't mark this unit unavailable: ${err.message}`);
  }
}

// ---- Reassign / nearest-driver picker ----
let reassignTargetRequestId = null;

// Requests we just handed back because their unit went unavailable, and
// for which we already popped the picker (so a driver/backend event
// can't pop it twice).
const pickerShownFor = new Set();

// Reference point for "nearest": the broken unit's last position when
// this is a mid-booking breakdown, otherwise the pickup point.
function reassignReference(req, options) {
  return (
    toPoint(options && options.reference) ||
    (req && req.breakdownLocation) ||
    (req && req.pickup) ||
    null
  );
}

function openReassignModal(reqId, options = {}) {
  reassignTargetRequestId = reqId;
  const req = requests[reqId] || null;
  const reference = reassignReference(req, options);
  const freeUnits = Object.values(ambulances).filter((a) => a.status === STATUS.FREE);

  // Nearest -> furthest from the reference point (unknown distances last).
  const ranked = freeUnits
    .map((amb) => ({
      amb,
      km:
        reference && Number.isFinite(amb.lat) && Number.isFinite(amb.lng)
          ? haversineKm({ lat: amb.lat, lng: amb.lng }, reference)
          : null
    }))
    .sort((a, b) => (a.km == null ? 1 : b.km == null ? -1 : a.km - b.km));

  const sub = document.getElementById("reassignSub");
  if (ranked.length === 0) {
    sub.textContent = "No free units available right now.";
  } else if (options.breakdown) {
    sub.textContent =
      "The assigned unit went unavailable mid-call. Nearest free units first — pick one to hand this booking to:";
  } else {
    sub.textContent = "Nearest free units first — pick one to put on this call:";
  }

  const list = document.getElementById("reassignList");
  list.innerHTML = "";
  ranked.forEach(({ amb, km }) => {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    const distLabel = km == null ? "distance unknown" : `${km.toFixed(2)} km away`;
    const phone = amb.driverPhone ? ` · ${amb.driverPhone}` : "";
    btn.textContent = `${driverLabel(amb)} — ${amb.label} — ${distLabel}${phone}`;
    btn.onclick = () => dispatcherReassign(reqId, amb.id);
    li.appendChild(btn);
    list.appendChild(li);
  });

  document.getElementById("reassignModal").classList.add("is-open");
}

// Auto-open the picker exactly once per request — used when a booking is
// left QUEUED (nothing to override) after its unit went unavailable.
function maybeAutoOpenPicker(requestId, options) {
  if (!requestId || pickerShownFor.has(requestId)) return;
  pickerShownFor.add(requestId);
  openReassignModal(requestId, options);
}

function closeReassignModal() {
  reassignTargetRequestId = null;
  document.getElementById("reassignModal").classList.remove("is-open");
}

// ---- Tabs ----
let activeTab = "FREE";

function switchTab(tab) {
  activeTab = tab;
  document.querySelectorAll(".tab").forEach((el) => {
    el.classList.toggle("is-active", el.dataset.tab === tab);
  });
  document.getElementById("listFree").classList.toggle("is-hidden", tab !== "FREE");
  document.getElementById("listBusy").classList.toggle("is-hidden", tab !== "BUSY");
  document.getElementById("listUnavailable").classList.toggle("is-hidden", tab !== "UNAVAILABLE");
}

document.getElementById("tabs").addEventListener("click", (e) => {
  const btn = e.target.closest(".tab");
  if (btn) switchTab(btn.dataset.tab);
});

document.getElementById("reassignClose").addEventListener("click", closeReassignModal);

// ---- Rendering (driver-centric: every card leads with the driver,
// ambulance label is secondary, "No driver assigned" is flagged) ----
function renderAll() {
  Object.values(ambulances).forEach(upsertAmbulanceMarker);
  renderFreeList();
  renderBusyList();
  renderUnavailableList();
  updateCounts();
}

function updateCounts() {
  const all = Object.values(ambulances);
  document.getElementById("countFree").textContent = all.filter((a) => a.status === STATUS.FREE).length;
  document.getElementById("countBusy").textContent = all.filter((a) => a.status === STATUS.BUSY).length;
  document.getElementById("countUnavailable").textContent = all.filter((a) => a.status === STATUS.UNAVAILABLE).length;
}

function renderFreeList() {
  const el = document.getElementById("listFree");
  const free = Object.values(ambulances).filter((a) => a.status === STATUS.FREE);
  if (free.length === 0) {
    el.innerHTML = `<li class="board-empty">No free drivers right now.</li>`;
    return;
  }
  el.innerHTML = free
    .map(
      (amb) => `
      <li class="amb-card">
        <div>
          <div class="amb-card__label">
            ${driverLabel(amb)}
            ${!amb.driverId ? `<span class="amb-card__flag">No driver assigned</span>` : ""}
          </div>
          <div class="amb-card__meta">${amb.label}${amb.driverPhone ? ` &middot; ${amb.driverPhone}` : ""} &middot; ready for dispatch</div>
        </div>
        <button class="btn btn--danger" onclick="dispatcherMarkUnavailable('${amb.id}')">Mark unavailable</button>
      </li>`
    )
    .join("");
}

function renderBusyList() {
  const el = document.getElementById("listBusy");
  // Everything we're tracking is an open call — assigned ones render on
  // their unit's card, unassigned/QUEUED ones (e.g. after a breakdown)
  // render as "needs unit" so the dispatcher can put a unit on them.
  const busyRequests = Object.values(requests);

  const trackedBusyIds = new Set(busyRequests.map((r) => r.ambulanceId));
  const orphanBusy = Object.values(ambulances).filter(
    (a) => a.status === STATUS.BUSY && !trackedBusyIds.has(a.id)
  );

  if (busyRequests.length === 0 && orphanBusy.length === 0) {
    el.innerHTML = `<li class="board-empty">No active bookings right now.</li>`;
    return;
  }

  const orphanHtml = orphanBusy
    .map(
      (amb) => `
      <li class="amb-card">
        <div>
          <div class="amb-card__label">
            ${driverLabel(amb)}
            ${!amb.driverId ? `<span class="amb-card__flag">No driver assigned</span>` : ""}
          </div>
          <div class="amb-card__meta">${amb.label} &middot; busy &middot; no booking details available</div>
        </div>
        <button class="btn btn--danger" onclick="dispatcherMarkUnavailable('${amb.id}')">Mark unavailable</button>
        <button class="btn btn--free" onclick="dispatcherMarkFree('${amb.id}')">Mark free</button>
      </li>`
    )
    .join("");

  const busyHtml = busyRequests
    .map((req) => {
      const amb = ambulances[req.ambulanceId];
      const callerPhone = req.callerPhone || null;
      const description = req.description || null;
      const pickupAddress = req.pickupAddress || null;
      const hospital = req.hospital;
      const user = req.user;
      const hospitalLabel = hospital ? hospital.name || hospital.address : req.hospitalName || req.hospitalAddress;
      const isTransfer = req.phase === "TRANSFER";
      const queued = !amb;
      const needsReassign = !!req.needsReassignment;

      return `
        <li class="booking-card">
          <div class="booking-card__top">
            <span class="booking-card__id">${shortId(req.id)}</span>
            <span class="booking-card__leg${isTransfer ? " booking-card__leg--transfer" : ""}">${
              queued ? "QUEUED · needs unit" : req.status || "ASSIGNED"
            }</span>
          </div>
          <div class="booking-card__main">
            ${
              amb
                ? `<strong>${driverLabel(amb)}</strong> &middot; ${amb.label}
                   ${!amb.driverId ? `<span class="amb-card__flag">No driver assigned</span>` : ""}`
                : `<strong>Unassigned</strong> &middot; no unit on this call`
            }
            ${needsReassign ? `<span class="booking-card__flag">Unit went unavailable — reassign</span>` : ""}
            ${
              user && (user.name || user.id)
                ? `<br/>Booked by: ${user.name || "Unknown"}${user.id ? ` (${shortId(user.id)})` : ""}${
                    user.phone ? ` &middot; ${user.phone}` : ""
                  }`
                : ""
            }
            ${callerPhone ? `<br/>Caller: ${callerPhone}` : ""}
            ${pickupAddress ? `<br/>Pickup: ${pickupAddress}` : ""}
            ${description ? `<br/>${description}` : ""}
            ${req.peopleCount ? `<br/>People: ${req.peopleCount}` : ""}
            ${req.additionalDetails ? `<br/>Notes: ${req.additionalDetails}` : ""}
            ${hospitalLabel ? `<br/>Hospital: ${hospitalLabel}` : ""}
          </div>
          <div class="booking-card__actions">
            <button class="btn btn--primary" onclick="openReassignModal('${req.id}'${
              needsReassign ? ", { breakdown: true }" : ""
            })">${needsReassign || queued ? "Assign nearest unit" : "Reassign"}</button>
            ${
              amb
                ? `<button class="btn btn--danger" onclick="dispatcherBar('${req.id}','${amb.id}')">Bar this unit</button>
                   <button class="btn btn--danger" onclick="dispatcherMarkUnavailable('${amb.id}')">Mark unavailable</button>
                   <button class="btn btn--free" onclick="dispatcherMarkFree('${amb.id}')">Mark free</button>`
                : ""
            }
          </div>
        </li>`;
    })
    .join("");

  el.innerHTML = orphanHtml + busyHtml;
}

function renderUnavailableList() {
  const el = document.getElementById("listUnavailable");
  const unavailable = Object.values(ambulances).filter((a) => a.status === STATUS.UNAVAILABLE);
  if (unavailable.length === 0) {
    el.innerHTML = `<li class="board-empty">No unavailable units.</li>`;
    return;
  }
  el.innerHTML = unavailable
    .map(
      (amb) => `
      <li class="amb-card">
        <div>
          <div class="amb-card__label">
            ${driverLabel(amb)}
            ${!amb.driverId ? `<span class="amb-card__flag">No driver assigned</span>` : ""}
          </div>
          <div class="amb-card__meta">${amb.label}</div>
          <div class="amb-card__reason">${amb.reason || "Unavailable"}</div>
        </div>
        <button class="btn btn--free" onclick="dispatcherMarkFree('${amb.id}')">Mark free</button>
      </li>`
    )
    .join("");
}

window.dispatcherMarkFree = dispatcherMarkFree;
window.dispatcherMarkUnavailable = dispatcherMarkUnavailable;
window.dispatcherBar = dispatcherBar;
window.openReassignModal = openReassignModal;

// ---- Socket.IO (real backend events — single source of truth) ----
const statusEl = document.getElementById("connectionStatus");
const statusTextEl = document.getElementById("statusText");

function setConnectionState(state, label) {
  statusEl.dataset.state = state;
  statusTextEl.textContent = label;
}

const socket = io(BACKEND_URL);

socket.on("connect", () => {
  setConnectionState("connected", "Live");
  socket.emit("join:dispatch");
});

socket.on("disconnect", () => {
  setConnectionState("offline", "Reconnecting…");
});

socket.io.on("reconnect", () => {
  socket.emit("join:dispatch");
  syncAmbulanceSnapshot();
});

// Pulls a request payload (from requestPayload(), whatever shape it
// really is) into this board's local tracking object, defensively.
// Coordinates ship with every payload now (commit ecfe6ef), so a
// tracked request gets its pulsing pickup pin immediately and its unit
// starts driving as soon as it is assigned.
function toPoint(value) {
  if (!value) return null;
  const lat = Number(value.lat ?? value.latitude);
  const lng = Number(value.lng ?? value.lon ?? value.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng };
}

function isQueuedStatus(status) {
  return /QUEUED/.test(String(status || "").toUpperCase());
}

function trackRequest(payload) {
  if (!payload || !payload.requestId) return;
  const ambulanceId = payload.assignedAmbulance?.id || payload.ambulanceId || null;
  const previous = requests[payload.requestId];

  // The payload carries the unit's authoritative position at assignment
  // time — take it, unless a drive is already underway (that animation
  // owns the position until it lands).
  const ambLocation = toPoint(payload.assignedAmbulance?.location);
  if (ambulanceId && ambulances[ambulanceId] && ambLocation && !animations[ambulanceId]) {
    ambulances[ambulanceId].lat = ambLocation.lat;
    ambulances[ambulanceId].lng = ambLocation.lng;
  }

  const status = payload.status || (previous && previous.status) || null;
  const req = {
    id: payload.requestId,
    status: payload.status,
    phase: payload.phase || (previous && previous.phase) || null,
    ambulanceId,
    pickup: toPoint(payload.pickupLocation) || (previous && previous.pickup) || null,
    pickupAddress: payload.pickupAddress || (previous && previous.pickupAddress) || null,
    callerPhone: payload.callerPhone || (previous && previous.callerPhone) || null,
    description: payload.emergencyDescription || payload.description || (previous && previous.description) || null,
    // Backend-driven booking detail — absent until Ibad adds it, renders
    // automatically when it appears. Nothing here is hardcoded.
    peopleCount: payload.peopleCount ?? (previous && previous.peopleCount) ?? null,
    additionalDetails: payload.additionalDetails || (previous && previous.additionalDetails) || null,
    user: pickUser(payload) || (previous && previous.user) || null,
    hospital: pickHospital(payload) || (previous && previous.hospital) || null,
    hospitalAddress:
      payload.hospitalAddress ?? payload.hospital_address ?? (previous && previous.hospitalAddress) ?? null,
    hospitalName: (payload.hospital && payload.hospital.name) || (previous && previous.hospitalName) || null,
    // Where the call has to be dispatched from after a breakdown. The
    // backend writes dispatch_location/breakdown_location; read both
    // spellings plus camelCase until the payload is finalised.
    breakdownLocation:
      toPoint(payload.breakdownLocation) ||
      toPoint(payload.dispatchLocation) ||
      toPoint(payload.breakdown_location) ||
      (previous && previous.breakdownLocation) ||
      null,
    needsReassignment: (previous && previous.needsReassignment) || false,
    anim: (previous && previous.anim) || { pickupDone: false, hospitalDone: false, running: false, leg: null }
  };
  // A queued call with no unit is exactly the state that needs the
  // dispatcher to pick a replacement; once a unit is attached, clear it.
  req.needsReassignment = !ambulanceId && isQueuedStatus(status);

  if (previous && previous.ambulanceId && previous.ambulanceId !== ambulanceId && previous.anim.running) {
    // Reassigned away mid-drive: stop the old unit's leg where it stands.
    cancelAnimation(previous.ambulanceId);
    previous.anim.running = false;
    previous.anim.leg = null;
  }
  if (req.anim.running && req.anim.leg === "pickup" && req.phase === "TRANSFER") {
    // The driver confirmed pickup while we were still driving there —
    // drop the pickup leg and send the unit on to the hospital instead.
    cancelAnimation(ambulanceId);
    req.anim.running = false;
    req.anim.leg = null;
    req.anim.pickupDone = true;
  }

  requests[payload.requestId] = req;
  if (ambulanceId && ambulances[ambulanceId]) {
    ambulances[ambulanceId].currentRequestId = payload.requestId;
  }
  if (req.hospital) {
    upsertHospitalMarker(req.id, req.hospital);
  }
  upsertRequestPin(req);
  syncRequestAnimation(req);
}

function untrackRequest(requestId) {
  const req = requests[requestId];
  if (req) {
    req.anim.running = false;
    req.anim.leg = null;
    if (req.ambulanceId) {
      // Only stop the unit's drive if it isn't already carrying a newer
      // booking (an out-of-order completion must not kill the next leg).
      const amb = ambulances[req.ambulanceId];
      if (!amb || !amb.currentRequestId || amb.currentRequestId === requestId) {
        cancelAnimation(req.ambulanceId);
      }
    }
    delete requests[requestId];
  }
  removeHospitalMarker(requestId);
  removeRequestPin(requestId);
}

// Every request-lifecycle event (queued, assigned, enRoute, pickedUp,
// patientTransferred, arrived, completed, reassigned) goes through the
// SAME emitRequest() helper on the backend, which fires this one
// `queue.updated` event to the whole dispatch room. The old `queue.new`
// event is completely dead on this backend — don't listen for it.
socket.on("queue.updated", (payload) => {
  if (!payload || !payload.requestId) return;
  if (payload.status === "COMPLETED" || payload.status === "CANCELLED") {
    untrackRequest(payload.requestId);
  } else {
    trackRequest(payload);
    // Breakdown left the call with no unit: pop the nearest-driver picker
    // so the dispatcher can put one on it (backend may have auto-assigned
    // already — then this flag is false and nothing pops).
    const tracked = requests[payload.requestId];
    if (tracked && tracked.needsReassignment && !tracked.ambulanceId) {
      maybeAutoOpenPicker(payload.requestId, {
        breakdown: true,
        reference: tracked.breakdownLocation || tracked.pickup
      });
    }
  }
  renderAll();
});

// Dispatcher-TEST_RESET cancellations are emitted only to the request's
// own room, not to `dispatch`/queue.updated — but the ambulance.updated
// event that always accompanies a freed unit still arrives, and that
// handler already clears out any request tracked against it below.
socket.on("ambulance.updated", (payload) => {
  const amb = ambulances[payload.id];
  if (!amb) return;
  const previousRequestId = amb.currentRequestId;
  const wasBusy = amb.status === STATUS.BUSY;
  const lastPosition = { lat: amb.lat, lng: amb.lng };
  if (payload.status) amb.status = normalizeStatus(payload.status);
  if (payload.lat != null) amb.lat = Number(payload.lat);
  if (payload.lng != null) amb.lng = Number(payload.lng);
  if (payload.unavailableReason !== undefined) amb.reason = payload.unavailableReason;
  if (payload.driver !== undefined) {
    amb.driverId = payload.driver ? payload.driver.id : null;
    amb.driverName = payload.driver ? payload.driver.name : null;
  }
  if (amb.status === STATUS.FREE) {
    amb.currentRequestId = null;
    if (previousRequestId) untrackRequest(previousRequestId);
  } else if (amb.status === STATUS.UNAVAILABLE) {
    // Unit dropped out (driver tapped unavailable, or dispatcher did).
    // The booking is no longer on it — backend re-queues it and/or
    // auto-assigns a replacement, which arrives as queue.updated.
    amb.currentRequestId = null;
    if (wasBusy && previousRequestId && requests[previousRequestId]) {
      const req = requests[previousRequestId];
      req.needsReassignment = true;
      req.breakdownLocation = { lat: lastPosition.lat, lng: lastPosition.lng };
    }
  }
  renderAll();
});

// request.completed also arrives on the per-request room; harmless to
// also handle here in case this tab is the one that was listening to
// a specific request (e.g. after opening it from a search later).
socket.on("request.completed", (payload) => {
  if (payload && payload.requestId) {
    untrackRequest(payload.requestId);
    renderAll();
  }
});

// ---- Login screen ----
// NOT real auth — any input logs in. Swap for a real check now that
// dispatcher records are linked to Supabase Auth IDs on the backend.
document.getElementById("loginSubmit").addEventListener("click", () => {
  const org = document.getElementById("loginOrg").value;
  document.getElementById("orgName").textContent = org;
  document.getElementById("loginScreen").classList.add("is-hidden");
});

// ---- Settings: ambulances + drivers (backend-wired) ----
// Every action below calls a real REST endpoint and surfaces the
// server's message when one isn't available yet. Nothing is faked or
// kept only in the browser: if the backend says no, the panel says so.
//
// Expected endpoints (proposed contract for Ibad — none exist yet):
//   POST   /api/v1/ambulances       { label, driverId? }
//   PATCH  /api/v1/ambulances/:id   { label?, driverId? }
//   DELETE /api/v1/ambulances/:id
//   POST   /api/v1/drivers          { name, phone }
//   PATCH  /api/v1/drivers/:id      { name?, phone? }
//   DELETE /api/v1/drivers/:id
//   PATCH  /api/v1/dispatcher/me    { userId, password }
let settingsStatusTimer = null;
function settingsStatus(message, isError) {
  const el = document.getElementById("settingsStatus");
  if (!el) return;
  el.textContent = message;
  el.classList.toggle("is-error", !!isError);
  if (settingsStatusTimer) clearTimeout(settingsStatusTimer);
  if (message) {
    settingsStatusTimer = setTimeout(() => {
      el.textContent = "";
      el.classList.remove("is-error");
    }, 6000);
  }
}

// Drivers are derived from the loaded ambulances (each carries driver
// id/name/phone from the backend join). There is no "list drivers"
// endpoint yet, so a driver not linked to any ambulance won't show.
function knownDrivers() {
  const seen = new Map();
  Object.values(ambulances).forEach((amb) => {
    if (!amb.driverId) return;
    seen.set(amb.driverId, {
      id: amb.driverId,
      name: amb.driverName,
      phone: amb.driverPhone,
      ambulanceLabel: amb.label
    });
  });
  return Array.from(seen.values());
}

function renderSettingsLists() {
  const ambList = document.getElementById("settingsAmbulanceList");
  const ambulanceValues = Object.values(ambulances);
  ambList.innerHTML = ambulanceValues.length
    ? ambulanceValues
        .map(
          (amb) => `
      <li class="settings-row">
        <span>${amb.label}<span class="settings-row__status">${amb.status}</span></span>
        <span class="settings-row__actions">
          <button class="btn" onclick="editAmbulance('${amb.id}')">Edit</button>
          <button class="btn btn--danger" onclick="removeAmbulance('${amb.id}')">Remove</button>
        </span>
      </li>`
        )
        .join("")
    : `<li class="board-empty">No ambulances yet.</li>`;

  const driverList = document.getElementById("settingsDriverList");
  const driverValues = knownDrivers();
  driverList.innerHTML = driverValues.length
    ? driverValues
        .map(
          (d) => `
      <li class="settings-row">
        <span>${d.name || "Unnamed driver"}<span class="settings-row__status">${d.phone || "no phone"}${
            d.ambulanceLabel ? ` &middot; ${d.ambulanceLabel}` : ""
          }</span></span>
        <span class="settings-row__actions">
          <button class="btn" onclick="editDriver('${d.id}')">Edit</button>
          <button class="btn btn--danger" onclick="removeDriver('${d.id}')">Remove</button>
        </span>
      </li>`
        )
        .join("")
    : `<li class="board-empty">No drivers linked to any ambulance yet.</li>`;
}

async function addAmbulance() {
  const input = document.getElementById("newAmbLabel");
  const label = input.value.trim();
  if (!label) return;
  const res = await apiCall("/api/v1/ambulances", "POST", { label });
  if (!res.ok) return settingsStatus(`Add ambulance failed: ${res.error}`, true);
  input.value = "";
  settingsStatus(`Added ${label}.`);
  await loadAmbulances();
  renderSettingsLists();
}

async function editAmbulance(id) {
  const amb = ambulances[id];
  if (!amb) return;
  const label = window.prompt(`New label for ${amb.label}?`, amb.label);
  if (label === null || !label.trim()) return;
  const res = await apiCall(`/api/v1/ambulances/${id}`, "PATCH", { label: label.trim() });
  if (!res.ok) return settingsStatus(`Edit ambulance failed: ${res.error}`, true);
  settingsStatus("Ambulance updated.");
  await loadAmbulances();
  renderSettingsLists();
}

async function removeAmbulance(id) {
  const amb = ambulances[id];
  if (!amb) return;
  const warning = amb.currentRequestId
    ? `${amb.label} is on a booking. Removing it also drops that booking. Continue?`
    : `Remove ${amb.label}?`;
  if (!window.confirm(warning)) return;
  const res = await apiCall(`/api/v1/ambulances/${id}`, "DELETE");
  if (!res.ok) return settingsStatus(`Remove ambulance failed: ${res.error}`, true);
  if (ambulanceMarkers[id]) {
    map.removeLayer(ambulanceMarkers[id]);
    delete ambulanceMarkers[id];
  }
  cancelAnimation(id);
  if (amb.currentRequestId && requests[amb.currentRequestId]) {
    requests[amb.currentRequestId].anim.running = false;
    requests[amb.currentRequestId].anim.leg = null;
  }
  delete ambulances[id];
  renderAll();
  renderSettingsLists();
  await loadAmbulances();
}

async function addDriver() {
  const nameInput = document.getElementById("newDriverName");
  const phoneInput = document.getElementById("newDriverPhone");
  const name = nameInput.value.trim();
  const phone = phoneInput.value.trim();
  if (!name) return;
  const res = await apiCall("/api/v1/drivers", "POST", { name, phone });
  if (!res.ok) return settingsStatus(`Add driver failed: ${res.error}`, true);
  nameInput.value = "";
  phoneInput.value = "";
  settingsStatus(`Added driver ${name}.`);
  await loadAmbulances();
  renderSettingsLists();
}

async function editDriver(id) {
  const driver = knownDrivers().find((d) => d.id === id);
  const name = window.prompt("Driver name?", driver ? driver.name || "" : "");
  if (name === null || !name.trim()) return;
  const phone = window.prompt("Driver phone?", driver ? driver.phone || "" : "");
  if (phone === null) return;
  const res = await apiCall(`/api/v1/drivers/${id}`, "PATCH", { name: name.trim(), phone: phone.trim() });
  if (!res.ok) return settingsStatus(`Edit driver failed: ${res.error}`, true);
  settingsStatus("Driver updated.");
  await loadAmbulances();
  renderSettingsLists();
}

async function removeDriver(id) {
  if (!window.confirm("Remove this driver?")) return;
  const res = await apiCall(`/api/v1/drivers/${id}`, "DELETE");
  if (!res.ok) return settingsStatus(`Remove driver failed: ${res.error}`, true);
  settingsStatus("Driver removed.");
  await loadAmbulances();
  renderSettingsLists();
}

window.removeAmbulance = removeAmbulance;
window.removeDriver = removeDriver;
window.editAmbulance = editAmbulance;
window.editDriver = editDriver;

document.getElementById("settingsOpenBtn").addEventListener("click", () => {
  renderSettingsLists();
  document.getElementById("settingsModal").classList.add("is-open");
});

document.getElementById("settingsClose").addEventListener("click", () => {
  document.getElementById("settingsModal").classList.remove("is-open");
});

document.getElementById("addAmbulanceBtn").addEventListener("click", addAmbulance);
document.getElementById("addDriverBtn").addEventListener("click", addDriver);

document.getElementById("settingsSaveCreds").addEventListener("click", async () => {
  const userId = document.getElementById("settingsUserId").value.trim();
  const password = document.getElementById("settingsPassword").value.trim();
  if (!userId && !password) return settingsStatus("Enter a user ID or a new password first.", true);
  const res = await apiCall("/api/v1/dispatcher/me", "PATCH", { userId, password });
  if (!res.ok) return settingsStatus(`Couldn't update credentials: ${res.error}`, true);
  document.getElementById("settingsPassword").value = "";
  settingsStatus("Credentials updated.");
});

// ---- Boot ----
initMap();
loadHospitals();
loadAmbulances();

// Keep the map live even if a socket event is missed (driver phones vary).
setInterval(syncAmbulanceSnapshot, 15000);

// =====================================================================
// CONFIRMED against the real server.js (the version importing from
// ./dispatch — assignNearest/assignSpecific/closeActiveAssignment/
// dispatchQueuedForAmbulance/getRequest/requestPayload):
//
//   - Ambulance status values are FREE / BUSY / UNAVAILABLE. All three
//     tabs are real now.
//   - GET /api/v1/ambulances LEFT JOINs drivers: driverId, driverName,
//     driverPhone come back nullable, per ambulance. There is still no
//     bulk "list all drivers" endpoint (only GET
//     /api/v1/drivers/:driverId/portal, for a single driver's own
//     view) — the driver-centric board here is derived entirely from
//     the ambulances endpoint.
//   - queue.new is COMPLETELY DEAD. Every request-lifecycle event
//     (queued, assigned, enRoute, pickedUp, patientTransferred,
//     arrived, completed, reassigned) now flows through one unified
//     `queue.updated` event on the dispatch room, via the shared
//     emitRequest() helper.
//   - Reassign is real: POST /api/v1/emergency-requests/:id/assign
//     { ambulanceId }.
//   - Bar is real: POST
//     /api/v1/emergency-requests/:id/blocked-ambulances
//     { ambulanceId, reason }.
//   - Dispatcher-triggered Mark free / Mark unavailable:
//       Mark free        -> PATCH /api/v1/ambulances/:id/status
//                           { status: "FREE", force: true }
//       Mark unavailable -> PATCH /api/v1/drivers/:driverId/unavailable
//                           { reason, lat, lng }  (falls back to
//                           PATCH /ambulances/:id/status
//                           { status: "UNAVAILABLE", force: true } when
//                           the unit has no driver linked)
//     force:true is mandatory on the status route: the handler 409s with
//     "BUSY ambulance requires force=true for a test reset" without it,
//     and WITH it the backend cancels that unit's ACTIVE booking in the
//     same transaction — which is exactly what makes "Mark free" work on
//     a mid-booking unit.
//   - Driver-triggered pickup/dropoff/unavailable/available all live
//     on PATCH /api/v1/drivers/:driverId/... routes. The board now also
//     calls the unavailable one, for dispatcher overrides; it reacts to
//     the ambulance.updated / queue.updated events those routes produce.
//   - Driver location ticks (PATCH /drivers/:id/location) write
//     straight onto the driver's one linked ambulance row and emit
//     ambulance.updated. While a booking leg is being animated the
//     animation owns the marker position; ticks arriving outside an
//     animation update the marker as before. A 15s snapshot reconcile
//     (syncAmbulanceSnapshot) keeps free + on-call positions live even
//     if a socket tick is missed.
//
// BREAKDOWN / MID-BOOKING UNAVAILABLE (backend already implements this):
// PATCH /api/v1/drivers/:id/unavailable does more than flip a flag — it
// closes the active assignment, re-queues the request from the unit's
// current position (PICKUP -> QUEUED, TRANSFER -> TRANSFER_QUEUED),
// stores dispatch_location/breakdown_location on the request, calls
// assignNearest for an automatic replacement, and returns
// { ambulanceId, status: "UNAVAILABLE", replacementRequestId }.
// This board: (a) turns BUSY->UNAVAILABLE into a "needs reassignment"
// flag on the tracked booking, (b) pops the nearest-driver picker when
// the backend leaves the call QUEUED (nothing to override), and (c) lets
// the dispatcher override the auto-assignment via the same picker.
//
// STILL EXPECTED FROM THE BACKEND (frontend is already written to read
// these; nothing is hardcoded, so they simply don't render until then):
//   - requestPayload() should include the caller: user { id, name, phone }
//     (the users table exists; emergency_requests.user_id is not set for
//     ambulance bookings yet). The board also reads flat userId/userName.
//   - requestPayload() should include breakdownLocation/dispatchLocation
//     { lat, lng } after an unavailable-mid-booking so the picker can
//     sort from the real breakdown point.
//   - CRUD endpoints for the Settings panel (POST/PATCH/DELETE
//     /api/v1/ambulances, /api/v1/drivers, PATCH /api/v1/dispatcher/me).
//     The panel calls them and shows the server's error until they exist.
//
// COORDINATES + HOSPITALS: landed on main in commit ecfe6ef ("backend
// connect and some other things") and already deployed to production.
// requestPayload() now selects ST_Y/ST_X of r.pickup_location and
// r.hospital_location and returns pickupLocation { lat, lng } plus
// hospital { id, name, address, location }. Alongside it, GET
// /api/v1/hospitals returns { id, name, address, lat, lng } for active
// rows, which loadHospitals() consumes at boot. Verified live on
// 2026-10-09 (9 hospitals returned; a real ASSIGNED request payload
// carries pickupLocation). Nothing further is needed from the backend
// for the six dispatcher items — the earlier patch note is obsolete.
// =====================================================================