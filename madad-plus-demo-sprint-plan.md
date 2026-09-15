# Madad+ mini-MVP sprint — team execution plan

v3 — 2026-09-12 (demo moved up to Tue Sep 15; the old Day 5 and Day 6 are now one day)

## 0. Situation

Team: Ibad owns backend, Zain owns mobile, Syed Ahmed owns web. Docs/QA and
deployment work are shared by all three, layered on top of their daily branch work.

Two deadlines:

- Demo: Tuesday, September 15, 2026 (day 5 of this sprint). The teacher wants
a working slice, not slides.
- Real MVP: first week of October 2026.

Stack is locked to madad-plus-final-techstack.md: Flutter + Provider (mobile),
Node + Express + Knex (backend), Supabase (Postgres + PostGIS), Socket.IO
(realtime), Google Maps Platform, Firebase Auth + JWT, plain HTML/CSS/JS
(web dashboard), Render + GitHub Pages (hosting). Ignore any other stack notes
floating around the repo — this file wins.

Repo reality: `main`, `backend`, `mobile`, `web`, `docs` branches exist. Every
one of them currently holds nothing but the wireframe HTML. Nobody has
scaffolded a real app yet. There is no separate "deployment" branch, and there
shouldn't be one — deployment is what happens when backend/mobile/web changes
land on `main`. Each branch carries its own release config: Render config in
backend, GitHub Pages workflow in web, build/signing steps in mobile. That
only holds together if Render's auto-deploy branch and GitHub Pages' publish
source are both actually pointed at `main`, not at `backend` or `web` directly
— otherwise a push to your own branch goes live before anyone reviews it. Set
that up on Day 0 (see the git-workflow-master task below); it costs five
minutes now and saves an argument later.

## 1. Demo scope — locked, do not expand this week

- 1 ambulance organization ("City Emergency Services", matching the
wireframe), 5 ambulances, fixed seed coordinates around DHA Phase 5, Karachi.
- The one thing this demo has to prove live: a customer requests an ambulance,
the nearest one is already BUSY, the system switches to the next-nearest
AVAILABLE one, and both the phone and the dispatcher screen show it happening.
- Switching means: computed once, at request time, by filtering to AVAILABLE
ambulances and picking the closest. No mid-flight reassignment (an ambulance
going BUSY after it's already assigned) — that's real-MVP scope, not this
demo's.
- Customer side is the real Flutter app. No web shortcut.
- Web branch, for now, is dispatcher-only: live map, queue, assign. Admin
screens (managing organizations, adding ambulances) are MVP scope.
- Login and OTP are a tap-through UI mock for the demo — no real Firebase
verification wired up. Real OTP verification is Week 2 scope (Section 6).
The backend should not require a verified JWT on `/emergency-requests`
until then; gating the demo endpoint behind real auth mobile never wired
up is exactly the kind of thing that only shows up on Day 3, integration
day, when it's expensive to fix.
- Demo data has to be deterministic: one ambulance is seeded BUSY and sits
physically closer to the scripted pickup point than the next-nearest
AVAILABLE one. The switch has to fire the same way every time you run it,
not "usually." That also means whichever ambulance gets assigned during a
rehearsal run needs to go back to AVAILABLE once that run's request reaches
COMPLETED — otherwise the second rehearsal run starts from a different world
than the first, and "every time" quietly becomes "the first time." See the
Day 4 backend task below.



## 2. Branches, owners, personas


| Branch       | Owner              | Personas to load                                                                                                                                                                                                                        | Owns                                                                                                                  |
| ------------ | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| backend      | Ibad               | @.cursor/rules/backend-architect.mdc , @.cursor/rules/database-optimizer.mdc , @.cursor/rules/realtime-collaboration-engineer.mdc                                                                                                       | API, DB schema, the dispatch/switch algorithm, Socket.IO, Render config                                               |
| mobile       | Zain               | @.cursor/rules/ui-designer.mdc , @.cursor/rules/mobile-app-builder.mdc                                                                                                                                                                  | Flutter app, theme pulled from wireframe tokens, emergency flow, APK build                                            |
| web          | Syed Ahmed         | @.cursor/rules/frontend-developer.mdc                                                                                                                                                                                                   | Dispatcher dashboard, Google Maps JS, Socket.IO client, GitHub Pages workflow                                         |
| docs         | shared (all three) | @.cursor/rules/git-workflow-master.mdc , @.cursor/rules/technical-writer.mdc , @.cursor/rules/api-tester.mdc , @.cursor/rules/test-automation-engineer.mdc , @.cursor/rules/evidence-collector.mdc , @.cursor/rules/reality-checker.mdc | Branch/PR conventions, API contract doc, README, test collection, smoke check, screenshot evidence, go/no-go sign-off |
| "deployment" | n/a, not a branch  | @.cursor/rules/infrastructure-maintainer.mdc (backend + web release config), @.cursor/rules/mobile-release-engineer.mdc (APK build)                                                                                                     | Cross-cutting — whatever lands on `main` is what's live for the demo                                                  |




## 3. The contract everyone builds against — finish today

API (docs branch owns the file; backend drafts it, mobile and web review it
before backend starts building against it):

```
POST /api/v1/emergency-requests
  headers: Authorization: Bearer <jwt>   (demo: not enforced yet — see Section 1)
  body: { lat: number, lng: number, type: "ambulance" }
  201: {
    requestId: string,
    status: "ASSIGNED" | "QUEUED",
    assignedAmbulance: { id: string, label: string, distanceKm: number } | null,
    consideredNearest: { id: string, label: string, distanceKm: number, status: "BUSY" | "OFFLINE" } | null
  }

GET /api/v1/ambulances
  200: [{ id, label, lat, lng, status: "AVAILABLE" | "BUSY" | "OFFLINE" }]
```

Three rules for that response shape, spelled out now because they change
what mobile and web have to render:

- `assignedAmbulance` is `null` only when `status` is `QUEUED` — there was no
AVAILABLE ambulance anywhere at request time. It is never null on
`ASSIGNED`.
- `consideredNearest` is `null` whenever the nearest ambulance overall was
already the one assigned — no switch happened, nothing to show. It's only
populated when a closer BUSY or OFFLINE ambulance got passed over. This is
the field that makes "switching" visible instead of buried inside a query —
both mobile and web should render it as something like "A-05 was closer but
busy, assigned A-12 instead."
- `distanceKm` is straight-line distance from a PostGIS geography column, not
a Google Distance Matrix road distance. It's good enough to rank which
ambulance is closer; don't present it to a user as an ETA.

Socket.IO:

- Room `request:{requestId}` emits `request.assigned`, `request.enRoute`,
`request.arrived`. Each payload includes the same `{ requestId, status, assignedAmbulance, consideredNearest }` shape as the POST response, so the
phone can render the switch message from any of these events, not only from
the initial request.
- Room `dispatch` emits `queue.new` (same payload shape as above, so the
dispatcher can show which unit got assigned and why for a request it didn't
originate, without a second API call) and `ambulance.updated`
(`{ id, status, lat, lng }`).
- Both clients should auto-reconnect and rejoin their rooms on disconnect.
Render's free tier drops idle connections, and rehearsal Wi-Fi will drop a
few more — this isn't optional polish, it's what keeps a demo run from
silently going stale mid-flow.

One thing the assign logic needs that "filter to AVAILABLE, pick closest"
doesn't say out loud: it has to be one atomic conditional update
(`UPDATE ambulances SET status = 'BUSY' WHERE id = ? AND status = 'AVAILABLE'`,
check rows affected, fall through to the next-nearest candidate on a 0-row
result), inside a single transaction — not a SELECT followed by a separate
UPDATE. With five ambulances and one demo phone this will probably never
actually trigger during the live demo, but it's a real bug the moment two
requests land close together, and it's a much cheaper problem to solve now
than to debug during rehearsal.

Two Google Maps keys are needed, not one: an Android key restricted by
package name plus SHA-1 fingerprint, and a separate web key restricted by
HTTP referrer (the GitHub Pages domain, plus localhost for development). They
carry different restriction types, so one key can't stand in for both.

Accounts still outstanding (you said some are set up, some aren't) get closed
out today, not squeezed in mid-week: Supabase project with PostGIS enabled,
Google Maps Platform billing account plus the two restricted keys above,
Firebase Auth phone provider with test numbers, Render account, GitHub Pages
enabled on the web branch. Whoever's free grabs whichever one is missing —
don't let backend or web sit idle waiting on this.

## 4. Demo sprint, day by day (Sep 10 -> Sep 15)

**Day 0 — Thu Sep 10 (today)**

- Backend: create the Supabase project, enable PostGIS, sketch the schema
(organizations, ambulances, emergency_requests) with database-optimizer,
finalize the API contract draft with backend-architect.
- Mobile: `flutter create` on the mobile branch, pull the theme tokens
straight out of the wireframe's CSS variables, list the exact screens
needed for this slice — the full flow is splash -> onboarding -> login ->
otp -> home -> emergencyType -> emergencyLocation -> emergencyDetails ->
emergencyConfirm -> emergencySearch -> emergencyAssigned/emergencyBusy ->
emergencyEnRoute -> emergencyApproaching -> emergencyArrived ->
emergencyComplete. That's four more screens than a glance at the wireframe
suggests (otp, emergencyDetails, emergencyConfirm, emergencyApproaching) —
worth listing all of them today so they don't turn into a Tuesday
surprise.
- Web: scaffold the plain HTML/CSS/JS dispatcher page reusing the
wireframe's desktop styles, get the Google Maps JS key requested.
- Docs/deploy: decide tonight who grabs which missing account;
git-workflow-master locks `main` to PR-only merges and points Render's
auto-deploy branch and GitHub Pages' publish source at `main` (not at
`backend` or `web`); technical-writer starts `docs/API-CONTRACT.md` with
the shapes above.

**Day 1 — Fri Sep 11**

- Backend: Knex migrations for organizations/ambulances/emergency_requests;
database-optimizer adds a geography column with a GiST index on
ambulances for the nearest-neighbor query; seed script inserts 1 org and
5 ambulances at fixed coordinates, one deliberately BUSY.
- Mobile: build the emergency-flow screens against the wireframe with
hardcoded data (no live API yet), Provider holding local screen state;
ui-designer locks the Flutter theme to match the wireframe exactly.
- Web: static dispatcher page, 5 hardcoded markers matching the seed
coordinates, queue list shell.
- Docs/deploy: api-tester builds a Thunder Client collection against the
backend skeleton so it's ready to fire the moment endpoints exist.

**Day 2 — Sat Sep 12**

- Backend: implement `POST /emergency-requests` (nearest AVAILABLE by
distance, falling through the list, as an atomic conditional update — see
Section 3) and `GET /ambulances`, including the QUEUED path for when no
AVAILABLE ambulance exists. That path was originally scheduled for Day 4,
but it's the same query with an empty-result branch, cheap to build
alongside the main path today, and it keeps Day 4 free for deploying and
polishing instead of writing new logic the day before the freeze.
realtime-collaboration-engineer wires the Socket.IO rooms; deploy the
skeleton to Render (infrastructure-maintainer sets env vars, a health
check, and notes the free-tier cold-start behavior).
- Mobile: connect the emergencySearch screen to the real endpoint, hold
requestId/status in Provider, connect the Socket.IO client, render the
"was busy, switched to" message from `consideredNearest`.
- Web: connect to the `dispatch` room, live-update markers from
`GET /ambulances`, show new requests landing in the queue.
- Docs/deploy: api-tester runs the collection against the real Render URL
and logs pass/fail; git-workflow-master reviews the first real PRs.

**Day 3 — Sun Sep 13 — integration day**

- All three, together: run the full slice end to end. Phone requests an
ambulance, backend finds the nearest one BUSY, switches, assigns, both
screens update. Fix whatever breaks. This is the day that decides whether
Tuesday goes well.
- Docs/deploy: evidence-collector takes the first real screenshots of the
flow and writes down the actual issues found — no "zero issues" on a
first integration pass, that's not how this goes.

**Day 4 — Mon Sep 14 — build and deploy by day, freeze and rehearse by night**

- Backend: finalize the Render deploy; add the completion-side fix that
flips an assigned ambulance back to AVAILABLE once its request reaches
COMPLETED. Without this, tonight's three-in-a-row rehearsal runs out of
AVAILABLE ambulances after the first pass — small fix, and the single
biggest thing standing between "worked once" and "works every time."
- Mobile: wire the remaining screens (emergencyEnRoute, emergencyApproaching,
emergencyArrived, emergencyComplete), build the APK for the demo device
(mobile-release-engineer: confirm the APK on the device is the one that
was actually tested, not a stale install) — get this locked before
rehearsal starts tonight, not partway through it.
- Web: finish the assign view showing considered-vs-assigned, deploy to
GitHub Pages (infrastructure-maintainer).
- Docs/deploy: technical-writer finishes the README quick-start and a
one-page demo script; test-automation-engineer writes one lightweight
smoke check hitting the dispatcher page and API — not a full suite,
there's no time for one and it's not needed yet.
- **Monday evening — freeze and rehearsal**, folded in from the old Day 5
now that the demo moved up a day: no new features past this point, only
fixes flagged by reality-checker. reality-checker runs the full demo
script against the actual deployed Render and GitHub Pages URLs, not
localhost, at least three times in a row — that run-through doubles as
the timed dry run, so there's no separate pass needed for that — and
only signs off if the switch fires correctly every single time. If a run
gets abandoned mid-flow (app killed before emergencyComplete), re-run the
seed script before the next attempt; that's the only thing that resets
ambulance state outside of a normal completion. evidence-collector keeps
the last of those three clean runs as the fallback recording, instead of
running a fourth one just to capture it.

**Day 5 — Tue Sep 15 — demo day, and nothing else**

- No fixes today, not even small ones — Monday night was the last chance
for that. Anything that breaks gets worked around live or covered by
last night's recording.
- Wake the Render service 5-10 minutes before presenting.
- Run the demo from the script. Fall back to the recording only if
something breaks live.



## 5. Definition of demo-ready

- [ ] Real Flutter app requests an ambulance from the scripted location.
- [ ] Backend identifies the nearest ambulance as BUSY and switches to the
  ```
  next-nearest AVAILABLE one, every time.
  ```
- [ ] Phone shows that the switch happened, not just the final assignment —
  ```
  the whole point is to show the logic, not hide it.
  ```
- [ ] Dispatcher page shows the same request arrive live and shows which
  ```
  unit got assigned and why.
  ```
- [ ] Completing a request frees its ambulance back to AVAILABLE, so this
  ```
  whole checklist is still true on rehearsal run two and three, not
  just run one.
  ```
- [ ] Backend is live on Render and has been woken up before presenting.
- [ ] Web dashboard is live on GitHub Pages, not localhost.
- [ ] A screen recording of one clean full run exists as a fallback.
- [ ] reality-checker has signed off after three consecutive successful
  ```
  runs against the live URLs.
  ```



## 6. After the demo — weeks toward the October MVP

About two and a half weeks stand between the demo and MVP week
(Sep 17 -> Oct 1-7). Same owners, same branches. Cadence loosens from daily
to weekly.

**Week 2 (Sep 17 - Sep 23) — breadth: domestic services**

- Backend: extend the schema/API to the domestic services flow (plumber,
electrician, AC technician, mechanic) from the wireframe's "Find a
service provider" path; simpler provider assignment, no switching
requirement here; swap in real Firebase OTP verification, replacing the
tap-through mock from demo week.
- Mobile: services flow screens, provider-mode screens (the "Switch to
provider mode" toggle already sitting in the wireframe's profile
screen), request history.
- Web: the admin screen deferred from the demo — organizations,
ambulances, service providers, categories.
- Docs/deploy: expand the API contract as endpoints land; api-tester keeps
the Thunder Client collection current; git-workflow-master keeps an eye
on PR volume now that three people are shipping in parallel.

**Week 3 (Sep 24 - Sep 30) — depth: hardening**

- Backend: FCM push notifications for status changes, ratings/history
endpoints, tighter auth middleware and error responses.
- Mobile: ratings screen, saved addresses, notification settings, a polish
pass against the full wireframe, not just the emergency slice.
- Web: dispatcher polish for more than one organization if MVP scope needs
it, queue history for admin.
- Docs/deploy: test-automation-engineer grows the smoke check into an
actual small test suite covering what now exists; evidence-collector
walks the whole app against the wireframe and flags gaps honestly;
reality-checker does a second go/no-go pass against full MVP scope.

**Buffer (Oct 1 - Oct 7) — MVP delivery window**

- Freeze scope. Fix only what reality-checker flags. Rehearse the same way
you rehearsed the mini demo on Day 5 above: multiple live runs against
the deployed URLs, a recorded backup ready.



## 7. How the shared docs branch actually works

Three people touching one branch on top of their own daily work only holds
together if updates are small and same-day. Whoever finishes a task writes
that day's change into `docs/API-CONTRACT.md` or `docs/demo-script.md`
themselves, immediately, not from memory a week later. git-workflow-master's
job here isn't picking a fancy branching model — there isn't time for that —
it's making sure the contract file never quietly drifts from what backend
actually shipped.