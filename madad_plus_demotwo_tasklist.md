# Madad+ demo two task list

Ahmed's `origin/Web` already has hospital pins, the pulsing pin, OSRM road routes, and Mark free. The earlier list said they were missing because it was read from a stale local `Web`.

## Ambulance

- [x] Find my location and a typed address, shown as a pin. The hardcoded location is gone.
- [x] Mic, English and Urdu transcription, and the what happened and people fields. English and Urdu work.
- [x] The missing-fields popup, with partial answers kept and a mic-free form when nothing comes back.

## Dispatcher

- [x] Hospital pins on the map.
- [x] Ambulance driving on roads to the user, then to the hospital. It animates on the dispatcher only, since the backend never moves a unit.
- [x] Mark free.
- [ ] Pulsing pin where a request came from. It is in the code, and it has not been ticked.
- [ ] Ambulance icons colored for free, busy, and unavailable. The screenshots only show busy units.
- [ ] Five ambulances free on the live server. Mark free works, so this can be done from the dispatcher. The last check had only A-04 free.

## Driver

Counted done on your word. There is no screenshot of that run.

- [x] Address, incident, extra details, and phone number show from the user's request.
- [x] The map stays hidden until a request arrives, then shows the user's pin. The hospital pin appears after Picked up.
- [x] The user phone and the driver phone show the same address and incident.
- [x] Straight lines on the driver phone are fine for now. Roads come later.

## Domestic

- [x] A booking from the user phone reaches the provider phone. Tested on both emulators.
- [x] The user sees each provider's rating and inspection charge.
- [x] The provider can save an inspection charge. The saved value was Rs. 500, which was already the value.
- [ ] Add a second provider for each trade. The user cannot choose between providers until then.
- [ ] Change the fee to a new number and confirm the user phone shows it.
- [ ] Accept the job on the provider phone and watch the user phone leave "Finding a plumber."

## Other

- [ ] One full run: an ambulance request from the phone showing on the dispatcher and the driver phone together, live.
- [ ] Choosing the hospital from the incident and the distance. The hospital table has no incident data, and the server picks only the nearest hospital.
