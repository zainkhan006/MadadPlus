require("dotenv").config();

const express = require("express");
const cors = require("cors");
const http = require("http");
const { Server } = require("socket.io");
const db = require("./db");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" }
});

app.use(cors());
app.use(express.json());

io.on("connection", (socket) => {
  socket.on("join:dispatch", () => {
    socket.join("dispatch");
  });

  socket.on("join:request", (requestId) => {
    socket.join(`request:${requestId}`);
  });
});

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
    const ambulances = await db("ambulances").select(
      "id",
      "label",
      "status",
      db.raw("ST_Y(location::geometry) as lat"),
      db.raw("ST_X(location::geometry) as lng")
    );

    res.json(ambulances);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to load ambulances" });
  }
});

app.post("/api/v1/emergency-requests", async (req, res) => {
  const { lat, lng, type } = req.body;

  if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng)) || type !== "ambulance") {
    return res.status(400).json({
      error: "lat, lng, and type: 'ambulance' are required"
    });
  }

  try {
    const result = await db.transaction(async (trx) => {
      const [organization] = await trx("organizations").select("id").limit(1);
      if (!organization) {
        throw new Error("No ambulance organization has been configured");
      }

      const point = "ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography";
      const bindings = [Number(lng), Number(lat)];
      const ambulances = await trx("ambulances")
        .select("id", "label", "status")
        .select(trx.raw(`ST_Distance(location, ${point}) / 1000 as distance_km`, bindings))
        .where("organization_id", organization.id)
        .orderByRaw(`location <-> ${point}`, bindings);

      const available = ambulances.filter((ambulance) => ambulance.status === "AVAILABLE");
      let assigned = null;

      for (const candidate of available) {
        const updated = await trx("ambulances")
          .where({ id: candidate.id, status: "AVAILABLE" })
          .update({ status: "BUSY", updated_at: trx.fn.now() });

        if (updated === 1) {
          assigned = candidate;
          break;
        }
      }

      const [request] = await trx("emergency_requests")
        .insert({
          organization_id: organization.id,
          assigned_ambulance_id: assigned?.id || null,
          type,
          status: assigned ? "ASSIGNED" : "QUEUED",
          pickup_location: trx.raw(`ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography`, bindings)
        })
        .returning(["id", "status"]);

      const nearest = ambulances[0];
      const consideredNearest = nearest && nearest.id !== assigned?.id && nearest.status !== "AVAILABLE"
        ? {
            id: nearest.id,
            label: nearest.label,
            distanceKm: Number(nearest.distance_km),
            status: nearest.status
          }
        : null;

      return {
        requestId: request.id,
        status: request.status,
        assignedAmbulance: assigned
          ? {
              id: assigned.id,
              label: assigned.label,
              distanceKm: Number(assigned.distance_km)
            }
          : null,
        consideredNearest
      };
    });

    io.to("dispatch").emit("queue.new", result);
    io.to(`request:${result.requestId}`).emit(
      result.status === "ASSIGNED" ? "request.assigned" : "request.queued",
      result
    );

    res.status(201).json(result);
  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Unable to create emergency request" });
  }
});

const port = process.env.PORT || 3000;

server.listen(port, () => {
  console.log(`Backend running on http://localhost:${port}`);
});
