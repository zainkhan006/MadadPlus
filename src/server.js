require("dotenv").config();

const express = require("express");
const cors = require("cors");
const http = require("http");
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

  try {
    const result = await db.transaction(async (trx) => {
      const orgId = await organizationId(trx);
      const pointValue = point(trx, lat, lng);
      const [request] = await trx("emergency_requests")
        .insert({
          organization_id: orgId,
          type,
          caller_phone: callerPhone || null,
          pickup_address: address || null,
          emergency_description: description || null,
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
    const request = await getRequest(trx, requestId);

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

    await trx("emergency_requests")
      .where("id", requestId)
      .update({
        status: transition.status,
        current_phase: transition.phase,
        picked_up_at: action === "pickup" && request.status !== "TRANSFER_EN_ROUTE"
          ? trx.fn.now()
          : undefined,
        arrived_hospital_at: action === "hospital" ? trx.fn.now() : undefined,
        updated_at: trx.fn.now()
      });

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
      await trx("ambulance_location_updates").insert({
        ambulance_id: ambulance.id,
        driver_id: req.params.driverId,
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

async function markUnavailable(driverId, reason, lat, lng, ambulanceIdOverride) {
  return db.transaction(async (trx) => {
    const ambulanceQuery = trx("ambulances")
      .select("id", "status")
      .first();
    if (ambulanceIdOverride) {
      ambulanceQuery.where("id", ambulanceIdOverride);
    } else {
      ambulanceQuery.where("driver_id", driverId);
    }
    const ambulance = await ambulanceQuery;
    if (!ambulance) return { statusCode: 404, body: { error: "Driver ambulance not found" } };

    if (validCoordinates(lat, lng)) {
      await trx("ambulances").where("id", ambulance.id).update({
        location: point(trx, lat, lng),
        last_location_at: trx.fn.now(),
        updated_at: trx.fn.now()
      });
    }

    const request = await trx("emergency_requests")
      .select("id", "status", "pickup_location")
      .where("assigned_ambulance_id", ambulance.id)
      .whereNotIn("status", ["COMPLETED", "CANCELLED"])
      .first();

    await trx("ambulances").where("id", ambulance.id).update({
      status: "UNAVAILABLE",
      unavailable_reason: reason || "Driver reported a breakdown",
      updated_at: trx.fn.now()
    });

    let replacementRequestId = null;
    if (request) {
      await closeActiveAssignment(trx, request.id, "AMBULANCE_UNAVAILABLE");
      const afterPickup = ["PICKED_UP", "EN_ROUTE_HOSPITAL", "ARRIVED"].includes(request.status);
      const currentLocation = await trx("ambulances")
        .select("location")
        .where("id", ambulance.id)
        .first();
      const dispatchLocation = validCoordinates(lat, lng)
        ? point(trx, lat, lng)
        : afterPickup
          ? currentLocation.location
          : request.pickup_location;

      await trx("emergency_requests")
        .where("id", request.id)
        .update({
          assigned_ambulance_id: null,
          status: afterPickup ? "TRANSFER_QUEUED" : "QUEUED",
          current_phase: afterPickup ? "TRANSFER" : "PICKUP",
          dispatch_location: dispatchLocation,
          breakdown_location: validCoordinates(lat, lng)
            ? point(trx, lat, lng)
            : currentLocation.location,
          updated_at: trx.fn.now()
        });

      await assignNearest(
        trx,
        request.id,
        afterPickup ? "TRANSFER" : "PICKUP",
        "BREAKDOWN_REPLACEMENT"
      );
      replacementRequestId = request.id;
    }

    return {
      statusCode: 200,
      body: { ambulanceId: ambulance.id, status: "UNAVAILABLE", replacementRequestId },
      ambulanceId: ambulance.id
    };
  });
}

app.patch("/api/v1/drivers/:driverId/unavailable", async (req, res) => {
  try {
    const result = await markUnavailable(
      req.params.driverId,
      req.body.reason,
      req.body.lat,
      req.body.lng
    );
    if (result.statusCode === 200) {
      await emitAmbulance(result.ambulanceId);
      if (result.body.replacementRequestId) {
        const replacement = await db.transaction((trx) => requestPayload(trx, result.body.replacementRequestId));
        emitRequest(replacement, replacement.status === "QUEUED" || replacement.status === "TRANSFER_QUEUED" ? "request.queued" : "request.reassigned");
        if (replacement.assignedAmbulance) await emitAmbulance(replacement.assignedAmbulance.id);
      }
    }
    res.status(result.statusCode).json(result.body);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to mark ambulance unavailable" });
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
      await emitAmbulance(req.params.ambulanceId);
      return res.status(result.statusCode).json(result.body);
    }

    const result = await db.transaction(async (trx) => {
      const updated = await trx("ambulances")
        .where({ id: req.params.ambulanceId, status: "UNAVAILABLE" })
        .update({ status: "FREE", unavailable_reason: null, updated_at: trx.fn.now() });
      if (!updated) return null;
      const waitingRequestId = await dispatchQueuedForAmbulance(trx, req.params.ambulanceId);
      return { waitingRequestId };
    });
    if (!result) return res.status(409).json({ error: "Ambulance is not UNAVAILABLE" });
    await emitAmbulance(req.params.ambulanceId);
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

const port = process.env.PORT || 3000;
server.listen(port, () => {
  console.log(`Backend running on http://localhost:${port}`);
});
