# Madad+ demo status, v4 through v4.3

Checked against the phone code on `mobiletest`, the backend on `main`, the dispatcher on `Web`, and the live server at `https://madadplus.onrender.com`.

Straight-line maps count as done. Road tracking is listed under yet to do.

## Done

### Ambulance

- [x] Replace the hardcoded DHA pin with Find my location and a typed address.
- [x] Show the chosen place as a pin on the map.
- [x] Send that latitude and longitude with the request.
- [x] Add a mic button before the details form, using Gemini's free transcription tier for English and Urdu.
- [x] From the speech, fill what happened and people needing help.
- [x] If neither comes back, the popup names both missing fields and opens the details form empty, with no mic.
- [x] If only one comes back, the popup names the missing field and the form keeps the one that was understood.
- [x] What happened and people needing help stay required. Extra details stay optional.

### Ambulance driver

- [x] Show the address, incident, extra details, and phone number from the user's live request.
- [x] Keep the map hidden until a request arrives.
- [x] When a request arrives, show the map with the user's pin and a straight line from the ambulance.
- [x] After Picked up, show the hospital pin and a straight line to it.
- [x] Send Picked up to the server so the trip can continue to the hospital.

### Backend

- [x] Store the request's address, latitude, longitude, incident, people count, input method, and extra details.
- [x] Add the ambulance status update so Mark free can set FREE.
- [x] In the seed file, set A-01, A-02, A-04, A-05, and A-06 to FREE. A-03 and A-07 stay BUSY.
- [x] Accept Picked up from the driver so the trip can continue to the hospital.
- [x] Add a domestic request the user can create and the provider can see and accept.
- [x] Store each provider's inspection charge.
- [x] Store a rating for each provider.

### Dispatcher

- [x] Draw each unit as an ambulance icon, colored for free, busy, and unavailable.

## Yet to do

### Domestic services and domestic provider

The screens for this are already in the phone app. They have not been tried on a device.

- [ ] Show each provider's rating and the inspection charge that provider set.
- [ ] Seed a second provider for each trade, so the user can choose between two. The live server has one plumber, one electrician, and one AC technician.
- [ ] Send the domestic request to the server and confirm the provider's phone sees the same job.
- [ ] Let the provider set their own inspection charge and save it on the server.

### Live ambulances

- [ ] Set five of A-01 through A-07 to FREE on the live server. The last check found only A-04 and A-05 free. The seed file already has five free, but the running database does not match it.

### Dispatcher map

- [ ] Put the nine hospital pins on the `Web` branch. The pin code from v4.1 is in `stash@{2}` (`dispatcher on main`). `Web` does not have it. The nine hospitals are already on the live server: Parklane Hospital, Clifton Kidney & General Hospital, South City Hospital, Infinity Eye Care Centre, Clifton Hospital, KKT Orthopedic Spine Center, Niazi Hospital, Medi Life Clinics, and Doctors Plaza.
- [ ] When a request arrives, pulse a pin at the user's coordinates.
- [ ] Move the assigned ambulance along a street route to that pin.
- [ ] After Picked up, continue the route from the user to the chosen hospital.

### Driver map, later

- [ ] Replace the straight line on the driver map with a route that follows roads, first to the user and then to the hospital.

## Cannot do yet

### Choose the hospital from the incident and the distance

- [ ] Choose the hospital from the named list using the incident and the distance.

The hospital table stores a name, phone, address, location, and whether it is active. It does not store which incidents a hospital takes. On Picked up, the server picks the nearest active hospital to the pickup point and ignores what happened.

To finish this:

1. Decide which of Cardiac, Accident, Injury, and Medical each of the nine hospitals takes, and store that on the hospital.
2. On Picked up, keep hospitals that match the incident, then pick the nearest of those. If none match, use the nearest hospital overall.
3. The pickup response already sends the hospital name, address, and location, so the phone and the dispatcher can show whichever hospital the server chose.

### Move the dispatcher ambulance along streets

- [ ] Move the assigned ambulance along a street route to the user, then to the hospital, on the dispatcher map.

The dispatcher only moves an ambulance when the server sends a new position. The driver app draws its own straight line and does not send positions along a road. The server has no road route either.

To finish this:

1. When a request is assigned, ask a road router for the driving line from the ambulance to the pickup, and draw that line. If the router does not answer within 5 seconds, draw a straight line.
2. Step the ambulance icon along that line until the driver taps Picked up.
3. After Picked up, ask for the driving line from the pickup to the hospital and step the icon along it until the request is complete.
