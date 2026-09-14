# Madad+ Final Tech Stack

| Layer | Technology | What it's used for | Why this one |
|---|---|---|---|
| Mobile app | Flutter | Builds the one customer app that runs on Android phones | Covers Android without learning two native languages; gives up native Android's smaller app size and simpler debugging |
| Mobile app | Provider (a way to share live data across screens) | Shares live request status across screens without passing data by hand | Simpler for beginners than Riverpod; gives up Riverpod's stricter type-checking and easier tests |
| Backend | Node.js with Express | Runs the server all apps send requests to | Reuses the team's JavaScript everywhere; gives up Fastify's faster built-in speed and validation |
| Backend | Knex (writes SQL for you, but lets you write raw SQL too) | Lets the server save and read data safely | Handles PostGIS's location queries directly; gives up Prisma's automatic type-checking and generated types |
| Database | Supabase (hosted PostgreSQL with PostGIS, an add-on that finds nearby locations) | Stores every user, request, and ambulance location online | Finds the closest ambulance right inside the database; gives up working without an internet connection |
| Real-time updates | Socket.IO (keeps a live connection open between phone and server) | Pushes live status changes straight to the app | Updates arrive instantly; gives up the simplicity of the app just checking again periodically |
| Maps | Google Maps Platform | Shows maps, measures distance, and reads addresses | Most accurate data for Karachi streets; gives up avoiding a credit card, since one is required |
| Auth | Firebase Authentication | Confirms a user's identity with an OTP (one-time code) sent by text | Matches how people in Pakistan already expect to sign in; gives up owning that sign-in code themselves |
| Auth | JWT (a signed pass proving someone's already logged in) | Lets the server recognize a signed-in user on later requests | Skips asking Firebase again each time; gives up Firebase's built-in per-request checks |
| Web dashboard | Plain HTML, CSS, and JavaScript | Builds the dispatcher and admin screens shown in a browser | Reuses the wireframe prototype directly; gives up React's reusable building blocks and larger community |
| Hosting | Render | Runs the backend server so it can be reached online | Free tier needs no card; gives up staying instantly awake between requests |
| Hosting | GitHub Pages | Hosts the dispatcher and admin web pages | Needs no new account since the team already uses GitHub; gives up any server-side logic on those pages |
| Dev tooling | Git and GitHub | Tracks every code change and who made it | Already set up and free; gives up GitLab's built-in automated testing tools |
| Dev tooling | Thunder Client | Tests backend requests before the apps can call them | Lives inside the editor with no signup; gives up Postman's shared team collections |

## Not needed yet

- Docker: worth adding if the team later hosts its own database instead of using Supabase.
- Firebase Cloud Messaging: worth adding once real push notifications matter more than in-app updates.
- Firebase Storage: worth adding once photo uploads for service requests become a priority.
- Xcode: worth adding only if the team gets access to a Mac and wants an iPhone version.
