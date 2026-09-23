const QUEUED_STATUSES = ["QUEUED", "TRANSFER_QUEUED"];

function statusForPhase(phase) {
  return phase === "TRANSFER" ? "TRANSFER_EN_ROUTE" : "ASSIGNED";
}

async function getRequest(trx, requestId) {
  return trx("emergency_requests")
    .select(
      "id",
      "organization_id",
      "status",
      "current_phase",
      "assigned_ambulance_id",
      "dispatch_location"
    )
    .where("id", requestId)
    .first();
}

async function nextAssignmentSequence(trx, requestId) {
  const row = await trx("request_assignments")
    .where("request_id", requestId)
    .max("sequence as value")
    .first();

  return Number(row?.value || 0) + 1;
}

async function closeActiveAssignment(trx, requestId, reason) {
  await trx("request_assignments")
    .where({ request_id: requestId, status: "ACTIVE" })
    .update({
      status: "RELEASED",
      released_at: trx.fn.now(),
      release_reason: reason,
      updated_at: trx.fn.now()
    });
}

async function assignSpecific(trx, requestId, ambulanceId, phase, reason) {
  const request = await getRequest(trx, requestId);
  if (!request || !QUEUED_STATUSES.includes(request.status)) {
    return false;
  }

  const [ambulance] = await trx("ambulances")
    .select("id", "driver_id")
    .where({
      id: ambulanceId,
      organization_id: request.organization_id,
      status: "FREE"
    })
    .whereNotExists(
      trx("request_ambulance_blocks")
        .select(trx.raw("1"))
        .whereRaw("request_ambulance_blocks.request_id = ?", [requestId])
        .whereRaw("request_ambulance_blocks.ambulance_id = ambulances.id")
    )
    .limit(1);

  if (!ambulance) {
    return false;
  }

  const updated = await trx("ambulances")
    .where({ id: ambulanceId, status: "FREE" })
    .update({ status: "BUSY", updated_at: trx.fn.now() });

  if (updated !== 1) {
    return false;
  }

  await trx("request_assignments").insert({
    request_id: requestId,
    ambulance_id: ambulanceId,
    driver_id: ambulance.driver_id,
    sequence: await nextAssignmentSequence(trx, requestId),
    phase,
    reason
  });

  await trx("emergency_requests")
    .where("id", requestId)
    .update({
      assigned_ambulance_id: ambulanceId,
      status: statusForPhase(phase),
      current_phase: phase,
      updated_at: trx.fn.now()
    });

  return true;
}

async function assignNearest(trx, requestId, phase, reason) {
  const request = await getRequest(trx, requestId);
  if (!request || !request.dispatch_location) {
    return false;
  }

  const candidates = await trx("ambulances")
    .select("id")
    .where({ organization_id: request.organization_id, status: "FREE" })
    .whereNotExists(
      trx("request_ambulance_blocks")
        .select(trx.raw("1"))
        .whereRaw("request_ambulance_blocks.request_id = ?", [requestId])
        .whereRaw("request_ambulance_blocks.ambulance_id = ambulances.id")
    )
    .orderByRaw(
      "ambulances.location <-> (select dispatch_location from emergency_requests where id = ?)",
      [requestId]
    );

  for (const candidate of candidates) {
    if (await assignSpecific(trx, requestId, candidate.id, phase, reason)) {
      return true;
    }
  }

  return false;
}

async function dispatchQueuedForAmbulance(trx, ambulanceId) {
  const ambulance = await trx("ambulances")
    .select("id", "organization_id", "location")
    .where("id", ambulanceId)
    .first();

  if (!ambulance) {
    return null;
  }

  const waiting = await trx("emergency_requests")
    .select("id", "current_phase")
    .where("organization_id", ambulance.organization_id)
    .whereIn("status", QUEUED_STATUSES)
    .orderByRaw(
      "dispatch_location <-> (select location from ambulances where id = ?)",
      [ambulanceId]
    );

  for (const request of waiting) {
    const phase = request.current_phase === "TRANSFER" ? "TRANSFER" : "PICKUP";
    if (await assignSpecific(trx, request.id, ambulanceId, phase, "QUEUE")) {
      return request.id;
    }
  }

  return null;
}

async function requestPayload(trx, requestId) {
  const request = await trx("emergency_requests as r")
    .leftJoin("ambulances as a", "a.id", "r.assigned_ambulance_id")
    .leftJoin("drivers as d", "d.id", "a.driver_id")
    .select(
      "r.id as request_id",
      "r.status",
      "r.current_phase",
      "r.type",
      "r.caller_phone",
      "r.pickup_address",
      "r.emergency_description",
      "r.hospital_address",
      "r.assigned_ambulance_id",
      "a.label as ambulance_label",
      "d.id as driver_id",
      "d.name as driver_name",
      "d.phone as driver_phone",
      trx.raw("ST_Y(a.location::geometry) as ambulance_lat"),
      trx.raw("ST_X(a.location::geometry) as ambulance_lng")
    )
    .where("r.id", requestId)
    .first();

  if (!request) {
    return null;
  }

  return {
    requestId: request.request_id,
    status: request.status,
    phase: request.current_phase,
    type: request.type,
    callerPhone: request.caller_phone,
    pickupAddress: request.pickup_address,
    emergencyDescription: request.emergency_description,
    hospitalAddress: request.hospital_address,
    assignedAmbulance: request.assigned_ambulance_id
      ? {
          id: request.assigned_ambulance_id,
          label: request.ambulance_label,
          driver: request.driver_id
            ? {
                id: request.driver_id,
                name: request.driver_name,
                phone: request.driver_phone
              }
            : null,
          location: {
            lat: Number(request.ambulance_lat),
            lng: Number(request.ambulance_lng)
          }
        }
      : null
  };
}

module.exports = {
  QUEUED_STATUSES,
  assignNearest,
  assignSpecific,
  closeActiveAssignment,
  dispatchQueuedForAmbulance,
  getRequest,
  requestPayload
};
