// =====================================================================
// Madad+ Dispatcher — ambulance board, driven entirely by the real
// backend now that Ibad has a real schema (hospitals, provider data,
// Supabase Auth links) and the real booking flow is: user books ->
// dispatcher auto-assigns a driver -> driver is tied to a distinct
// ambulance. All client-side booking SIMULATION has been removed.
//
// This board now only ever shows what the backend actually reports via
// GET /api/v1/ambulances and the `dispatch` socket room. It never
// invents a booking, a destination, or a movement animation itself.
//
// Driver actions (pickup, dropoff, reporting unavailable) live on Zain's
// driver app, not here. This board only keeps three genuine dispatcher
// overrides: Reassign, Bar this unit, and Mark free. Each attempts a
// real backend call using the best-guess endpoint shape proposed at the
// bottom of this file — update those paths once Ibad confirms the real
// routes, since they aren't confirmed yet.
// =====================================================================

// ---- Config ----
const BACKEND_URL = "https://madadplus.onrender.com";

// DHA Phase 5, Karachi — matches the seed coordinates.
const DEFAULT_CENTER = { lat: 24.8000, lng: 67.0500 };

const organizationBases = [
  { name: "Edhi Foundation", lat: 24.84870, lng: 66.99575 },
  { name: "Al Khidmat Hospital", lat: 24.81281, lng: 67.00897 },
];

const STATUS = { FREE: "FREE", BUSY: "BUSY", UNAVAILABLE: "UNAVAILABLE" };

const STATUS_COLOR = {
  FREE: "#16a34a",
  BUSY: "#b45309",
  UNAVAILABLE: "#dc2626"
};

// ---- State ----
let map = null;
const ambulanceMarkers = {};  // ambulance id -> L.Marker
const ambulances = {};        // ambulance id -> { id, label, status, lat, lng, reason, currentRequestId }
const requests = {};          // request id -> whatever the backend's `queue.new` event sent us

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

// ---- Map ----
function initMap() {
  map = L.map("map", { zoomControl: true }).setView([DEFAULT_CENTER.lat, DEFAULT_CENTER.lng], 14);

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19
  }).addTo(map);

  organizationBases.forEach((base) => {
    L.marker([base.lat, base.lng], {
      icon: L.divIcon({
        className: "organization-marker",
        html: "+",
        iconSize: [22, 22],
        iconAnchor: [11, 11]
      })
    })
      .bindTooltip(base.name)
      .addTo(map);
  });
}

// Small inline SVG ambulance icon, color-coded by status.
function ambulanceIconHtml(status) {
  const color = STATUS_COLOR[status] || STATUS_COLOR.UNAVAILABLE;
  return `
    <svg width="30" height="30" viewBox="0 0 30 30" xmlns="http://www.w3.org/2000/svg">
      <circle cx="15" cy="15" r="13.5" fill="${color}" stroke="#ffffff" stroke-width="2.5" />
      <g transform="translate(6.5,9.5)">
        <rect x="0" y="2.5" width="17" height="7.5" rx="1.4" fill="#ffffff" />
        <rect x="11.5" y="0" width="5.5" height="5.5" rx="1" fill="#ffffff" />
        <circle cx="3.6" cy="11.2" r="1.5" fill="${color}" />
        <circle cx="13" cy="11.2" r="1.5" fill="${color}" />
        <rect x="2.8" y="4.6" width="3.6" height="1.3" fill="${color}" />
        <rect x="4.1" y="3.3" width="1.3" height="3.6" fill="${color}" />
      </g>
    </svg>`;
}

function ambulanceIcon(status) {
  return L.divIcon({
    className: "ambulance-marker",
    html: ambulanceIconHtml(status),
    iconSize: [30, 30],
    iconAnchor: [15, 15]
  });
}

function upsertAmbulanceMarker(amb) {
  if (!map) return;
  const latlng = [amb.lat, amb.lng];
  if (ambulanceMarkers[amb.id]) {
    ambulanceMarkers[amb.id].setLatLng(latlng);
    ambulanceMarkers[amb.id].setIcon(ambulanceIcon(amb.status));
  } else {
    ambulanceMarkers[amb.id] = L.marker(latlng, { icon: ambulanceIcon(amb.status) })
      .bindTooltip(`${amb.label} — ${amb.status}`)
      .addTo(map);
  }
  ambulanceMarkers[amb.id].setTooltipContent(`${amb.label} — ${amb.status}`);
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
        reason: a.unavailable_reason || a.reason || null,
        currentRequestId: null,
        // Driver/user detail fields below are guesses pending the real
        // payload shape from Ibad — rendering code checks these
        // defensively and falls back gracefully if they're absent.
        driver: a.driver || null
      };
      upsertAmbulanceMarker(ambulances[a.id]);
    });
    renderAll();
  } catch (err) {
    console.error("Could not load ambulances:", err);
  }
}

// ---- Dispatcher overrides (real backend calls — endpoint paths are a
// best guess until Ibad confirms the actual routes; see the contract
// note at the bottom of this file) ----
async function dispatcherReassign(requestId, newAmbulanceId) {
  closeReassignModal();
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/emergency-requests/${requestId}/reassign`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ambulanceId: newAmbulanceId })
    });
    if (!res.ok) throw new Error(`Reassign failed: ${res.status}`);
    // Backend should re-broadcast the updated state over the dispatch
    // socket room — this board just waits for that rather than guessing.
  } catch (err) {
    console.error(err);
    window.alert("Reassign isn't supported by the backend yet — ask Ibad to add PATCH /api/v1/emergency-requests/:id/reassign.");
  }
}

async function dispatcherBar(requestId, ambulanceId) {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/emergency-requests/${requestId}/bar`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ambulanceId })
    });
    if (!res.ok) throw new Error(`Bar failed: ${res.status}`);
  } catch (err) {
    console.error(err);
    window.alert("Barring a unit isn't supported by the backend yet — ask Ibad to add PATCH /api/v1/emergency-requests/:id/bar.");
  }
}

async function dispatcherMarkFree(ambulanceId) {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/ambulances/${ambulanceId}/status`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status: "FREE" })
    });
    if (!res.ok) throw new Error(`Mark free failed: ${res.status}`);
  } catch (err) {
    console.error(err);
    window.alert("Manually freeing a unit isn't supported by the backend yet — the only way AVAILABLE gets set today is automatically, via PATCH .../complete.");
  }
}

// ---- Reassign modal ----
let reassignTargetRequestId = null;

function openReassignModal(reqId) {
  reassignTargetRequestId = reqId;
  const req = requests[reqId];
  const freeUnits = Object.values(ambulances).filter((a) => a.status === STATUS.FREE);

  document.getElementById("reassignSub").textContent = freeUnits.length
    ? "Pick a free unit to put on this call instead:"
    : "No free units available right now.";

  const list = document.getElementById("reassignList");
  list.innerHTML = "";
  freeUnits.forEach((amb) => {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    const distLabel =
      req && req.pickup ? `${haversineKm({ lat: amb.lat, lng: amb.lng }, req.pickup).toFixed(2)} km away` : "distance unknown";
    btn.textContent = `${amb.label} — ${distLabel}`;
    btn.onclick = () => dispatcherReassign(reqId, amb.id);
    li.appendChild(btn);
    list.appendChild(li);
  });

  document.getElementById("reassignModal").classList.add("is-open");
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

// ---- Rendering ----
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
    el.innerHTML = `<li class="board-empty">No free units right now.</li>`;
    return;
  }
  el.innerHTML = free
    .map(
      (amb) => `
      <li class="amb-card">
        <div>
          <div class="amb-card__label">${amb.label}</div>
          <div class="amb-card__meta">${amb.driver ? amb.driver.name || amb.driver : "Idle"} &middot; ready for dispatch</div>
        </div>
      </li>`
    )
    .join("");
}

function renderBusyList() {
  const el = document.getElementById("listBusy");
  const busyRequests = Object.values(requests).filter((r) => r.ambulanceId && ambulances[r.ambulanceId]);

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
          <div class="amb-card__label">${amb.label}</div>
          <div class="amb-card__meta">Busy &middot; no booking details available</div>
        </div>
        <button class="btn btn--free" onclick="dispatcherMarkFree('${amb.id}')">Mark free</button>
      </li>`
    )
    .join("");

  const busyHtml = busyRequests
    .map((req) => {
      const amb = ambulances[req.ambulanceId];
      // These fields are guesses pending the real `queue.new` payload
      // shape — render defensively so nothing breaks if they're absent.
      const driverName = req.driver?.name || req.driverName || null;
      const userName = req.user?.name || req.userName || null;
      const description = req.description || req.emergencyDescription || null;

      return `
        <li class="booking-card">
          <div class="booking-card__top">
            <span class="booking-card__id">${shortId(req.id)}</span>
            <span class="booking-card__leg">${req.status || "ASSIGNED"}</span>
          </div>
          <div class="booking-card__main">
            <strong>${amb.label}</strong>${driverName ? ` &middot; ${driverName}` : ""} on this call
            ${userName ? `<br/>Caller: ${userName}` : ""}
            ${description ? `<br/>${description}` : ""}
          </div>
          ${req.switchNote ? `<div class="booking-card__note">${req.switchNote}</div>` : ""}
          <div class="booking-card__actions">
            <button class="btn" onclick="openReassignModal('${req.id}')">Reassign</button>
            <button class="btn btn--danger" onclick="dispatcherBar('${req.id}','${amb.id}')">Bar this unit</button>
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
          <div class="amb-card__label">${amb.label}</div>
          <div class="amb-card__reason">${amb.reason || "Unavailable"}</div>
        </div>
        <button class="btn btn--free" onclick="dispatcherMarkFree('${amb.id}')">Mark free</button>
      </li>`
    )
    .join("");
}

window.dispatcherMarkFree = dispatcherMarkFree;
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
});

// The backend's own status strings are AVAILABLE / BUSY (confirmed from
// server.js — there's no UNAVAILABLE support there yet). This board's
// internal STATUS constants use FREE instead of AVAILABLE, so every
// status coming off the wire has to pass through here — never assign
// a raw backend status string to amb.status directly.
function normalizeStatus(rawStatus) {
  if (rawStatus === "BUSY") return STATUS.BUSY;
  if (rawStatus === "UNAVAILABLE") return STATUS.UNAVAILABLE;
  return STATUS.FREE; // covers "AVAILABLE" and anything else
}

// A real call came in from the backend. Everything beyond requestId/
// status/assignedAmbulance/consideredNearest below (pickup location,
// driver, caller details) is rendered defensively since confirmed
// server.js doesn't send them yet — these fields simply won't appear
// until Ibad adds them to the POST /emergency-requests response.
socket.on("queue.new", (payload) => {
  if (!payload.assignedAmbulance) return;
  const amb = ambulances[payload.assignedAmbulance.id];
  if (!amb) return;
  amb.status = STATUS.BUSY;
  amb.currentRequestId = payload.requestId;
  requests[payload.requestId] = {
    id: payload.requestId,
    pickup: payload.pickupLocation || payload.pickup || null,
    status: payload.status || "ASSIGNED",
    ambulanceId: amb.id,
    driver: payload.driver || null,
    user: payload.user || null,
    description: payload.description || payload.emergencyDescription || null,
    switchNote: payload.consideredNearest
      ? `${payload.consideredNearest.label} was closer but ${payload.consideredNearest.status.toLowerCase()} — switched to ${amb.label}.`
      : null
  };
  renderAll();
});

// Confirmed real: fired by PATCH .../en-route and PATCH .../arrived.
// Updates the booking's status label on the board (e.g. "EN_ROUTE",
// "ARRIVED") — these are driver-triggered on Zain's app, this board
// only ever listens, never triggers them.
socket.on("queue.updated", (payload) => {
  if (!payload || !payload.requestId) return;
  const req = requests[payload.requestId];
  if (req) req.status = payload.status;
  renderAll();
});

socket.on("ambulance.updated", (payload) => {
  const amb = ambulances[payload.id];
  if (!amb) return;
  const previousRequestId = amb.currentRequestId;
  if (payload.status) amb.status = normalizeStatus(payload.status);
  if (payload.lat != null) amb.lat = Number(payload.lat);
  if (payload.lng != null) amb.lng = Number(payload.lng);
  if (payload.reason !== undefined) amb.reason = payload.reason;
  if (amb.status === STATUS.FREE) {
    amb.currentRequestId = null;
    if (previousRequestId && requests[previousRequestId]) delete requests[previousRequestId];
  }
  renderAll();
});

// Confirmed real: fired by PATCH .../complete. Removes the booking from
// the active board — the ambulance itself frees up via a separate
// ambulance.updated event the backend sends right alongside this one.
socket.on("request.completed", (payload) => {
  if (payload && payload.requestId && requests[payload.requestId]) {
    delete requests[payload.requestId];
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

// ---- Settings: ambulances + drivers (LOCAL-ONLY for now) ----
// Ibad's backend doesn't have CRUD endpoints for ambulances/drivers yet.
// This is a local-only management utility — nothing added or removed
// here is saved to the backend. Swap for real API calls once those
// endpoints exist.
const drivers = {}; // driver id -> { id, name, phone, assignedAmbulanceId }

function genLocalId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 8)}`;
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
        <button class="btn btn--danger" onclick="removeAmbulance('${amb.id}')">Remove</button>
      </li>`
        )
        .join("")
    : `<li class="board-empty">No ambulances yet.</li>`;

  const driverList = document.getElementById("settingsDriverList");
  const driverValues = Object.values(drivers);
  driverList.innerHTML = driverValues.length
    ? driverValues
        .map(
          (d) => `
      <li class="settings-row">
        <span>${d.name}<span class="settings-row__status">${d.phone || "no phone"}</span></span>
        <button class="btn btn--danger" onclick="removeDriver('${d.id}')">Remove</button>
      </li>`
        )
        .join("")
    : `<li class="board-empty">No drivers yet.</li>`;
}

function addAmbulance() {
  const input = document.getElementById("newAmbLabel");
  const label = input.value.trim();
  if (!label) return;
  const id = genLocalId("amb");
  ambulances[id] = {
    id,
    label,
    status: STATUS.FREE,
    lat: DEFAULT_CENTER.lat,
    lng: DEFAULT_CENTER.lng,
    reason: null,
    currentRequestId: null,
    driver: null
  };
  input.value = "";
  upsertAmbulanceMarker(ambulances[id]);
  renderAll();
  renderSettingsLists();
}

function removeAmbulance(id) {
  const amb = ambulances[id];
  if (!amb) return;
  if (amb.currentRequestId && !window.confirm(`${amb.label} is currently on a booking. Remove it anyway?`)) {
    return;
  }
  if (ambulanceMarkers[id]) {
    map.removeLayer(ambulanceMarkers[id]);
    delete ambulanceMarkers[id];
  }
  delete ambulances[id];
  renderAll();
  renderSettingsLists();
}

function addDriver() {
  const nameInput = document.getElementById("newDriverName");
  const phoneInput = document.getElementById("newDriverPhone");
  const name = nameInput.value.trim();
  const phone = phoneInput.value.trim();
  if (!name) return;
  const id = genLocalId("drv");
  drivers[id] = { id, name, phone, assignedAmbulanceId: null };
  nameInput.value = "";
  phoneInput.value = "";
  renderSettingsLists();
}

function removeDriver(id) {
  delete drivers[id];
  renderSettingsLists();
}

window.removeAmbulance = removeAmbulance;
window.removeDriver = removeDriver;

document.getElementById("settingsOpenBtn").addEventListener("click", () => {
  renderSettingsLists();
  document.getElementById("settingsModal").classList.add("is-open");
});

document.getElementById("settingsClose").addEventListener("click", () => {
  document.getElementById("settingsModal").classList.remove("is-open");
});

document.getElementById("addAmbulanceBtn").addEventListener("click", addAmbulance);
document.getElementById("addDriverBtn").addEventListener("click", addDriver);

document.getElementById("settingsSaveCreds").addEventListener("click", () => {
  document.getElementById("settingsCredsNote").textContent =
    "Saved for this session — not yet connected to a real account.";
});

// ---- Boot ----
initMap();
loadAmbulances();

// =====================================================================
// CONFIRMED against the real server.js (as of the version Ahmed shared):
//   - Ambulance status values are AVAILABLE / BUSY. No UNAVAILABLE
//     support exists yet (no column read, no endpoint) — the
//     Unavailable tab being empty right now is correct, not a bug.
//   - Real request lifecycle: ASSIGNED -> EN_ROUTE -> ARRIVED -> COMPLETED,
//     via PATCH .../en-route, PATCH .../arrived, PATCH .../complete.
//     All three are driver-triggered on Zain's app; this board only
//     listens to their resulting queue.updated / request.completed /
//     ambulance.updated events, never calls them itself.
//   - queue.new payload is still just { requestId, status,
//     assignedAmbulance: {id,label,distanceKm}, consideredNearest }.
//     No pickup location, driver, or caller info yet — the defensive
//     fallbacks in socket.on("queue.new", ...) and renderBusyList()
//     will start showing real data the moment Ibad adds those fields.
//
// STILL MISSING (confirmed absent, not just unconfirmed):
//   - PATCH /api/v1/emergency-requests/:id/reassign { ambulanceId }
//   - PATCH /api/v1/emergency-requests/:id/bar      { ambulanceId }
//   - Any endpoint to manually set AVAILABLE/UNAVAILABLE — today
//     AVAILABLE only ever gets set automatically inside /complete.
// These three are what Reassign / Bar this unit / Mark free call —
// until they exist, those buttons will correctly show a "not
// supported yet" alert rather than pretending to succeed.
// =====================================================================