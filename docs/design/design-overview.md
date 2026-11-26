# Design Overview

## Design Goals and Constraints

| ID | Goal | Design driver | PA2 references |
| --- | --- | --- | --- |
| ASR-G1 | Consistent reservations | At most one confirmed booking per court and slot. Only one request can win a contested slot. Revalidate the hold and its slots at confirmation. | FR-11, FR-13, NFR-02 |
| ASR-G2 | Hold lifetime | A hold lasts up to five minutes without extension. Reload preserves the remaining time. Reject confirmation at expiry and release within five seconds. Early release on abandonment is best effort. | FR-14, FR-25, FR-26, FR-31, NFR-03 |
| ASR-G3 | All-or-nothing selection | A selection spans one facility and consecutive 30-minute slots per court. Proceed to booking revalidates every slot. Players must book at least 60 minutes in advance. Owner bookings at the counter are exempt. | FR-09, FR-10, FR-13, FR-21, FR-27, FR-32 |
| ASR-G4 | Role and resource ownership | Guests may browse and select. Proceed to booking requires sign-in and reselection from home. Players access their own bookings, and owners manage only their own facilities. | FR-01–03, FR-23, FR-24, NFR-04 |
| ASR-G5 | Shared schedule | Web bookings, in-person bookings and blocked periods affect a single availability view. Schedule changes appear on the next load or refresh. | FR-21, FR-22, NFR-08 |
| ASR-G6 | Cancellation and schedule changes | A player may cancel the full booking at least three hours before its earliest slot. For owner changes, wait for affected holds to end or be confirmed, then retry and revalidate. Affected bookings must start at least 24 hours later, measured from the earliest slot of each booking. Exactly 24 hours is permitted. Preview impacts and notify players after owner-confirmed cancellation. | FR-18, FR-20, FR-28–30, BR-09, BR-11, BR-12 |
| ASR-G7 | Response time and booking usability | Target search and availability latency is P95 at or below two seconds with 50 concurrent users in the demo environment. A first-time player who is already signed in should complete the booking in three minutes. | FR-04–08, NFR-06, NFR-07 |
| ASR-G8 | Browser compatibility | A responsive browser application supports Chrome and Safari on desktop and mobile. | NFR-01 |
| ASR-G9 | Credentials and notifications | Store password hashes. Deliver cancellation notifications and booking status in the application. | NFR-05, NFR-09, BR-16 |

Design constraints

| ID | Constraint | Design implication |
| --- | --- | --- |
| CON-01 | Technology | React, Node.js with Express, PostgreSQL, Jest and GitHub Actions. |
| CON-02 | Environment | Responsive web application and a Linux cloud environment for integration testing and the demo. |
| CON-03 | Course scope | Waterfall delivery. The five PA2 Must features are carried through to PA5. |
| CON-04 | Team capacity | The PA2 planning baseline assumes four members at about 14 hours per member per week. |
| CON-05 | Product scope | Payments and deposits, native applications, external integrations, reviews/ratings, chat, and email/SMS notifications are outside this PA3 design scope. |
