# Driver emergency request contract

## Driver request data

`GET /api/v1/drivers/{driverId}/portal` returns the active call in `activeRequest`.
The same request shape is sent in driver and request-room socket events. Relevant
fields are:

- `additionalDetails`: the caller's free-text details (for example, "I am burnt").
- `pickupLocation`: the caller's original location.
- `dispatchLocation`: the destination for the current leg. Use this for navigation;
  during `phase: "TRANSFER"`, it is the stranded ambulance's latest location.
- `phase`: `PICKUP`, `TRANSFER`, or `HOSPITAL`.
- `hospital.location`: the hospital destination when available.

## Change ambulance

Use this when the current ambulance cannot continue:

```http
PATCH /api/v1/drivers/{driverId}/requests/{requestId}/reassign
Content-Type: application/json
```

```json
{
  "reason": "Vehicle breakdown",
  "lat": 24.8607,
  "lng": 67.0011
}
```

`lat` and `lng` are optional, but must be sent together. If omitted, the server
uses the ambulance's last saved location. The endpoint verifies that the request
is currently assigned to this driver's ambulance, marks that ambulance
`UNAVAILABLE`, then chooses the nearest free, unblocked ambulance.

For a call still in `PICKUP`, the replacement is dispatched to the caller's
`pickupLocation` and receives the caller details, including `additionalDetails`.
After pickup, the replacement is dispatched to the current ambulance location;
the request enters `TRANSFER` until the replacement confirms pickup.

Successful response:

```json
{
  "ambulanceId": "old-ambulance-id",
  "status": "UNAVAILABLE",
  "replacementRequestId": "request-id",
  "reassignmentStatus": "ASSIGNED",
  "callerMessage": "Your ambulance has changed to A-02.",
  "request": {
    "requestId": "request-id",
    "status": "TRANSFER_EN_ROUTE",
    "phase": "TRANSFER",
    "pickupLocation": { "lat": 24.86, "lng": 67.00 },
    "dispatchLocation": { "lat": 24.87, "lng": 67.01 },
    "additionalDetails": "I am burnt",
    "assignedAmbulance": { "id": "new-ambulance-id", "label": "A-02" }
  }
}
```

If no free ambulance is available, the request is still successful but
`reassignmentStatus` is `QUEUED`, `request.assignedAmbulance` is `null`, and
`callerMessage` says a replacement is being found. A mismatched driver/request
returns `404`; a request in a non-reassignable state returns `409`.

## Socket events

Join `request:{requestId}` to receive caller updates. When reassigned, the server
emits `request.reassigned` with the request fields above, plus
`reassignmentStatus` and `callerMessage`. If no replacement is free yet, it emits
`request.queued` with the same message fields. The newly assigned driver also
receives `request.reassigned` in `driver:{driverId}`.
