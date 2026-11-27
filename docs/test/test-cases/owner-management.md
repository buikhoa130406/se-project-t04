# Test Cases — Owner Management and Shared Schedule (Task 4.1.5)

- **Issue:** [#47](https://github.com/buikhoa130406/se-project-t04/issues/47) · Range TC-201 to TC-299
- **Design:** [`../test-design/owner-management.md`](../test-design/owner-management.md) (conditions, EP/BVA, decision tables DT-01 and DT-02, test data in Section 1.3)
- **Status:** Designed only. Actual results are recorded in PA5.
- **Columns:** *Technique* — UC = use-case based, EP = equivalence partitioning, BVA = boundary value analysis, DT = decision table (rule). *Automated?* is the planned approach for PA5: API = API-level automated test, E2E = browser end-to-end, Manual = inspection/demonstration.

## 1. Test Case List

### 1.1 Facilities and courts (UC-09)

| ID | Title | Req. / UC | Technique | Priority | Automated? |
| --- | --- | --- | --- | --- | --- |
| TC-201 | Create facility with valid required fields | UC-09, FR-17, AC-34 | UC, EP | High | API |
| TC-202 | Create facility with blank name | UC-09 E1, FR-17 | EP | High | API |
| TC-203 | Create facility with missing address or district | UC-09 E1, FR-17 | EP | Medium | API |
| TC-204 | Create facility with unknown sport or amenity | UC-09 E1, FR-17 | EP | Medium | API |
| TC-205 | Update own facility information with valid data | UC-09, FR-17, AC-34 | UC | High | API |
| TC-206 | Add court with unique name to own facility | UC-09, FR-17 | UC, EP | High | API |
| TC-207 | Add court with duplicate name in same facility | UC-09 E1, FR-17 | EP | Medium | API |
| TC-208 | Create second facility for same owner as separate branch | UC-09 A1, FR-03, BR-10 | UC | Medium | API |

### 1.2 Prices and operating hours (UC-10, UC-12 data)

| ID | Title | Req. / UC | Technique | Priority | Automated? |
| --- | --- | --- | --- | --- | --- |
| TC-209 | Cancel price edit before submission | UC-10 A1 | UC | Low | E2E |
| TC-210 | Update court price with zero amount | UC-10, FR-19 | BVA | Medium | API |
| TC-211 | Update court price with negative amount | UC-10 E1, FR-19 | BVA | High | API |
| TC-212 | Update court price with non-numeric or missing amount | UC-10 E1, FR-19 | EP | Medium | API |
| TC-213 | Update court price with missing or malformed effective time | UC-10 E1, FR-19 | EP | Medium | API |
| TC-214 | Display slot price at effective-time boundary | UC-10, FR-07, FR-19 | BVA | High | API |
| TC-215 | Keep held and confirmed totals after price change | FR-19, DB-HIS | EP | High | API |
| TC-216 | Change operating hours with closing time not after opening time | UC-12 E, FR-18 | BVA | High | API |
| TC-217 | Change operating hours with invalid weekday | UC-12 E, FR-18 | BVA | Medium | API |
| TC-218 | Remove weekday from operating hours as closed day | UC-12, FR-18 | EP | Medium | API |
| TC-219 | Delete court with no bookings and keep history | UC-12 A1, FR-17, FR-29 | UC | Medium | API |

### 1.3 Blocking and schedule changes (UC-11, UC-12 — DT-01)

| ID | Title | Req. / UC | Technique | Priority | Automated? |
| --- | --- | --- | --- | --- | --- |
| TC-220 | Create block starting exactly 24 hours ahead | UC-11, FR-20, BR-12 | BVA, DT R4 | High | API |
| TC-221 | Create block starting 23 hours 59 minutes ahead | UC-11 E2, FR-20, BR-12, AC-31 | BVA, DT R2 | High | API |
| TC-222 | Create block starting 48 hours ahead | UC-11, FR-20 | BVA | Low | API |
| TC-223 | Preview block with active affected hold | UC-11 E1, FR-29, AC-30 | DT R3 | High | API |
| TC-224 | Apply block when hold appears after preview | UC-11 E1, FR-29, AC-30 | DT R3 | High | API |
| TC-225 | Apply block with affected booking exactly 24 hours ahead | UC-11, FR-29, FR-30, AC-28, AC-32 | BVA, DT R8 | High | API |
| TC-226 | Apply block with affected booking 23 hours 59 minutes ahead | UC-11 E2, FR-29, BR-11, AC-29 | BVA, DT R5 | High | API |
| TC-227 | Apply block with affected booking 48 hours ahead | UC-11, FR-29 | BVA, DT R8 | Low | API |
| TC-228 | Apply change with multi-court booking starting under 24 hours on unaffected court | FR-29, BR-11, AC-29 | BVA, DT R5 | High | API |
| TC-229 | Apply block after 24-hour boundary passes since preview | FR-20, FR-29, BR-12 | BVA | High | API |
| TC-230 | Apply block with no affected bookings | UC-11, FR-20, FR-22 | DT R4 | Medium | API |
| TC-231 | Apply operating-hour change with no affected bookings | UC-12 A1, FR-18 | DT R4 | Medium | API |
| TC-232 | Decline schedule change after preview warning | UC-11 A1, UC-12 A2 | DT R6 | Medium | E2E |
| TC-233 | Apply change when booking added after preview | UC-11, UC-12, FR-29 | DT R7 | High | API |
| TC-234 | Delete court of another facility or already deleted court | UC-12 E, FR-17 | EP, DT R2 | Medium | API |
| TC-235 | Apply operating-hour change cancelling affected booking | UC-12, FR-18, FR-29, FR-30 | DT R8 | High | API |
| TC-236 | Apply court deletion cancelling multi-court booking with partial notice | UC-12, FR-29, FR-30, NFR-09 | DT R8 | High | API |
| TC-237 | Apply change when booking removed after preview | UC-11, UC-12, FR-29 | DT R7 | Medium | API |

### 1.4 Authorization (NFR-04)

| ID | Title | Req. / UC | Technique | Priority | Automated? |
| --- | --- | --- | --- | --- | --- |
| TC-240 | Update facility information as another owner | NFR-04, FR-03, BR-10, UC-09 E1 | EP, DT R1 | High | API |
| TC-241 | Apply schedule change as another owner | NFR-04, FR-03, UC-11 | DT R1 | High | API |
| TC-242 | Call owner management functions as guest | NFR-04 | EP | High | API |
| TC-243 | Call owner management functions as player | NFR-04 | EP | High | API |
| TC-244 | Update price of another owner's court | NFR-04, UC-10 | EP | High | API |
| TC-245 | Confirm in-person hold of another owner's facility | NFR-04, UC-13, DB-BV-10 | EP | High | API |
| TC-246 | View public facility information as guest | NFR-04, FR-04, FR-06 | EP | Medium | API |

### 1.5 In-person booking (UC-13 — DT-02)

| ID | Title | Req. / UC | Technique | Priority | Automated? |
| --- | --- | --- | --- | --- | --- |
| TC-250 | Create in-person booking 30 minutes ahead in two steps | UC-13, FR-21, FR-27, AC-25 | BVA, DT R4 | High | API |
| TC-251 | Create in-person booking 60 minutes ahead | UC-13, FR-21 | BVA, DT R5 | Medium | API |
| TC-252 | Create in-person hold for slot already started | UC-13, DB-BV-04 | BVA, DT R2 | High | API |
| TC-253 | Create player hold 30 minutes ahead without exemption | FR-27, BR-08 | BVA | High | API |
| TC-254 | Create in-person hold at another owner's facility | UC-13, FR-21, NFR-04 | DT R1 | High | API |
| TC-255 | Create in-person hold with non-consecutive slots on one court | UC-13, BR-03 | EP, DT R2 | Medium | API |
| TC-256 | Create in-person hold outside opening hours or on deleted court | UC-13, FR-22 | EP, DT R2 | Medium | API |
| TC-257 | Create in-person hold over slot held by player | UC-13 E1, FR-21, BR-13, AC-33 | DT R3 | High | API |
| TC-258 | Create in-person hold over booked slot | UC-13 E1, FR-21, BR-13, AC-33 | DT R3 | High | API |
| TC-259 | Create in-person hold over blocked slot | UC-13 E1, FR-22, BR-13 | DT R3 | High | API |
| TC-260 | Create in-person booking with consecutive slots on two courts | UC-13 A1, BR-03 | UC, DT R5 | Medium | API |
| TC-261 | Confirm in-person hold after expiry | UC-13, FR-11 | DT R6 | High | API |
| TC-262 | Confirm in-person hold after reload keeping direct context | UC-13, FR-21, API-HOLD | DT R7 | Medium | E2E |
| TC-263 | Book another owner's facility through player flow without exemption | FR-21, FR-27, BR-08 | EP | Medium | API |
| TC-264 | Show in-person booking to player after reload | NFR-08, FR-22, AC-33 | UC | High | E2E |
| TC-265 | Reject player hold on slot booked in person | FR-22, BR-13 | UC | High | API |
| TC-266 | Retry in-person confirmation with same idempotency key | UC-13, API-01 | EP | Medium | API |

### 1.6 Data freshness and notifications (NFR-08, NFR-09)

| ID | Title | Req. / UC | Technique | Priority | Automated? |
| --- | --- | --- | --- | --- | --- |
| TC-270 | Show new block to player after reload | NFR-08, FR-22, UC-11 | UC | High | E2E |
| TC-271 | Show new price to player after reload | NFR-08, FR-19, UC-10 | UC | High | E2E |
| TC-272 | Show operating-hour change to player after reload | NFR-08, FR-18, UC-12 | UC | Medium | E2E |
| TC-275 | Show owner-cancellation notice in application | NFR-09, FR-30, BR-16, AC-32 | UC | High | E2E |
| TC-276 | Verify absence of email and phone notification function | NFR-09, BR-16 | Inspection | Medium | Manual |

**Coverage summary:** 66 test cases. Every rule of DT-01 (R1–R8) and DT-02 (R1–R7) has at least one test case (see the mapping row under each table in the design document). Seven cases are specified in detail below.

## 2. Detailed Test Case Specifications

Common fixture: Section 1.3 of the design document (`owner-A` owns `F1` with courts `C1`, `C2`; `owner-B` owns `F2`; players `P1`, `P2`; F1 open 06:00–22:00; price VND 100,000 per slot). Times are Asia/Ho_Chi_Minh. “No data changed” means: no row added, updated or deactivated in `schedule_entry`, `booking`, `notification`, `court` or `operating_hours`.

### TC-220 — Create block starting exactly 24 hours ahead

| Field | Content |
| --- | --- |
| Requirement / UC | FR-20, BR-12, UC-11; DB-BV-06; DT-01 R4 |
| Technique | BVA (on-boundary value) |
| Priority | High |
| Preconditions | `owner-A` is logged in. Server time is fixed at D 10:00. Court `C1` has no hold, booking or block on D+1. |
| Test data | `change = { type: BLOCK, courtId: "<C1>", startTime: D+1 10:00, endTime: D+1 11:00, reason: "Maintenance" }` |
| Test steps | 1. `POST /owner/facilities/<F1>/schedule-changes/preview` with the change. 2. Check the response. 3. `POST /owner/facilities/<F1>/schedule-changes/apply` with `{ change, expectedBookingIds: [] }` and a new `Idempotency-Key`. 4. Read `GET /facilities/<F1>/schedule?date=D+1`. |
| Expected result | Step 2: `200`, `affectedBookings` is empty, `expectedBookingIds` is `[]`. Step 3: change applied (2xx). Step 4: slots 10:00 and 10:30 on `C1` show `BLOCKED`; other slots unchanged. No notification is created. |
| Postconditions | One active `BLOCK` range on `C1` D+1 10:00–11:00. Reset fixture before the next case. |

### TC-228 — Apply change with multi-court booking starting under 24 hours on unaffected court

| Field | Content |
| --- | --- |
| Requirement / UC | FR-29, BR-11, AC-29, UC-11 E2; DB-BV-07, DB-ATOM-06; DT-01 R5 |
| Technique | BVA, decision table |
| Priority | High |
| Preconditions | Server time D 10:00. `P1` holds one confirmed booking `B1` in `F1` with two parts: `C2` D+1 09:30–10:00 and `C1` D+2 10:00–11:00. No active holds in `F1`. |
| Test data | `change = { type: BLOCK, courtId: "<C1>", startTime: D+2 10:00, endTime: D+2 11:00 }` (touches only the `C1` part of `B1`). |
| Test steps | 1. Preview the change. 2. Apply with `expectedBookingIds` taken from step 1. 3. Read `B1` and the D+1/D+2 schedules. |
| Expected result | The block itself is ≥ 24 h ahead, but `B1`'s earliest start across all courts (D+1 09:30) is 23 h 30 min away. The entire change is rejected (preview reports the violation or apply rejects it); no booking is cancelled, `B1` stays `CONFIRMED`, `C1` D+2 10:00 is not blocked, no notification is created. |
| Postconditions | No data changed. |

### TC-225 — Apply block with affected booking exactly 24 hours ahead

| Field | Content |
| --- | --- |
| Requirement / UC | FR-29, FR-30, BR-11, BR-16, AC-28, AC-32, UC-11; DT-01 R8 |
| Technique | BVA (on-boundary), decision table |
| Priority | High |
| Preconditions | Server time D 10:00. `P1` has confirmed booking `B2` in `F1`: `C1` D+1 10:00–11:00 and `C2` D+1 12:00–13:00. No active holds in `F1`. |
| Test data | `change = { type: BLOCK, courtId: "<C1>", startTime: D+1 10:00, endTime: D+1 10:30, reason: "Maintenance" }` |
| Test steps | 1. Preview the change. 2. Apply with `expectedBookingIds = ["<B2>"]`. 3. Read `B2`. 4. Read the D+1 schedule as `P2`. 5. As `P1`, `GET /notifications`. |
| Expected result | Step 1: `200`; `affectedBookings` lists `B2` with `earliestStartTime` D+1 10:00 and `affectedSlots` = `C1` 10:00–10:30 only; a warning is shown on UI-14. Step 2: applied (exactly 24 h is allowed). Step 3: `B2` is `CANCELLED_BY_OWNER` as a whole (both courts). Step 4: `C1` 10:00 is `BLOCKED`; `C1` 10:30 and `C2` 12:00–13:00 are released and shown `AVAILABLE`. Step 5: one notice for `B2` with `reason = BLOCKED_PERIOD`, the booking ID, and `affectedItems` = `C1` 10:00–10:30 only; `isRead = false`. |
| Postconditions | `B2` cancelled; one block; one unread notice for `P1`. |

### TC-233 — Apply change when booking added after preview

| Field | Content |
| --- | --- |
| Requirement / UC | FR-29, UC-11 step 5, UC-12 step 5; API-OWN “Reconfirmation”; DB-ATOM-06; DT-01 R7 |
| Technique | Decision table |
| Priority | High |
| Preconditions | Server time D 10:00. `C1` D+2 has one confirmed booking `B3` (`P1`, 10:00–11:00) and free slots 11:00–12:00. |
| Test data | `change = { type: BLOCK, courtId: "<C1>", startTime: D+2 10:00, endTime: D+2 12:00 }` |
| Test steps | 1. `owner-A` previews; record `expectedBookingIds` (= `["<B3>"]`). 2. Before apply, `P2` holds and confirms `C1` D+2 11:00–11:30, creating `B4`. 3. `owner-A` applies with `expectedBookingIds = ["<B3>"]`. 4. `owner-A` applies again with `["<B3>", "<B4>"]` from the response of step 3. |
| Expected result | Step 3: `409 AFFECTED_BOOKINGS_CHANGED` with the same envelope as preview, now listing `B3` and `B4` with their `affectedSlots`; no data changed (`B3`, `B4` still `CONFIRMED`, no block). Step 4: applied; `B3` and `B4` are `CANCELLED_BY_OWNER`; `C1` 10:00–12:00 `BLOCKED`; `P1` and `P2` each receive one notice. |
| Postconditions | Two cancelled bookings, one block, two notices. |

### TC-250 — Create in-person booking 30 minutes ahead in two steps

| Field | Content |
| --- | --- |
| Requirement / UC | UC-13, FR-21, FR-22, FR-27, BR-08, AC-25, AC-33; SEQ-05; DT-02 R4 |
| Technique | BVA, decision table |
| Priority | High |
| Preconditions | `owner-A` is logged in. Server time D 17:30. `C1` D 18:00–18:30 is free. |
| Test data | `selections = [{ courtId: "<C1>", slotStartTimes: [D 18:00] }]` |
| Test steps | 1. `POST /owner/facilities/<F1>/direct-holds` with the selection and an `Idempotency-Key`. 2. Check the response. 3. `POST /owner/facilities/<F1>/direct-holds/<holdId>/confirm` with a new `Idempotency-Key` before `expiresAt`. 4. As `P1`, reload `GET /facilities/<F1>/schedule?date=D`. |
| Expected result | Step 2: `201`; `source = IN_PERSON`, `isDirect = true`, `status = ACTIVE`, `expiresAt = createdAt + 5 min`, price VND 100,000. The 60-minute cutoff is not applied. Step 3: `201`; booking `CONFIRMED`, `source = IN_PERSON`. Step 4: `C1` D 18:00 shows `BOOKED`. |
| Postconditions | One `IN_PERSON` booking in the shared schedule. |

### TC-257 — Create in-person hold over slot held by player

| Field | Content |
| --- | --- |
| Requirement / UC | UC-13 E1, FR-21, BR-13, AC-33; DB-CON-01; DT-02 R3 |
| Technique | Decision table |
| Priority | High |
| Preconditions | Server time D 15:00. `P1` has an active hold on `C1` D 18:00–18:30 (created through the player flow, not expired). `C2` D 18:00 is free. |
| Test data | `selections = [{ courtId: "<C1>", slotStartTimes: [D 18:00] }, { courtId: "<C2>", slotStartTimes: [D 18:00] }]` |
| Test steps | 1. `owner-A` sends `POST /owner/facilities/<F1>/direct-holds`. 2. Read `P1`'s hold. 3. Read the D schedule. |
| Expected result | Step 1: `409 SLOT_CONFLICT` with `conflictedSlots` containing `C1` D 18:00; no hold is created, including for the free `C2` slot (all-or-nothing). Step 2: `P1`'s hold is unchanged (`ACTIVE`, same `expiresAt`). Step 3: `C1` 18:00 `HELD`, `C2` 18:00 `AVAILABLE`. |
| Postconditions | No data changed. |

### TC-240 — Update facility information as another owner

| Field | Content |
| --- | --- |
| Requirement / UC | NFR-04, FR-03, BR-10, UC-09 E1; DB-BV-10; DT-01 R1 |
| Technique | Equivalence partitioning (other-owner partition) |
| Priority | High |
| Preconditions | `owner-B` is logged in (valid `FACILITY_OWNER` token). `F1` belongs to `owner-A`. |
| Test data | `PATCH /owner/facilities/<F1>` body `{ name: "Taken over" }` |
| Test steps | 1. Send the request as `owner-B`. 2. As guest, `GET /facilities/<F1>`. |
| Expected result | Step 1: `403 NOT_FACILITY_OWNER`; no data changed. Step 2: `200`; `F1` still shows its original name, confirming public information remains accessible and unchanged. |
| Postconditions | No data changed. |

## 3. Self-Check

- [x] Covers UC-09 to UC-13, authorization, shared schedule, 24-hour boundaries (on/below/above and across courts), affected holds and bookings, in-person flow and notifications.
- [x] Every feasible rule in DT-01 and DT-02 maps to at least one test case.
- [x] NFR-04, NFR-08 and NFR-09 have explicit expected results.
- [x] No actual results or claims of execution; open points are listed in Section 7 of the design document.
- [x] IDs stay within TC-201 to TC-299 and do not overlap Booking (TC-101–199), Account/Discovery (TC-001–099) or System/Acceptance (TC-301–399).
