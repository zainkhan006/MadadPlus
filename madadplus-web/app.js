// ---- Config ----
// Point this at Ibad's backend. Use localhost while developing, swap to the
// Render URL once it's deployed (see madad-plus-demo-sprint-plan.md).
const BACKEND_URL = "http://localhost:3000";

// ---- State ----
let map = null;
const markers = {}; // ambulance id -> google.maps.Marker
let ambulancesLoaded = false;

const STATUS_COLOR = {
  AVAILABLE: "#34d399",
  BUSY: "#f5a623",
  OFFLINE: "#5b6472"
};

// Dark map style to match the console theme
const MAP_STYLE = [
  { elementType: "geometry", stylers: [{ color: "#171d26" }] },
  { elementType: "labels.text.stroke", stylers: [{ color: "#171d26" }] },
  { elementType: "labels.text.fill", stylers: [{ color: "#8b96a5" }] },
  { featureType: "road", elementType: "geometry", stylers: [{ color: "#232a35" }] },
  { featureType: "road", elementType: "geometry.stroke", stylers: [{ color: "#171d26" }] },
  { featureType: "water", elementType: "geometry", stylers: [{ color: "#0d1116" }] },
  { featureType: "poi", stylers: [{ visibility: "off" }] },
  { featureType: "transit", stylers: [{ visibility: "off" }] },
  { featureType: "administrative", elementType: "geometry", stylers: [{ color: "#2a323f" }] }
];

// DHA Phase 5, Karachi — matches the demo's seed coordinates
const DEFAULT_CENTER = { lat: 24.8000, lng: 67.0500 };

// ---- Google Maps callback (called by the Maps script tag once loaded) ----
function initMap() {
  map = new google.maps.Map(document.getElementById("map"), {
    center: DEFAULT_CENTER,
    zoom: 14,
    disableDefaultUI: true,
    zoomControl: true,
    styles: MAP_STYLE
  });

  // If ambulance data already arrived before the map finished loading, draw it now.
  if (ambulancesLoaded) {
    renderAllMarkers();
  }
}

// ---- Marker rendering ----
function markerIcon(status) {
  return {
    path: google.maps.SymbolPath.CIRCLE,
    fillColor: STATUS_COLOR[status] || STATUS_COLOR.OFFLINE,
    fillOpacity: 1,
    strokeColor: "#10141b",
    strokeWeight: 2,
    scale: 8
  };
}

function upsertMarker(ambulance) {
  if (!map) return; // map not ready yet — renderAllMarkers() will catch it up later

  const position = { lat: Number(ambulance.lat), lng: Number(ambulance.lng) };

  if (markers[ambulance.id]) {
    markers[ambulance.id].setPosition(position);
    markers[ambulance.id].setIcon(markerIcon(ambulance.status));
  } else {
    markers[ambulance.id] = new google.maps.Marker({
      map,
      position,
      icon: markerIcon(ambulance.status),
      title: `${ambulance.label} — ${ambulance.status}`
    });
  }
}

let latestAmbulances = [];

function renderAllMarkers() {
  latestAmbulances.forEach(upsertMarker);
}

// ---- Load initial ambulance state ----
async function loadAmbulances() {
  try {
    const res = await fetch(`${BACKEND_URL}/api/v1/ambulances`);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    latestAmbulances = await res.json();
    ambulancesLoaded = true;
    renderAllMarkers();
  } catch (err) {
    console.error("Could not load ambulances:", err);
  }
}

// ---- Queue rendering ----
const queueListEl = document.getElementById("queueList");
const queueEmptyEl = document.getElementById("queueEmpty");
const queueCountEl = document.getElementById("queueCount");
let queueCount = 0;

function badgeClass(status) {
  if (status === "ASSIGNED") return "queue-item__badge--assigned";
  if (status === "COMPLETED") return "queue-item__badge--completed";
  return "queue-item__badge--queued";
}

function renderQueueItem(payload) {
  if (queueEmptyEl) queueEmptyEl.remove();

  const li = document.createElement("li");
  li.className = "queue-item";

  const top = document.createElement("div");
  top.className = "queue-item__top";

  const id = document.createElement("span");
  id.className = "queue-item__id";
  id.textContent = `#${String(payload.requestId).slice(0, 8)}`;

  const badge = document.createElement("span");
  badge.className = `queue-item__badge ${badgeClass(payload.status)}`;
  badge.textContent = payload.status;

  top.append(id, badge);

  const main = document.createElement("div");
  main.className = "queue-item__main";

  if (payload.assignedAmbulance) {
    main.innerHTML = `Assigned <strong>${payload.assignedAmbulance.label}</strong> &middot; <span class="queue-item__distance">${payload.assignedAmbulance.distanceKm.toFixed(2)} km</span>`;
  } else {
    main.textContent = "No ambulance available — request queued.";
  }

  li.append(top, main);

  if (payload.consideredNearest) {
    const switched = document.createElement("div");
    switched.className = "queue-item__switch";
    switched.innerHTML = `<strong>${payload.consideredNearest.label}</strong> was closer but ${payload.consideredNearest.status.toLowerCase()} — switched to the next-nearest available unit.`;
    li.appendChild(switched);
  }

  queueListEl.prepend(li);

  queueCount += 1;
  queueCountEl.textContent = queueCount;
}

// ---- Socket.IO ----
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
  setConnectionState("offline", "Reconnecting\u2026");
});

socket.io.on("reconnect", () => {
  socket.emit("join:dispatch");
});

socket.on("queue.new", (payload) => {
  renderQueueItem(payload);
});

socket.on("ambulance.updated", (payload) => {
  const idx = latestAmbulances.findIndex((a) => a.id === payload.id);
  if (idx >= 0) {
    latestAmbulances[idx] = { ...latestAmbulances[idx], ...payload };
  } else {
    latestAmbulances.push(payload);
  }
  upsertMarker(payload);
});

// ---- Boot ----
loadAmbulances();