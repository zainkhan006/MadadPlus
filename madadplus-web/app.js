// =====================================================================
// Madad+ Dispatcher — ambulance board, live simulated tracking, and
// dispatcher-only overrides.
//
// DRIVER ACTIONS LIVE ON ZAIN'S DRIVER APP, NOT HERE.
// Mark picked up, confirming dropoff, and reporting unavailable are all
// real driver actions that belong on the driver's phone. Buttons on this
// board labeled "(test)" are a stand-in for those, so you can exercise
// the whole board solo until Ibad's backend and Zain's driver app are
// actually wired together — delete them once that integration is real.
// Reassign, Bar this unit, and Mark Free are genuine dispatcher
// overrides and stay regardless of integration status.
//
// No fixed hospital location: the real system never hardcodes a
// destination — a driver drives wherever they actually go and marks
// Free on arrival. The "test" pickup button below simulates a drive to
// an unspecified nearby point purely for visual demo purposes; nothing
// about it is stored or treated as a real hospital location.
// =====================================================================

// ---- Config ----
const BACKEND_URL = "https://madadplus.onrender.com";

// DHA Phase 5, Karachi — matches the seed coordinates.
const DEFAULT_CENTER = { lat: 24.8000, lng: 67.0500 };

const STATUS = { FREE: "FREE", BUSY: "BUSY", UNAVAILABLE: "UNAVAILABLE" };
const LEG = { TO_PICKUP: "TO_PICKUP", TRANSFER: "TRANSFER", TO_HOSPITAL: "TO_HOSPITAL" };

const STATUS_COLOR = {
  FREE: "#34d399",
  BUSY: "#f5a623",
  UNAVAILABLE: "#e5484d"
};

const PICKUP_DRIVE_MS = 8000;
const HOSPITAL_DRIVE_MS = 10000;
const TRANSFER_DRIVE_MS = 6000;

// Purely for the "(test)" pickup simulation — picks a random nearby point
// to animate toward, standing in for wherever a real driver would actually
// drive. Never persisted, never a real hospital location.
function randomNearbyPoint(from, maxKm) {
  const dLat = (Math.random() - 0.5) * (maxKm / 111);
  const dLng = (Math.random() - 0.5) * (maxKm / (111 * Math.cos((from.lat * Math.PI) / 180)));
  return { lat: from.lat + dLat, lng: from.lng + dLng };
}

// ---- State ----
let map = null;
const ambulanceMarkers = {};  // ambulance id -> L.circleMarker
const ambulances = {};        // ambulance id -> { id, label, status, lat, lng, reason, currentRequestId }
const requests = {};          // request id -> booking object
const animations = {};        // ambulance id -> { cancelled }
const waitQueue = [];         // requests with no ambulance available yet
let activeTab = "FREE";
let reassignTargetRequestId = null;

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

function findNearestFree(point, excludeIds = []) {
  let best = null;
  let bestDist = Infinity;
  Object.values(ambulances).forEach((amb) => {
    if (amb.status !== STATUS.FREE) return;
    if (excludeIds.includes(amb.id)) return;
    const d = haversineKm(point, { lat: amb.lat, lng: amb.lng });
    if (d < bestDist) {
      bestDist = d;
      best = amb;
    }
  });
  return best;
}

function shortId(id) {
  return `#${String(id).slice(0, 6)}`;
}

function genRequestId() {
  return `req-${Math.random().toString(36).slice(2, 8)}`;
}

function agentLog(hypothesisId, location, message, data) {
  // #region agent log
  fetch('http://127.0.0.1:7305/ingest/3123ab15-a865-40c1-9544-a2717b4e7d1d',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'2302e5'},body:JSON.stringify({sessionId:'2302e5',runId:'pre-fix',hypothesisId,location,message,data,timestamp:Date.now()})}).catch(()=>{});
  // #endregion
}

// ---- Animation (simulated live tracking, following real roads) ----
const routeLines = {}; // ambulance id -> L.Polyline (the visible route path)

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

// Free public OSRM demo server — no API key, follows real road geometry.
// Falls back to a straight line if the request fails or times out, so a
// flaky network never breaks the demo, it just looks less precise.
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

// Animates a marker along a multi-point route at constant speed, rather
// than teleporting in a straight line between two points.
function animateAlongRoute(ambulanceId, routePoints, durationMs, onComplete) {
  cancelAnimation(ambulanceId);
  const anim = { cancelled: false };
  animations[ambulanceId] = anim;

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
    if (anim.cancelled) return;
    const t = Math.min(1, (now - start) / durationMs);
    const pos = pointAtFraction(t);

    const amb = ambulances[ambulanceId];
    if (amb) {
      amb.lat = pos.lat;
      amb.lng = pos.lng;
    }
    updateMarkerPosition(ambulanceId, pos);

    if (t < 1) {
      requestAnimationFrame(step);
    } else {
      clearRouteLine(ambulanceId);
      if (onComplete) onComplete();
    }
  }
  requestAnimationFrame(step);
}

// Fetches a real road route, draws it, then animates the marker along it.
async function driveAmbulanceTo(ambulanceId, destination, durationMs, onComplete) {
  const amb = ambulances[ambulanceId];
  if (!amb) return;
  const from = { lat: amb.lat, lng: amb.lng };
  const route = await fetchRoute(from, destination);
  if (!ambulances[ambulanceId]) return; // ambulance no longer exists by the time the route arrives
  drawRouteLine(ambulanceId, route);
  animateAlongRoute(ambulanceId, route, durationMs, onComplete);
}

// ---- Map ----
function initMap() {
  map = L.map("map", { zoomControl: true }).setView([DEFAULT_CENTER.lat, DEFAULT_CENTER.lng], 14);

  // Plain OpenStreetMap tiles — light basemap, free, no API key.
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19
  }).addTo(map);

  map.on("click", (e) => {
    simulateNewCall({ lat: e.latlng.lat, lng: e.latlng.lng });
  });
}

function markerStyle(status) {
  return {
    radius: 8,
    fillColor: STATUS_COLOR[status] || STATUS_COLOR.UNAVAILABLE,
    color: "#171d26",
    weight: 2,
    fillOpacity: 1
  };
}

function updateMarkerPosition(id, latlng) {
  const marker = ambulanceMarkers[id];
  if (marker) marker.setLatLng([latlng.lat, latlng.lng]);
}

function upsertAmbulanceMarker(amb) {
  if (!map) return;
  const latlng = [amb.lat, amb.lng];
  if (ambulanceMarkers[amb.id]) {
    ambulanceMarkers[amb.id].setLatLng(latlng);
    ambulanceMarkers[amb.id].setStyle(markerStyle(amb.status));
  } else {
    ambulanceMarkers[amb.id] = L.circleMarker(latlng, markerStyle(amb.status))
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
        status: a.status === "BUSY" ? STATUS.BUSY : a.status === "UNAVAILABLE" ? STATUS.UNAVAILABLE : STATUS.FREE,
        lat: Number(a.lat),
        lng: Number(a.lng),
        reason: null,
        currentRequestId: null
      };
      upsertAmbulanceMarker(ambulances[a.id]);
    });
    renderAll();
    // #region agent log
    agentLog('A', 'app.js:loadAmbulances', 'server ambulance statuses', {statuses: list.map((a) => ({label: a.label, status: a.status}))});
    // #endregion
  } catch (err) {
    console.error("Could not load ambulances:", err);
  }
}

// ---- Booking lifecycle ----
function simulateNewCall(pickup) {
  const req = {
    id: genRequestId(),
    pickup,
    status: "QUEUED",
    leg: null,
    ambulanceId: null,
    switchNote: null,
    barred: new Set()
  };
  requests[req.id] = req;

  const nearest = findNearestFree(pickup, [...req.barred]);
  // #region agent log
  agentLog('B', 'app.js:simulateNewCall', 'map click is local only', {requestId: req.id, nearestLabel: nearest ? nearest.label : null});
  // #endregion
  if (nearest) {
    assignAmbulanceToRequest(nearest, req);
  } else {
    req.status = "WAITING";
    waitQueue.push(req);
    renderAll();
  }
}

function assignAmbulanceToRequest(amb, req) {
  amb.status = STATUS.BUSY;
  amb.currentRequestId = req.id;
  req.ambulanceId = amb.id;
  req.leg = LEG.TO_PICKUP;
  req.status = "ASSIGNED";

  driveAmbulanceTo(amb.id, req.pickup, PICKUP_DRIVE_MS);
  renderAll();
}

function markPickedUp(reqId) {
  const req = requests[reqId];
  if (!req) return;
  const amb = ambulances[req.ambulanceId];
  if (!amb) return;

  req.leg = LEG.TO_HOSPITAL;
  req.status = "PICKED_UP";
  // Test-mode stand-in for a real driver's route — see file header.
  const simulatedDestination = randomNearbyPoint({ lat: amb.lat, lng: amb.lng }, 4);
  driveAmbulanceTo(amb.id, simulatedDestination, HOSPITAL_DRIVE_MS);
  renderAll();
}

function markDropoff(reqId) {
  const req = requests[reqId];
  if (!req) return;
  const amb = ambulances[req.ambulanceId];

  req.status = "COMPLETED";
  cancelAnimation(req.ambulanceId);
  delete requests[reqId];

  if (amb) {
    amb.status = STATUS.FREE;
    amb.currentRequestId = null;
    onAmbulanceBecameFree(amb);
  }
  renderAll();
}

function confirmTransfer(reqId) {
  const req = requests[reqId];
  if (!req) return;
  const amb = ambulances[req.ambulanceId];
  if (!amb) return;

  req.leg = LEG.TO_HOSPITAL;
  req.switchNote = `Patient transferred into ${amb.label} — continuing toward the hospital.`;
  const simulatedDestination = randomNearbyPoint({ lat: amb.lat, lng: amb.lng }, 4);
  driveAmbulanceTo(amb.id, simulatedDestination, HOSPITAL_DRIVE_MS);
  renderAll();
}

// ---- Unavailable handling (three cases) ----
function markUnavailable(ambId, reason) {
  const amb = ambulances[ambId];
  if (!amb) return;

  const reqId = amb.currentRequestId;
  amb.status = STATUS.UNAVAILABLE;
  amb.reason = reason || "Unavailable";
  amb.currentRequestId = null;
  cancelAnimation(ambId);

  if (!reqId) {
    // Case 1 — unavailable before any booking. Just moves tabs, excluded from matching.
    renderAll();
    return;
  }

  const req = requests[reqId];

  if (req.leg === LEG.TO_PICKUP) {
    // Case 2 — broke down before pickup. Auto-assign nearest FREE unit to the caller's address.
    req.barred.add(ambId);
    const replacement = findNearestFree(req.pickup, [...req.barred]);
    req.switchNote = `${amb.label} had a problem (${amb.reason}) — switched to the next-nearest available unit.`;
    if (replacement) {
      assignAmbulanceToRequest(replacement, req);
    } else {
      req.status = "WAITING";
      req.ambulanceId = null;
      req.leg = null;
      waitQueue.push(req);
    }
  } else if (req.leg === LEG.TO_HOSPITAL) {
    // Case 3 — broke down after pickup, patient already aboard. Nearest FREE unit
    // goes to the BROKEN ambulance's current position to transfer the patient.
    req.barred.add(ambId);
    const brokenLocation = { lat: amb.lat, lng: amb.lng };
    const replacement = findNearestFree(brokenLocation, [...req.barred]);
    req.switchNote = `${amb.label} had an emergency mid-route (${amb.reason}) — a unit is transferring the patient.`;
    if (replacement) {
      req.leg = LEG.TRANSFER;
      req.ambulanceId = replacement.id;
      replacement.status = STATUS.BUSY;
      replacement.currentRequestId = req.id;
      driveAmbulanceTo(replacement.id, brokenLocation, TRANSFER_DRIVE_MS);
    } else {
      req.status = "WAITING_TRANSFER";
      req.ambulanceId = null;
      waitQueue.push(req);
    }
  }

  renderAll();
}

function manualFree(ambId) {
  const amb = ambulances[ambId];
  if (!amb) return;
  amb.status = STATUS.FREE;
  amb.reason = null;
  amb.currentRequestId = null;
  // #region agent log
  agentLog('A', 'app.js:manualFree', 'mark free is local only', {label: amb.label});
  // #endregion
  renderAll();
  onAmbulanceBecameFree(amb);
}

// "First unit that turns FREE goes to the nearest waiting call, even if far."
function onAmbulanceBecameFree(amb) {
  if (waitQueue.length === 0) return;
  let bestIdx = -1;
  let bestDist = Infinity;
  waitQueue.forEach((req, idx) => {
    if (req.barred.has(amb.id)) return;
    const d = haversineKm({ lat: amb.lat, lng: amb.lng }, req.pickup);
    if (d < bestDist) {
      bestDist = d;
      bestIdx = idx;
    }
  });
  if (bestIdx >= 0) {
    const req = waitQueue.splice(bestIdx, 1)[0];
    assignAmbulanceToRequest(amb, req);
  }
}

// ---- Manual dispatcher overrides ----
// Handles both cases: swapping the unit already on a call, AND manually
// assigning a Free unit to a call that's still sitting in the wait queue.
function dispatcherAssign(reqId, newAmbId) {
  const req = requests[reqId];
  const newAmb = ambulances[newAmbId];
  if (!req || !newAmb || newAmb.status !== STATUS.FREE) return;

  const waitIdx = waitQueue.findIndex((r) => r.id === reqId);
  if (waitIdx >= 0) waitQueue.splice(waitIdx, 1);

  const oldAmb = ambulances[req.ambulanceId];
  if (oldAmb && oldAmb.id !== newAmbId) {
    oldAmb.status = STATUS.FREE;
    oldAmb.currentRequestId = null;
    cancelAnimation(oldAmb.id);
  }
  closeReassignModal();
  assignAmbulanceToRequest(newAmb, req);
}

function barAmbulance(reqId, ambId) {
  const req = requests[reqId];
  if (!req) return;
  req.barred.add(ambId);

  if (req.ambulanceId === ambId) {
    const amb = ambulances[ambId];
    if (amb) {
      amb.status = STATUS.FREE;
      amb.currentRequestId = null;
      cancelAnimation(ambId);
    }
    const replacement = findNearestFree(req.pickup, [...req.barred]);
    if (replacement) {
      assignAmbulanceToRequest(replacement, req);
    } else {
      req.status = "WAITING";
      req.ambulanceId = null;
      req.leg = null;
      waitQueue.push(req);
      renderAll();
    }
  } else {
    renderAll();
  }
}

// ---- Reassign modal ----
function openReassignModal(reqId) {
  reassignTargetRequestId = reqId;
  const req = requests[reqId];
  const freeUnits = Object.values(ambulances).filter((a) => a.status === STATUS.FREE);
  const isSwap = !!req.ambulanceId;

  document.getElementById("reassignSub").textContent = freeUnits.length
    ? isSwap
      ? "Pick a free unit to put on this call instead:"
      : "Pick a free unit to dispatch to this call:"
    : "No free units available right now.";

  const list = document.getElementById("reassignList");
  list.innerHTML = "";
  freeUnits.forEach((amb) => {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    const dist = haversineKm({ lat: amb.lat, lng: amb.lng }, req.pickup).toFixed(2);
    btn.textContent = `${amb.label} — ${dist} km away`;
    btn.onclick = () => dispatcherAssign(reqId, amb.id);
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
          <div class="amb-card__meta">Idle &middot; ready for dispatch</div>
        </div>
        <button class="btn btn--danger btn--test" onclick="promptUnavailable('${amb.id}')">Simulate: driver unavailable</button>
      </li>`
    )
    .join("");
}

function renderBusyList() {
  const el = document.getElementById("listBusy");
  const busyRequests = Object.values(requests).filter((r) => r.ambulanceId && ambulances[r.ambulanceId]);
  const waiting = waitQueue;

  const busyWithoutRequest = Object.values(ambulances).filter((amb) => {
    return amb.status === STATUS.BUSY && !amb.currentRequestId;
  });
  const serverBusyHtml = busyWithoutRequest
    .map(
      (amb) => `
      <li class="amb-card">
        <div>
          <div class="amb-card__label">${amb.label}</div>
          <div class="amb-card__meta">Busy on the server. This page cannot mark it free.</div>
        </div>
      </li>`
    )
    .join("");

  if (busyRequests.length === 0 && waiting.length === 0 && busyWithoutRequest.length === 0) {
    el.innerHTML = `<li class="board-empty">No active bookings. Click the map to simulate a new call.</li>`;
    return;
  }

  const busyHtml = busyRequests
    .map((req) => {
      const amb = ambulances[req.ambulanceId];
      const legLabel =
        req.leg === LEG.TO_PICKUP ? "To pickup" : req.leg === LEG.TRANSFER ? "Transferring patient" : "To hospital";
      const legClass = req.leg === LEG.TRANSFER ? "booking-card__leg--transfer" : "";

      let actionsHtml = "";
      if (req.leg === LEG.TO_PICKUP) {
        actionsHtml = `
          <button class="btn btn--free btn--test" onclick="markPickedUp('${req.id}')">Simulate: picked up</button>
          <button class="btn" onclick="openReassignModal('${req.id}')">Reassign</button>
          <button class="btn btn--danger" onclick="barAmbulance('${req.id}','${amb.id}')">Bar this unit</button>
          <button class="btn btn--danger btn--test" onclick="promptUnavailable('${amb.id}')">Simulate: driver unavailable</button>
        `;
      } else if (req.leg === LEG.TRANSFER) {
        actionsHtml = `
          <button class="btn btn--free" onclick="confirmTransfer('${req.id}')">Confirm patient transferred</button>
        `;
      } else {
        actionsHtml = `
          <button class="btn btn--danger btn--test" onclick="promptUnavailable('${amb.id}')">Simulate: driver unavailable</button>
        `;
      }

      const sliderHtml =
        req.leg === LEG.TO_HOSPITAL
          ? `
        <div class="booking-card__slider">
          <label>(test) Slide to simulate the driver confirming dropoff</label>
          <input type="range" min="0" max="100" value="0"
            oninput="if (this.value >= 90) { markDropoff('${req.id}'); }" />
        </div>`
          : "";

      return `
        <li class="booking-card">
          <div class="booking-card__top">
            <span class="booking-card__id">${shortId(req.id)}</span>
            <span class="booking-card__leg ${legClass}">${legLabel}</span>
          </div>
          <div class="booking-card__main"><strong>${amb.label}</strong> on this call</div>
          ${req.switchNote ? `<div class="booking-card__note">${req.switchNote}</div>` : ""}
          <div class="booking-card__actions">${actionsHtml}</div>
          ${sliderHtml}
        </li>`;
    })
    .join("");

  const waitingHtml = waiting
    .map(
      (req) => `
      <li class="booking-card">
        <div class="booking-card__top">
          <span class="booking-card__id">${shortId(req.id)}</span>
          <span class="booking-card__leg" style="color:var(--text-secondary);background:var(--bg-panel-alt);">Waiting</span>
        </div>
        <div class="booking-card__main">No free unit yet — will dispatch automatically the moment one frees up.</div>
        ${req.switchNote ? `<div class="booking-card__note">${req.switchNote}</div>` : ""}
        <div class="booking-card__actions">
          <button class="btn" onclick="openReassignModal('${req.id}')">Assign manually</button>
        </div>
      </li>`
    )
    .join("");

  el.innerHTML = serverBusyHtml + busyHtml + waitingHtml;
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
        <button class="btn btn--free" onclick="manualFree('${amb.id}')">Mark free</button>
      </li>`
    )
    .join("");
}

function promptUnavailable(ambId) {
  const reason = window.prompt("Reason this ambulance is unavailable (e.g. tire, engine, no petrol, emergency):");
  if (reason === null) return; // cancelled
  markUnavailable(ambId, reason.trim() || "Unavailable");
}

// Expose functions used by inline onclick handlers in generated HTML.
window.promptUnavailable = promptUnavailable;
window.manualFree = manualFree;
window.markPickedUp = markPickedUp;
window.markDropoff = markDropoff;
window.confirmTransfer = confirmTransfer;
window.openReassignModal = openReassignModal;
window.barAmbulance = barAmbulance;

// ---- Socket.IO (real backend events, layered on top of local simulation) ----
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

// A real call came in from the backend (e.g. the mobile app). The backend
// doesn't currently send pickup coordinates in this event, so we can't
// animate movement for it yet — it's reflected on the board without a
// live-tracking leg until that field is added. See the contract note below.
socket.on("queue.new", (payload) => {
  // #region agent log
  agentLog('C', 'app.js:queue.new', 'phone request reached dispatcher', {requestId: payload.requestId, status: payload.status, assignedLabel: payload.assignedAmbulance ? payload.assignedAmbulance.label : null, hasAmbulanceLocally: !!(payload.assignedAmbulance && ambulances[payload.assignedAmbulance.id])});
  // #endregion
  if (!payload.assignedAmbulance) return;
  const amb = ambulances[payload.assignedAmbulance.id];
  if (!amb) return;
  amb.status = STATUS.BUSY;
  amb.currentRequestId = payload.requestId;
  requests[payload.requestId] = {
    id: payload.requestId,
    pickup: null,
    status: "ASSIGNED",
    leg: LEG.TO_PICKUP,
    ambulanceId: amb.id,
    switchNote: payload.consideredNearest
      ? `${payload.consideredNearest.label} was closer but ${payload.consideredNearest.status.toLowerCase()} — switched to ${amb.label}.`
      : null,
    barred: new Set()
  };
  renderAll();
});

socket.on("ambulance.updated", (payload) => {
  // #region agent log
  agentLog('E', 'app.js:ambulance.updated', 'ambulance status event', {id: payload.id, status: payload.status, known: !!ambulances[payload.id]});
  // #endregion
  const amb = ambulances[payload.id];
  if (!amb) return;
  if (payload.status) amb.status = payload.status;
  if (payload.lat != null) amb.lat = Number(payload.lat);
  if (payload.lng != null) amb.lng = Number(payload.lng);
  renderAll();
});

// ---- Boot ----
initMap();
loadAmbulances();

// =====================================================================
// PROPOSED BACKEND CONTRACT (for coordinating with Ibad + Zain — not yet
// built). Once the driver app and backend are wired together for real,
// these "(test)" buttons on this board become obsolete — the actions
// below would instead arrive here purely as socket events, the same way
// they'd arrive on the caller's phone.
//
//   - POST /api/v1/emergency-requests: include pickup lat/lng in the
//     `queue.new` socket payload (already sent by the caller, just not
//     echoed back in the broadcast).
//   - Driver app actions, each updating the DB and re-broadcasting to
//     both the `dispatch` room and the specific `request:<id>` room so
//     the caller's app and this board update from the same event:
//       PATCH /api/v1/ambulances/:id/status   { status, reason }
//       PATCH /api/v1/emergency-requests/:id/pickup
//       PATCH /api/v1/emergency-requests/:id/dropoff   (no destination
//         needed — the driver's own GPS position at the time IS the
//         dropoff location; nothing hardcoded)
//   - PATCH /api/v1/emergency-requests/:id/reassign { ambulanceId }  (dispatcher)
//   - PATCH /api/v1/emergency-requests/:id/bar      { ambulanceId }  (dispatcher)
//   - Socket event `ambulance.location`: periodic real GPS ticks from
//     the driver's phone, replacing the client-side animation in this
//     file entirely once it exists.
// =====================================================================