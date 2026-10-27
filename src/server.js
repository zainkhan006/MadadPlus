require("dotenv").config();

const express = require("express");
const cors = require("cors");
const http = require("http");
const crypto = require("crypto");
const { Server } = require("socket.io");
const db = require("./db");
const {
  assignNearest,
  assignSpecific,
  closeActiveAssignment,
  dispatchQueuedForAmbulance,
  getRequest,
  requestPayload
} = require("./dispatch");

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());

io.on("connection", (socket) => {
  socket.on("join:dispatch", () => socket.join("dispatch"));
  socket.on("join:request", (requestId) => socket.join(`request:${requestId}`));
  socket.on("join:driver", (driverId) => socket.join(`driver:${driverId}`));
  socket.on("join:provider", (providerId) => socket.join(`provider:${providerId}`));
  socket.on("join:domestic-request", (requestId) => socket.join(`domestic:${requestId}`));
});

function validCoordinates(lat, lng) {
  return Number.isFinite(Number(lat)) && Number.isFinite(Number(lng));
}

function point(trx, lat, lng) {
  return trx.raw(
    "ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography",
    [Number(lng), Number(lat)]
  );
}

async function organizationId(trx) {
  const organization = await trx("organizations").select("id").first();
  if (!organization) {
    throw new Error("No ambulance organization has been configured");
  }
  return organization.id;
}

async function emitAmbulance(ambulanceId) {
  const ambulance = await db("ambulances as a")
    .leftJoin("drivers as d", "d.id", "a.driver_id")
    .select(
      "a.id",
      "a.label",
      "a.status",
      "a.unavailable_reason",
      "d.id as driver_id",
      "d.name as driver_name",
      db.raw("ST_Y(a.location::geometry) as lat"),
      db.raw("ST_X(a.location::geometry) as lng")
    )
    .where("a.id", ambulanceId)
    .first();

  if (ambulance) {
    io.to("dispatch").emit("ambulance.updated", {
      id: ambulance.id,
      label: ambulance.label,
      status: ambulance.status,
      unavailableReason: ambulance.unavailable_reason,
      driver: ambulance.driver_id
        ? { id: ambulance.driver_id, name: ambulance.driver_name }
        : null,
      lat: Number(ambulance.lat),
      lng: Number(ambulance.lng)
    });
  }
}

function emitRequest(request, event) {
  io.to(`request:${request.requestId}`).emit(event, request);
  io.to("dispatch").emit("queue.updated", request);
  const driverId = request.assignedAmbulance?.driver?.id;
  if (driverId) {
    io.to(`driver:${driverId}`).emit(event, request);
  }
}

function money(value) {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && !value.trim()) return null;
  const amount = Number(value);
  return Number.isFinite(amount) && amount >= 0 ? amount : null;
}

function domesticRequestPayload(request) {
  return {
    requestId: request.id,
    status: request.status,
    description: request.description,
    address: request.address,
    createdAt: request.created_at,
    updatedAt: request.updated_at,
    specialisation: request.specialisation_id
      ? { id: request.specialisation_id, name: request.specialisation_name }
      : null,
    user: request.user_id
      ? { id: request.user_id, name: request.user_name, phone: request.user_phone }
      : null,
    provider: request.provider_id
      ? {
          id: request.provider_id,
          name: request.provider_name,
          phone: request.provider_phone,
          rating: Number(request.provider_rating),
          inspectionFee: Number(request.provider_inspection_fee)
        }
      : null,
    quotedTotal: request.quoted_total == null ? null : Number(request.quoted_total),
    inspectionFee: request.receipt_inspection_fee == null
      ? null
      : Number(request.receipt_inspection_fee),
    finalTotal: request.final_total == null ? null : Number(request.final_total),
    receiptStatus: request.receipt_status || null
  };
}

async function getDomesticRequest(requestId) {
  const request = await db("domestic_requests as r")
    .leftJoin("specialisations as s", "s.id", "r.specialisation_id")
    .leftJoin("users as u", "u.id", "r.user_id")
    .leftJoin("providers as p", "p.id", "r.provider_id")
    .select(
      "r.id",
      "r.status",
      "r.description",
      "r.address",
      "r.created_at",
      "r.updated_at",
      "r.specialisation_id",
      "s.name as specialisation_name",
      "r.user_id",
      "u.name as user_name",
      "u.phone as user_phone",
      "r.provider_id",
      "p.name as provider_name",
      "p.phone as provider_phone",
      "p.rating as provider_rating",
      "p.inspection_fee as provider_inspection_fee",
      "receipt.quoted_total",
      "receipt.inspection_fee as receipt_inspection_fee",
      "receipt.final_total",
      "receipt.status as receipt_status"
    )
    .leftJoin("receipts as receipt", "receipt.request_id", "r.id")
    .where("r.id", requestId)
    .first();

  return request ? domesticRequestPayload(request) : null;
}

function emitDomesticRequest(request, event) {
  io.to(`domestic:${request.requestId}`).emit(event, request);
  if (request.provider?.id) {
    io.to(`provider:${request.provider.id}`).emit(event, request);
  }
}

async function assignAndLoad(trx, requestId, phase, reason) {
  await assignNearest(trx, requestId, phase, reason);
  return requestPayload(trx, requestId);
}

async function completeRequest(requestId) {
  return db.transaction(async (trx) => {
    const request = await getRequest(trx, requestId);
    if (!request) {
      return { statusCode: 404, body: { error: "Request not found" } };
    }
    if (request.status === "COMPLETED") {
      return { statusCode: 200, body: await requestPayload(trx, requestId) };
    }
    if (!request.assigned_ambulance_id) {
      return { statusCode: 409, body: { error: "This request has no assigned ambulance" } };
    }

    await trx("emergency_requests")
      .where("id", requestId)
      .update({
        status: "COMPLETED",
        completed_at: trx.fn.now(),
        updated_at: trx.fn.now()
      });
    await closeActiveAssignment(trx, requestId, "COMPLETED");
    await trx("ambulances")
      .where({ id: request.assigned_ambulance_id, status: "BUSY" })
      .update({ status: "FREE", updated_at: trx.fn.now() });

    const waitingRequestId = await dispatchQueuedForAmbulance(
      trx,
      request.assigned_ambulance_id
    );
    return {
      statusCode: 200,
      body: await requestPayload(trx, requestId),
      freedAmbulanceId: request.assigned_ambulance_id,
      waitingRequestId
    };
  });
}

app.get("/health", async (req, res) => {
  try {
    await db.raw("select 1");
    res.json({ status: "ok", database: "connected" });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ status: "error", database: "disconnected" });
  }
});

app.get("/api/v1/ambulances", async (req, res) => {
  try {
    const query = db("ambulances as a")
      .leftJoin("drivers as d", "d.id", "a.driver_id")
      .select(
        "a.id",
        "a.label",
        "a.status",
        "a.unavailable_reason as unavailableReason",
        "a.last_location_at as lastLocationAt",
        "d.id as driverId",
        "d.name as driverName",
        "d.phone as driverPhone",
        db.raw("ST_Y(a.location::geometry) as lat"),
        db.raw("ST_X(a.location::geometry) as lng")
      );

    if (req.query.status) {
      query.where("a.status", String(req.query.status).toUpperCase());
    }

    const ambulances = await query.orderBy("a.label");
    res.json(ambulances);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load ambulances" });
  }
});

app.get("/api/v1/hospitals", async (req, res) => {
  try {
    const hospitals = await db("hospitals")
      .select(
        "id",
        "name",
        "phone",
        "address",
        db.raw("ST_Y(location::geometry) as lat"),
        db.raw("ST_X(location::geometry) as lng")
      )
      .where("active", true)
      .orderBy("name");
    res.json(hospitals.map((hospital) => ({
      ...hospital,
      lat: Number(hospital.lat),
      lng: Number(hospital.lng)
    })));
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load hospitals" });
  }
});

app.get("/api/v1/drivers/:driverId/portal", async (req, res) => {
  try {
    const driver = await db("drivers as d")
      .leftJoin("ambulances as a", "a.driver_id", "d.id")
      .select(
        "d.id",
        "d.name",
        "d.phone",
        "d.status",
        "a.id as ambulance_id",
        "a.label as ambulance_label",
        "a.status as ambulance_status",
        "a.unavailable_reason"
      )
      .where("d.id", req.params.driverId)
      .first();

    if (!driver) {
      return res.status(404).json({ error: "Driver not found" });
    }

    const activeRequest = driver.ambulance_id
      ? await db("emergency_requests")
          .select("id")
          .where("assigned_ambulance_id", driver.ambulance_id)
          .whereNotIn("status", ["COMPLETED", "CANCELLED"])
          .first()
      : null;

    const request = activeRequest
      ? await db.transaction((trx) => requestPayload(trx, activeRequest.id))
      : null;

    res.json({
      driver: {
        id: driver.id,
        name: driver.name,
        phone: driver.phone,
        status: driver.status
      },
      ambulance: driver.ambulance_id
        ? {
            id: driver.ambulance_id,
            label: driver.ambulance_label,
            status: driver.ambulance_status,
            unavailableReason: driver.unavailable_reason
          }
        : null,
      activeRequest: request
    });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load driver portal" });
  }
});

app.get("/api/v1/dispatch/requests", async (req, res) => {
  try {
    const requests = await db("emergency_requests as r")
      .leftJoin("ambulances as a", "a.id", "r.assigned_ambulance_id")
      .select(
        "r.id",
        "r.status",
        "r.current_phase as phase",
        "r.type",
        "r.caller_phone as callerPhone",
        "r.pickup_address as pickupAddress",
        "r.emergency_description as emergencyDescription",
        "r.created_at as createdAt",
        "a.label as ambulanceLabel"
      )
      .modify((query) => {
        if (req.query.status) {
          query.where("r.status", String(req.query.status).toUpperCase());
        }
      })
      .orderBy("r.created_at", "desc");

    res.json(requests);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load dispatch requests" });
  }
});

app.get("/api/v1/emergency-requests", async (req, res) => {
  try {
    const requests = await db("emergency_requests as r")
      .leftJoin("ambulances as a", "a.id", "r.assigned_ambulance_id")
      .select(
        "r.id",
        "r.status",
        "r.current_phase as phase",
        "r.type",
        "r.caller_phone as callerPhone",
        "r.pickup_address as pickupAddress",
        "r.emergency_description as emergencyDescription",
        "r.created_at as createdAt",
        "a.label as ambulanceLabel"
      )
      .whereNotIn("r.status", ["COMPLETED", "CANCELLED"])
      .orderBy("r.created_at", "desc");

    res.json(requests);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load emergency requests" });
  }
});

app.get("/api/v1/emergency-requests/:requestId", async (req, res) => {
  try {
    const payload = await db.transaction((trx) => requestPayload(trx, req.params.requestId));
    if (!payload) return res.status(404).json({ error: "Request not found" });
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load emergency request" });
  }
});

app.post("/api/v1/emergency-requests", async (req, res) => {
  const {
    lat,
    lng,
    type,
    address,
    description,
    peopleCount,
    additionalDetails,
    inputMethod,
    callerPhone,
    hospitalAddress,
    hospitalLat,
    hospitalLng
  } = req.body;

  if (!validCoordinates(lat, lng) || type !== "ambulance") {
    return res.status(400).json({
      error: "lat, lng, and type: 'ambulance' are required"
    });
  }
  if (!String(address || "").trim() || !String(description || "").trim()) {
    return res.status(400).json({
      error: "address and description (what happened) are required"
    });
  }
  const parsedPeopleCount = Number(peopleCount);
  if (!Number.isInteger(parsedPeopleCount) || parsedPeopleCount < 1) {
    return res.status(400).json({
      error: "peopleCount must be a positive whole number"
    });
  }
  const method = String(inputMethod || "MANUAL").toUpperCase();
  if (!["MANUAL", "VOICE"].includes(method)) {
    return res.status(400).json({ error: "inputMethod must be MANUAL or VOICE" });
  }

  try {
    const result = await db.transaction(async (trx) => {
      const orgId = await organizationId(trx);
      const pointValue = point(trx, lat, lng);
      const [request] = await trx("emergency_requests")
        .insert({
          organization_id: orgId,
          type,
          caller_phone: callerPhone || null,
          pickup_address: String(address).trim(),
          emergency_description: String(description).trim(),
          people_count: parsedPeopleCount,
          additional_details: additionalDetails ? String(additionalDetails).trim() : null,
          input_method: method,
          hospital_address: hospitalAddress || null,
          hospital_location: validCoordinates(hospitalLat, hospitalLng)
            ? point(trx, hospitalLat, hospitalLng)
            : null,
          pickup_location: pointValue,
          dispatch_location: pointValue,
          status: "QUEUED",
          current_phase: "PICKUP",
          queued_at: trx.fn.now()
        })
        .returning("id");

      const allNearby = await trx("ambulances")
        .select("id", "label", "status")
        .select(trx.raw(
          "ST_Distance(location, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography) / 1000 as distance_km",
          [Number(lng), Number(lat)]
        ))
        .where("organization_id", orgId)
        .orderByRaw(
          "location <-> ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography",
          [Number(lng), Number(lat)]
        );

      await assignAndLoad(trx, request.id, "PICKUP", "AUTOMATIC");
      const payload = await requestPayload(trx, request.id);
      const nearest = allNearby[0];

      return {
        payload,
        response: {
          ...payload,
          consideredNearest: nearest && nearest.id !== payload.assignedAmbulance?.id && nearest.status !== "FREE"
            ? {
                id: nearest.id,
                label: nearest.label,
                distanceKm: Number(nearest.distance_km),
                status: nearest.status
              }
            : null
        }
      };
    });

    emitRequest(
      result.payload,
      result.payload.status === "QUEUED" ? "request.queued" : "request.assigned"
    );
    if (result.payload.assignedAmbulance) {
      await emitAmbulance(result.payload.assignedAmbulance.id);
    }
    res.status(201).json(result.response);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to create emergency request" });
  }
});

app.patch("/api/v1/emergency-requests/:requestId/en-route", async (req, res) => {
  try {
    const result = await db("emergency_requests")
      .where({ id: req.params.requestId, status: "ASSIGNED" })
      .update({ status: "EN_ROUTE", updated_at: db.fn.now() });

    if (result !== 1) {
      return res.status(409).json({ error: "Request is not currently assigned" });
    }

    const payload = await db.transaction((trx) => requestPayload(trx, req.params.requestId));
    emitRequest(payload, "request.enRoute");
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to mark request EN_ROUTE" });
  }
});

app.patch("/api/v1/emergency-requests/:requestId/arrived", async (req, res) => {
  try {
    const updated = await db("emergency_requests")
      .whereIn("status", ["EN_ROUTE", "PICKED_UP", "EN_ROUTE_HOSPITAL"])
      .where("id", req.params.requestId)
      .update({ status: "ARRIVED", arrived_hospital_at: db.fn.now(), updated_at: db.fn.now() });

    if (updated !== 1) {
      return res.status(409).json({ error: "Request is not in a route state" });
    }

    const payload = await db.transaction((trx) => requestPayload(trx, req.params.requestId));
    emitRequest(payload, "request.arrived");
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to mark request ARRIVED" });
  }
});

async function markDriverRequest(driverId, requestId, action) {
  return db.transaction(async (trx) => {
    const driver = await trx("drivers as d")
      .join("ambulances as a", "a.driver_id", "d.id")
      .select("d.id as driver_id", "a.id as ambulance_id")
      .where("d.id", driverId)
      .first();
    const request = await trx("emergency_requests")
      .select(
        "id",
        "organization_id",
        "status",
        "current_phase",
        "assigned_ambulance_id",
        "dispatch_location",
        "hospital_id",
        "hospital_location"
      )
      .where("id", requestId)
      .first();

    if (!driver || !request || request.assigned_ambulance_id !== driver.ambulance_id) {
      return { statusCode: 404, body: { error: "Driver request assignment not found" } };
    }

    const transitions = {
      pickup: {
        from: ["ASSIGNED", "EN_ROUTE", "TRANSFER_EN_ROUTE"],
        status: request.status === "TRANSFER_EN_ROUTE" ? "EN_ROUTE_HOSPITAL" : "PICKED_UP",
        phase: "HOSPITAL"
      },
      hospital: { from: ["PICKED_UP", "EN_ROUTE_HOSPITAL"], status: "ARRIVED", phase: "HOSPITAL" }
    };
    const transition = transitions[action];
    if (!transition.from.includes(request.status)) {
      return { statusCode: 409, body: { error: `Request cannot perform ${action} from ${request.status}` } };
    }

    const updates = {
      status: transition.status,
      current_phase: transition.phase,
      picked_up_at: action === "pickup" && request.status !== "TRANSFER_EN_ROUTE"
        ? trx.fn.now()
        : undefined,
      arrived_hospital_at: action === "hospital" ? trx.fn.now() : undefined,
      updated_at: trx.fn.now()
    };

    if (action === "pickup") {
      if (!request.hospital_id && !request.hospital_location) {
        const hospital = await trx("hospitals")
          .select("id", "name", "address")
          .where("active", true)
          .orderByRaw(
            "location <-> (select pickup_location from emergency_requests where id = ?)",
            [requestId]
          )
          .first();
        if (hospital) {
          updates.hospital_id = hospital.id;
          updates.hospital_address = hospital.address;
          updates.hospital_location = trx.raw(
            "(select location from hospitals where id = ?)",
            [hospital.id]
          );
          updates.dispatch_location = trx.raw(
            "(select location from hospitals where id = ?)",
            [hospital.id]
          );
        }
      } else if (request.hospital_id) {
        updates.dispatch_location = trx.raw(
          "(select location from hospitals where id = ?)",
          [request.hospital_id]
        );
      } else {
        updates.dispatch_location = request.hospital_location;
      }
    }

    await trx("emergency_requests")
      .where("id", requestId)
      .update(updates);

    return {
      statusCode: 200,
      body: await requestPayload(trx, requestId),
      event: action === "pickup"
        ? request.status === "TRANSFER_EN_ROUTE" ? "request.patientTransferred" : "request.pickedUp"
        : "request.arrived"
    };
  });
}

app.patch("/api/v1/drivers/:driverId/requests/:requestId/pickup", async (req, res) => {
  try {
    const result = await markDriverRequest(req.params.driverId, req.params.requestId, "pickup");
    if (result.statusCode === 200) emitRequest(result.body, result.event);
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to confirm pickup" });
  }
});

app.patch("/api/v1/drivers/:driverId/requests/:requestId/hospital", async (req, res) => {
  try {
    const result = await markDriverRequest(req.params.driverId, req.params.requestId, "hospital");
    if (result.statusCode === 200) emitRequest(result.body, result.event);
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to confirm hospital arrival" });
  }
});

app.patch("/api/v1/emergency-requests/:requestId/complete", async (req, res) => {
  try {
    const result = await completeRequest(req.params.requestId);
    if (result.statusCode === 200) {
      emitRequest(result.body, "request.completed");
      if (result.freedAmbulanceId) await emitAmbulance(result.freedAmbulanceId);
      if (result.waitingRequestId) {
        const waiting = await db.transaction((trx) => requestPayload(trx, result.waitingRequestId));
        emitRequest(waiting, "request.assigned");
        if (waiting.assignedAmbulance) await emitAmbulance(waiting.assignedAmbulance.id);
      }
    }
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to complete emergency request" });
  }
});

app.patch("/api/v1/drivers/:driverId/requests/:requestId/dropoff", async (req, res) => {
  req.params.requestId = req.params.requestId;
  try {
    const result = await completeRequest(req.params.requestId);
    if (result.statusCode === 200) {
      emitRequest(result.body, "request.completed");
      if (result.freedAmbulanceId) await emitAmbulance(result.freedAmbulanceId);
    }
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to confirm drop-off" });
  }
});

app.patch("/api/v1/drivers/:driverId/location", async (req, res) => {
  const { lat, lng } = req.body;
  if (!validCoordinates(lat, lng)) {
    return res.status(400).json({ error: "lat and lng are required" });
  }

  try {
    const result = await db.transaction(async (trx) => {
      const ambulance = await trx("ambulances")
        .select("id")
        .where("driver_id", req.params.driverId)
        .first();
      if (!ambulance) return null;

      const location = point(trx, lat, lng);
      await trx("ambulances")
        .where("id", ambulance.id)
        .update({ location, last_location_at: trx.fn.now(), updated_at: trx.fn.now() });
      const activeRequest = await trx("emergency_requests")
        .select("id")
        .where("assigned_ambulance_id", ambulance.id)
        .whereNotIn("status", ["COMPLETED", "CANCELLED"])
        .first();
      await trx("ambulance_location_updates").insert({
        ambulance_id: ambulance.id,
        driver_id: req.params.driverId,
        request_id: activeRequest?.id || null,
        location
      });
      return ambulance.id;
    });

    if (!result) return res.status(404).json({ error: "Driver ambulance not found" });
    await emitAmbulance(result);
    res.json({ status: "ok", ambulanceId: result, lat: Number(lat), lng: Number(lng) });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to update driver location" });
  }
});

async function markUnavailable(driverId, reason, lat, lng, ambulanceIdOverride, requestId) {
  const hasCoordinates = lat != null || lng != null;
  if (hasCoordinates && !validCoordinates(lat, lng)) {
    return { statusCode: 400, body: { error: "lat and lng must both be valid coordinates" } };
  }

  return db.transaction(async (trx) => {
    const ambulanceQuery = trx("ambulances")
      .select("id", "status", "driver_id");
    if (ambulanceIdOverride) {
      ambulanceQuery.where("id", ambulanceIdOverride);
    } else {
      ambulanceQuery.where("driver_id", driverId);
    }
    const ambulance = await ambulanceQuery.forUpdate().first();
    if (!ambulance) return { statusCode: 404, body: { error: "Driver ambulance not found" } };

    const requestQuery = trx("emergency_requests")
      .select("id", "status", "current_phase", "pickup_location")
      .where("assigned_ambulance_id", ambulance.id);
    if (requestId) {
      requestQuery.where("id", requestId);
    } else {
      requestQuery.whereNotIn("status", ["COMPLETED", "CANCELLED"]);
    }
    requestQuery.forUpdate();
    const request = await requestQuery.first();

    if (requestId && !request) {
      return { statusCode: 404, body: { error: "Driver request assignment not found" } };
    }

    const reassignableStatuses = [
      "ASSIGNED",
      "EN_ROUTE",
      "PICKED_UP",
      "EN_ROUTE_HOSPITAL",
      "TRANSFER_EN_ROUTE",
      "ARRIVED"
    ];
    if (request && !reassignableStatuses.includes(request.status)) {
      return {
        statusCode: 409,
        body: { error: `Request cannot be reassigned from ${request.status}` }
      };
    }

    if (hasCoordinates) {
      await trx("ambulances").where("id", ambulance.id).update({
        location: point(trx, lat, lng),
        last_location_at: trx.fn.now(),
        updated_at: trx.fn.now()
      });
    }

    const unavailableReason = String(reason || "").trim().slice(0, 255)
      || "Driver reported a breakdown";
    await trx("ambulances").where("id", ambulance.id).update({
      status: "UNAVAILABLE",
      unavailable_reason: unavailableReason,
      updated_at: trx.fn.now()
    });

    let replacementRequestId = null;
    let requestEventPayload = null;
    let requestEvent = null;
    if (request) {
      await closeActiveAssignment(trx, request.id, "AMBULANCE_UNAVAILABLE");
      const afterPickup = ["PICKED_UP", "EN_ROUTE_HOSPITAL", "TRANSFER_EN_ROUTE", "ARRIVED"]
        .includes(request.status) || request.current_phase === "TRANSFER";
      const currentLocation = await trx("ambulances")
        .select("location")
        .where("id", ambulance.id)
        .first();

      await trx("emergency_requests")
        .where("id", request.id)
        .update({
          assigned_ambulance_id: null,
          status: afterPickup ? "TRANSFER_QUEUED" : "QUEUED",
          current_phase: afterPickup ? "TRANSFER" : "PICKUP",
          dispatch_location: afterPickup ? currentLocation.location : request.pickup_location,
          breakdown_location: currentLocation.location,
          updated_at: trx.fn.now()
        });

      await assignNearest(
        trx,
        request.id,
        afterPickup ? "TRANSFER" : "PICKUP",
        "BREAKDOWN_REPLACEMENT"
      );
      replacementRequestId = request.id;

      const payload = await requestPayload(trx, request.id);
      const reassigned = Boolean(payload.assignedAmbulance);
      requestEvent = reassigned ? "request.reassigned" : "request.queued";
      requestEventPayload = {
        ...payload,
        reassignmentStatus: reassigned ? "ASSIGNED" : "QUEUED",
        callerMessage: reassigned
          ? `Your ambulance has changed to ${payload.assignedAmbulance.label}.`
          : "Your ambulance is unavailable. We are finding a replacement now."
      };

      if (hasCoordinates) {
        await trx("ambulance_location_updates").insert({
          ambulance_id: ambulance.id,
          driver_id: ambulance.driver_id,
          request_id: request.id,
          location: point(trx, lat, lng)
        });
      }
    }

    return {
      statusCode: 200,
      body: {
        ambulanceId: ambulance.id,
        status: "UNAVAILABLE",
        replacementRequestId,
        reassignmentStatus: requestEventPayload?.reassignmentStatus || null,
        callerMessage: requestEventPayload?.callerMessage || null,
        request: requestEventPayload
      },
      ambulanceId: ambulance.id,
      previousDriverId: ambulance.driver_id,
      requestEvent,
      requestEventPayload
    };
  });
}

async function publishUnavailableResult(result) {
  await emitAmbulance(result.ambulanceId);
  if (!result.requestEventPayload) return;

  emitRequest(result.requestEventPayload, result.requestEvent);
  const nextDriverId = result.requestEventPayload.assignedAmbulance?.driver?.id;
  if (result.previousDriverId && result.previousDriverId !== nextDriverId) {
    io.to(`driver:${result.previousDriverId}`).emit("request.reassigned", result.requestEventPayload);
  }
  if (result.requestEventPayload.assignedAmbulance) {
    await emitAmbulance(result.requestEventPayload.assignedAmbulance.id);
  }
}

function validateUnavailableCoordinates(req, res) {
  const { lat, lng } = req.body;
  if ((lat != null || lng != null) && !validCoordinates(lat, lng)) {
    res.status(400).json({ error: "lat and lng must both be valid coordinates" });
    return false;
  }
  return true;
}

app.patch("/api/v1/drivers/:driverId/unavailable", async (req, res) => {
  if (!validateUnavailableCoordinates(req, res)) return;
  try {
    const result = await markUnavailable(
      req.params.driverId,
      req.body.reason,
      req.body.lat,
      req.body.lng
    );
    if (result.statusCode === 200) {
      await publishUnavailableResult(result);
    }
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to mark ambulance unavailable" });
  }
});

app.patch("/api/v1/drivers/:driverId/requests/:requestId/reassign", async (req, res) => {
  if (!validateUnavailableCoordinates(req, res)) return;
  try {
    const result = await markUnavailable(
      req.params.driverId,
      req.body.reason,
      req.body.lat,
      req.body.lng,
      undefined,
      req.params.requestId
    );
    if (result.statusCode === 200) {
      await publishUnavailableResult(result);
    }
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to reassign emergency request" });
  }
});

app.patch("/api/v1/drivers/:driverId/available", async (req, res) => {
  try {
    const result = await db.transaction(async (trx) => {
      const ambulance = await trx("ambulances")
        .select("id")
        .where("driver_id", req.params.driverId)
        .first();
      if (!ambulance) return null;

      const active = await trx("request_assignments")
        .where({ ambulance_id: ambulance.id, status: "ACTIVE" })
        .first();
      if (active) return { conflict: true };

      await trx("ambulances").where("id", ambulance.id).update({
        status: "FREE",
        unavailable_reason: null,
        updated_at: trx.fn.now()
      });
      const waitingRequestId = await dispatchQueuedForAmbulance(trx, ambulance.id);
      return { ambulanceId: ambulance.id, waitingRequestId };
    });

    if (!result) return res.status(404).json({ error: "Driver ambulance not found" });
    if (result.conflict) return res.status(409).json({ error: "Finish or transfer the active call first" });
    await emitAmbulance(result.ambulanceId);
    res.json({ status: "FREE", ...result });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to mark ambulance free" });
  }
});

app.patch("/api/v1/ambulances/:ambulanceId/status", async (req, res) => {
  const status = String(req.body.status || "").toUpperCase();
  if (!["FREE", "UNAVAILABLE"].includes(status)) {
    return res.status(400).json({ error: "status must be FREE or UNAVAILABLE" });
  }

  try {
    if (status === "UNAVAILABLE") {
      const ambulance = await db("ambulances").select("driver_id").where("id", req.params.ambulanceId).first();
      if (!ambulance) return res.status(404).json({ error: "Ambulance not found" });
      const result = await markUnavailable(
        ambulance.driver_id,
        req.body.reason || "Dispatcher marked unavailable",
        undefined,
        undefined,
        req.params.ambulanceId
      );
      if (result.statusCode === 200) await publishUnavailableResult(result);
      return res.status(result.statusCode).json(result.body);
    }

    const force = req.body.force === true || req.body.reason === "TEST_RESET";
    const result = await db.transaction(async (trx) => {
      const ambulance = await trx("ambulances")
        .select("id", "status")
        .where("id", req.params.ambulanceId)
        .forUpdate()
        .first();
      if (!ambulance) return { notFound: true };
      if (ambulance.status === "BUSY" && !force) {
        return { conflict: true, reason: "BUSY ambulance requires force=true for a test reset" };
      }
      if (ambulance.status === "FREE") {
        return { alreadyFree: true };
      }

      const activeAssignment = await trx("request_assignments")
        .where({ ambulance_id: ambulance.id, status: "ACTIVE" })
        .first();
      let cancelledRequestId = null;
      if (activeAssignment) {
        cancelledRequestId = activeAssignment.request_id;
        await trx("emergency_requests")
          .where("id", activeAssignment.request_id)
          .update({ status: "CANCELLED", updated_at: trx.fn.now() });
        await closeActiveAssignment(trx, activeAssignment.request_id, "DISPATCHER_TEST_RESET");
      }

      await trx("ambulances")
        .where("id", req.params.ambulanceId)
        .update({ status: "FREE", unavailable_reason: null, updated_at: trx.fn.now() });
      const waitingRequestId = await dispatchQueuedForAmbulance(trx, req.params.ambulanceId);
      return { waitingRequestId, cancelledRequestId };
    });
    if (result.notFound) return res.status(404).json({ error: "Ambulance not found" });
    if (result.conflict) return res.status(409).json({ error: result.reason });
    if (result.alreadyFree) return res.json({ ambulanceId: req.params.ambulanceId, status: "FREE" });
    await emitAmbulance(req.params.ambulanceId);
    if (result.cancelledRequestId) {
      io.to(`request:${result.cancelledRequestId}`).emit("request.cancelled", {
        requestId: result.cancelledRequestId,
        status: "CANCELLED",
        reason: "DISPATCHER_TEST_RESET"
      });
    }
    if (result.waitingRequestId) {
      const waiting = await db.transaction((trx) => requestPayload(trx, result.waitingRequestId));
      emitRequest(waiting, "request.assigned");
      if (waiting.assignedAmbulance) await emitAmbulance(waiting.assignedAmbulance.id);
    }
    res.json({ ambulanceId: req.params.ambulanceId, status: "FREE", ...result });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to update ambulance status" });
  }
});

app.post("/api/v1/emergency-requests/:requestId/blocked-ambulances", async (req, res) => {
  try {
    await db("request_ambulance_blocks")
      .insert({
        request_id: req.params.requestId,
        ambulance_id: req.body.ambulanceId,
        reason: req.body.reason || "Dispatcher blocked this ambulance for the request"
      })
      .onConflict(["request_id", "ambulance_id"])
      .merge({ reason: req.body.reason || "Dispatcher blocked this ambulance for the request" });
    res.status(201).json({ requestId: req.params.requestId, ambulanceId: req.body.ambulanceId, blocked: true });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to block ambulance for request" });
  }
});

app.post("/api/v1/emergency-requests/:requestId/assign", async (req, res) => {
  try {
    const result = await db.transaction(async (trx) => {
      const request = await getRequest(trx, req.params.requestId);
      if (!request) return { statusCode: 404, body: { error: "Request not found" } };
      if (!["QUEUED", "TRANSFER_QUEUED", "ASSIGNED", "EN_ROUTE"].includes(request.status)) {
        return { statusCode: 409, body: { error: "Request cannot be manually reassigned now" } };
      }

      if (request.assigned_ambulance_id) {
        await closeActiveAssignment(trx, request.id, "DISPATCHER_SWAP");
        await trx("ambulances").where({ id: request.assigned_ambulance_id, status: "BUSY" }).update({
          status: "FREE",
          updated_at: trx.fn.now()
        });
        await trx("emergency_requests").where("id", request.id).update({
          assigned_ambulance_id: null,
          status: "QUEUED",
          updated_at: trx.fn.now()
        });
      }

      const phase = request.current_phase === "TRANSFER" ? "TRANSFER" : "PICKUP";
      const assigned = await assignSpecific(trx, request.id, req.body.ambulanceId, phase, "MANUAL_OVERRIDE");
      if (!assigned) return { statusCode: 409, body: { error: "Selected ambulance is not FREE or is blocked" } };
      return { statusCode: 200, body: await requestPayload(trx, request.id) };
    });

    if (result.statusCode === 200) {
      emitRequest(result.body, "request.reassigned");
      if (result.body.assignedAmbulance) await emitAmbulance(result.body.assignedAmbulance.id);
    }
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to manually assign ambulance" });
  }
});

app.get("/api/v1/specialisations", async (req, res) => {
  try {
    const specialisations = await db("specialisations")
      .select("id", "name")
      .where("active", true)
      .orderBy("name");
    res.json(specialisations);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load specialisations" });
  }
});

app.get("/api/v1/callers", async (req, res) => {
  try {
    const callers = await db("users")
      .select("id", "name", "phone")
      .orderBy("name");
    res.json(callers);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load callers" });
  }
});

app.post("/api/v1/callers", async (req, res) => {
  const name = String(req.body.name || "").trim();
  const phone = String(req.body.phone || "").trim();
  if (!name || !phone) {
    return res.status(400).json({ error: "name and phone are required" });
  }

  try {
    const taken = await db("users").select("id").where("phone", phone).first();
    if (taken) {
      return res.status(409).json({ error: "That phone number is already registered" });
    }
    const authUserId = crypto.randomUUID();
    const [caller] = await db("users")
      .insert({
        auth_user_id: authUserId,
        name,
        phone,
        email: `${authUserId}@madadplus.test`,
        verified: true
      })
      .returning(["id", "name", "phone"]);
    res.status(201).json(caller);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to register caller" });
  }
});

app.post("/api/v1/drivers", async (req, res) => {
  const name = String(req.body.name || "").trim();
  const phone = String(req.body.phone || "").trim();
  const label = String(req.body.ambulanceLabel || "").trim().toUpperCase();
  if (!name || !phone || !label) {
    return res.status(400).json({ error: "name, phone, and ambulanceLabel are required" });
  }

  try {
    const ambulanceId = await db.transaction(async (trx) => {
      const orgId = await organizationId(trx);
      const [driver] = await trx("drivers")
        .insert({ organization_id: orgId, name, phone })
        .returning(["id"]);

      const existing = await trx("ambulances").select("id").where("label", label).first();
      if (existing) {
        await trx("ambulances").where("id", existing.id).update({ driver_id: driver.id });
        return existing.id;
      }

      // New ambulances start somewhere in Karachi (Clifton to Korangi).
      const lat = 24.84 + Math.random() * 0.08;
      const lng = 67.03 + Math.random() * 0.09;
      const [created] = await trx("ambulances")
        .insert({
          organization_id: orgId,
          driver_id: driver.id,
          label,
          status: "FREE",
          location: point(trx, lat, lng)
        })
        .returning(["id"]);
      return created.id;
    });

    const ambulance = await db("ambulances as a")
      .leftJoin("drivers as d", "d.id", "a.driver_id")
      .select(
        "a.id",
        "a.label",
        "a.status",
        "d.id as driverId",
        "d.name as driverName",
        "d.phone as driverPhone",
        db.raw("ST_Y(a.location::geometry) as lat"),
        db.raw("ST_X(a.location::geometry) as lng")
      )
      .where("a.id", ambulanceId)
      .first();
    await emitAmbulance(ambulanceId);
    res.status(201).json(ambulance);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to register driver" });
  }
});

app.get("/api/v1/providers", async (req, res) => {
  try {
    const providers = await db("providers as p")
      .leftJoin("specialisations as s", "s.id", "p.specialisation_id")
      .select(
        "p.id",
        "p.name",
        "p.phone",
        "p.status",
        "p.designation",
        "p.rating",
        "p.inspection_fee as inspectionFee",
        "p.services_provided_count as servicesProvidedCount",
        "s.id as specialisationId",
        "s.name as specialisationName"
      )
      .modify((query) => {
        if (req.query.specialisationId) {
          query.where("p.specialisation_id", req.query.specialisationId);
        }
        if (req.query.status) {
          query.where("p.status", String(req.query.status).toUpperCase());
        }
      })
      .orderBy("p.rating", "desc");

    res.json(providers.map((provider) => ({
      ...provider,
      rating: Number(provider.rating),
      inspectionFee: Number(provider.inspectionFee)
    })));
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load providers" });
  }
});

function normalizeName(value) {
  return String(value || "").trim().replace(/\s+/g, " ").toLowerCase();
}

function editDistance(a, b) {
  let previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let i = 1; i <= a.length; i += 1) {
    const current = [i];
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      current[j] = Math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost);
    }
    previous = current;
  }
  return previous[b.length];
}

function isPartialNameMatch(typed, saved) {
  if (saved.includes(typed) || typed.includes(saved)) return true;
  if (typed.length < 8 || saved.length < 8) return false;
  return editDistance(typed, saved) <= 2;
}

function maskCnic(cnic) {
  let seen = 0;
  return String(cnic || "").replace(/\d/g, (digit) => {
    seen += 1;
    return seen <= 5 ? digit : "x";
  });
}

async function findProviderNameMatches(name, specialisationId) {
  const typed = normalizeName(name);
  const rows = await db("providers as p")
    .leftJoin("specialisations as s", "s.id", "p.specialisation_id")
    .select(
      "p.id",
      "p.name",
      "p.phone",
      "p.cnic",
      "p.status",
      "p.rating",
      "p.inspection_fee as inspectionFee",
      "s.id as specialisationId",
      "s.name as specialisationName"
    )
    .where("p.specialisation_id", specialisationId);

  const exact = rows.some((row) => normalizeName(row.name) === typed);
  const matches = exact
    ? []
    : rows
        .filter((row) => isPartialNameMatch(typed, normalizeName(row.name)))
        .map((row) => ({
          ...row,
          cnic: maskCnic(row.cnic),
          rating: Number(row.rating),
          inspectionFee: Number(row.inspectionFee)
        }));
  return { exact, matches };
}

const existingNameMessage = "A user already exists with that name.";

app.post("/api/v1/providers/name-check", async (req, res) => {
  const name = String(req.body.name || "").trim();
  const trade = String(req.body.trade || "").trim();
  if (!name || !trade) {
    return res.status(400).json({ error: "name and trade are required" });
  }

  try {
    const specialisation = await db("specialisations")
      .select("id")
      .whereRaw("lower(name) = lower(?)", [trade])
      .first();
    if (!specialisation) {
      return res.status(404).json({ error: `No trade called ${trade} was found` });
    }
    const { exact, matches } = await findProviderNameMatches(name, specialisation.id);
    if (exact) {
      return res.status(409).json({ error: existingNameMessage });
    }
    res.json({ matches });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to check provider name" });
  }
});

app.post("/api/v1/providers", async (req, res) => {
  const name = String(req.body.name || "").trim();
  const phone = String(req.body.phone || "").trim();
  const cnic = String(req.body.cnic || "").trim();
  const trade = String(req.body.trade || "").trim();
  if (!name || !phone || !cnic || !trade) {
    return res.status(400).json({ error: "name, phone, cnic, and trade are required" });
  }

  try {
    const specialisation = await db("specialisations")
      .select("id", "name")
      .whereRaw("lower(name) = lower(?)", [trade])
      .first();
    if (!specialisation) {
      return res.status(404).json({ error: `No trade called ${trade} was found` });
    }
    const { exact } = await findProviderNameMatches(name, specialisation.id);
    if (exact) {
      return res.status(409).json({ error: existingNameMessage });
    }
    const takenPhone = await db("providers").select("id").where("phone", phone).first();
    if (takenPhone) {
      return res.status(409).json({ error: "That phone number is already registered" });
    }
    const takenCnic = await db("providers").select("id").where("cnic", cnic).first();
    if (takenCnic) {
      return res.status(409).json({ error: "That CNIC is already registered" });
    }

    const [provider] = await db("providers")
      .insert({
        auth_user_id: crypto.randomUUID(),
        name,
        phone,
        cnic,
        status: "ONLINE",
        designation: specialisation.name,
        specialisation_id: specialisation.id,
        rating: 0,
        inspection_fee: 0,
        services_provided_count: 0
      })
      .returning(["id", "name", "phone", "status"]);
    res.status(201).json({
      ...provider,
      rating: 0,
      inspectionFee: 0,
      specialisationId: specialisation.id,
      specialisationName: specialisation.name
    });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to register provider" });
  }
});

app.get("/api/v1/providers/:providerId", async (req, res) => {
  try {
    const provider = await db("providers as p")
      .leftJoin("specialisations as s", "s.id", "p.specialisation_id")
      .select(
        "p.id",
        "p.name",
        "p.phone",
        "p.status",
        "p.designation",
        "p.rating",
        "p.inspection_fee as inspectionFee",
        "p.services_provided_count as servicesProvidedCount",
        "s.id as specialisationId",
        "s.name as specialisationName"
      )
      .where("p.id", req.params.providerId)
      .first();
    if (!provider) return res.status(404).json({ error: "Provider not found" });
    res.json({
      ...provider,
      rating: Number(provider.rating),
      inspectionFee: Number(provider.inspectionFee)
    });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load provider" });
  }
});

app.patch("/api/v1/providers/:providerId/inspection-fee", async (req, res) => {
  const inspectionFee = money(req.body.inspectionFee);
  if (inspectionFee == null) {
    return res.status(400).json({ error: "inspectionFee must be a non-negative number" });
  }

  try {
    const updated = await db("providers")
      .where("id", req.params.providerId)
      .update({ inspection_fee: inspectionFee, updated_at: db.fn.now() });
    if (updated !== 1) return res.status(404).json({ error: "Provider not found" });
    res.json({ providerId: req.params.providerId, inspectionFee });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to update inspection fee" });
  }
});

app.patch("/api/v1/providers/:providerId/rating", async (req, res) => {
  const stars = Number(req.body.rating);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) {
    return res.status(400).json({ error: "rating must be a whole number from 1 to 5" });
  }

  try {
    const current = await db("providers").where("id", req.params.providerId).first();
    if (!current) return res.status(404).json({ error: "Provider not found" });
    const rating = Math.round(((Number(current.rating) + stars) / 2) * 10) / 10;
    const updated = await db("providers")
      .where("id", req.params.providerId)
      .update({ rating, updated_at: db.fn.now() });
    if (updated !== 1) return res.status(404).json({ error: "Provider not found" });
    res.json({ providerId: req.params.providerId, rating });
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to update rating" });
  }
});

app.post("/api/v1/domestic-requests", async (req, res) => {
  const {
    userId,
    providerId,
    specialisationId,
    description,
    address,
    lat,
    lng
  } = req.body;

  if (!userId || !providerId || !specialisationId
    || !String(description || "").trim() || !String(address || "").trim()) {
    return res.status(400).json({
      error: "userId, providerId, specialisationId, description, and address are required"
    });
  }
  if (lat != null || lng != null) {
    if (!validCoordinates(lat, lng)) {
      return res.status(400).json({ error: "lat and lng must both be valid coordinates" });
    }
  }

  try {
    const created = await db.transaction(async (trx) => {
      const user = await trx("users").select("id").where("id", userId).first();
      if (!user) return { statusCode: 404, body: { error: "User not found" } };

      const provider = await trx("providers")
        .select("id", "specialisation_id", "status")
        .where("id", providerId)
        .first();
      if (!provider) return { statusCode: 404, body: { error: "Provider not found" } };
      if (provider.specialisation_id !== specialisationId) {
        return { statusCode: 409, body: { error: "Provider does not offer this specialisation" } };
      }

      const [request] = await trx("domestic_requests")
        .insert({
          user_id: userId,
          provider_id: providerId,
          specialisation_id: specialisationId,
          description: String(description).trim(),
          address: String(address).trim(),
          location: validCoordinates(lat, lng) ? point(trx, lat, lng) : null,
          status: "PENDING"
        })
        .returning("id");

      return { statusCode: 201, requestId: request.id };
    });

    if (created.statusCode !== 201) {
      return res.status(created.statusCode).json(created.body);
    }
    const payload = await getDomesticRequest(created.requestId);
    emitDomesticRequest(payload, "domestic.requested");
    res.status(201).json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to create domestic request" });
  }
});

app.get("/api/v1/domestic-requests/:requestId", async (req, res) => {
  try {
    const payload = await getDomesticRequest(req.params.requestId);
    if (!payload) return res.status(404).json({ error: "Domestic request not found" });
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load domestic request" });
  }
});

app.get("/api/v1/providers/:providerId/requests", async (req, res) => {
  try {
    const requests = await db("domestic_requests as r")
      .leftJoin("specialisations as s", "s.id", "r.specialisation_id")
      .leftJoin("users as u", "u.id", "r.user_id")
      .leftJoin("providers as p", "p.id", "r.provider_id")
      .select(
        "r.id",
        "r.status",
        "r.description",
        "r.address",
        "r.created_at",
        "r.updated_at",
        "r.specialisation_id",
        "s.name as specialisation_name",
        "r.user_id",
        "u.name as user_name",
        "u.phone as user_phone",
        "r.provider_id",
        "p.name as provider_name",
        "p.phone as provider_phone",
        "p.rating as provider_rating",
        "p.inspection_fee as provider_inspection_fee",
        "receipt.quoted_total",
        "receipt.inspection_fee as receipt_inspection_fee",
        "receipt.final_total",
        "receipt.status as receipt_status"
      )
      .leftJoin("receipts as receipt", "receipt.request_id", "r.id")
      .where("r.provider_id", req.params.providerId)
      .orderBy("r.created_at", "desc");
    res.json(requests.map(domesticRequestPayload));
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load provider requests" });
  }
});

app.patch("/api/v1/providers/:providerId/requests/:requestId/accept", async (req, res) => {
  try {
    const updated = await db("domestic_requests")
      .where({ id: req.params.requestId, provider_id: req.params.providerId, status: "PENDING" })
      .update({ status: "ACCEPTED", updated_at: db.fn.now() });
    if (updated !== 1) {
      return res.status(409).json({ error: "Request is not pending for this provider" });
    }
    const payload = await getDomesticRequest(req.params.requestId);
    emitDomesticRequest(payload, "domestic.accepted");
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to accept domestic request" });
  }
});

app.post("/api/v1/providers/:providerId/requests/:requestId/cost", async (req, res) => {
  const quotedTotal = req.body?.quotedTotal;
  const parsedQuotedTotal = quotedTotal == null ? null : money(quotedTotal);
  if (parsedQuotedTotal == null) {
    return res.status(400).json({ error: "quotedTotal must be a non-negative number" });
  }

  try {
    const result = await db.transaction(async (trx) => {
      const request = await trx("domestic_requests")
        .select("id", "status", "provider_id", "user_id")
        .where({ id: req.params.requestId, provider_id: req.params.providerId })
        .forUpdate()
        .first();
      if (!request) return { statusCode: 404, error: "Request not found for this provider" };
      if (request.status !== "ACCEPTED") {
        return { statusCode: 409, error: "Cost can only be submitted for an ACCEPTED request" };
      }

      const existingReceipt = await trx("receipts")
        .select("id")
        .where("request_id", request.id)
        .first();
      if (existingReceipt) {
        return { statusCode: 409, error: "A cost has already been submitted for this request" };
      }

      const provider = await trx("providers")
        .select("inspection_fee")
        .where("id", request.provider_id)
        .first();
      if (!provider) return { statusCode: 404, error: "Provider not found" };

      await trx("receipts").insert({
        request_id: request.id,
        provider_id: request.provider_id,
        user_id: request.user_id,
        inspection_fee: provider.inspection_fee,
        quoted_total: parsedQuotedTotal,
        final_total: null,
        status: "NEGOTIABLE"
      });
      return { statusCode: 200 };
    });

    if (result.error) return res.status(result.statusCode).json({ error: result.error });
    const payload = await getDomesticRequest(req.params.requestId);
    emitDomesticRequest(payload, "domestic.cost_submitted");
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to submit domestic cost" });
  }
});

app.post("/api/v1/domestic-requests/:requestId/cost-decision", async (req, res) => {
  const decision = String(req.body?.decision || "").toUpperCase();
  if (!["ACCEPT", "REFUSE"].includes(decision)) {
    return res.status(400).json({ error: "decision must be ACCEPT or REFUSE" });
  }

  try {
    const result = await db.transaction(async (trx) => {
      const request = await trx("domestic_requests")
        .select("id")
        .where("id", req.params.requestId)
        .forUpdate()
        .first();
      if (!request) return { statusCode: 404, error: "Domestic request not found" };

      const receipt = await trx("receipts")
        .select("id", "inspection_fee", "quoted_total", "status")
        .where({ request_id: request.id, status: "NEGOTIABLE" })
        .forUpdate()
        .first();
      if (!receipt) {
        return { statusCode: 409, error: "No negotiable cost exists for this request" };
      }

      const accepted = decision === "ACCEPT";
      await trx("receipts")
        .where({ id: receipt.id, status: "NEGOTIABLE" })
        .update({
          final_total: accepted
            ? trx.raw("inspection_fee + quoted_total")
            : receipt.inspection_fee,
          status: accepted ? "ACCEPTED" : "DECLINED",
          responded_at: trx.fn.now(),
          updated_at: trx.fn.now()
        });
      return { statusCode: 200 };
    });

    if (result.error) return res.status(result.statusCode).json({ error: result.error });
    const payload = await getDomesticRequest(req.params.requestId);
    emitDomesticRequest(payload, "domestic.cost_decided");
    res.json(payload);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to save domestic cost decision" });
  }
});

const port = process.env.PORT || 3000;
server.listen(port, () => {
  console.log(`Backend running on http://localhost:${port}`);
});
