# Test Design — Owner Management and Shared Schedule (Task 4.1.5)

- **Issue:** [#47](https://github.com/buikhoa130406/se-project-t04/issues/47) · WBS 4.1.5 · PA4
- **Author:** Lý Sĩ Vĩ (`@Lysivi2005`) · **Reviewer:** Nguyễn Minh Trí (`@nmt1206`) — business rules, 24-hour boundaries, shared schedule and notifications
- **Scope:** UC-09 to UC-13; FR-03, FR-17 to FR-22, FR-27 (owner exemption), FR-29, FR-30; BR-10 to BR-13, BR-16; NFR-04, NFR-08, NFR-09; AC-25, AC-28 to AC-34.
- **Test case range:** TC-201 to TC-299. The list and the detailed specifications are in [`../test-cases/owner-management.md`](../test-cases/owner-management.md).
- **Status:** Test design only. No test in this document has been executed; actual results belong to PA5.

## 1. Inputs and Boundaries

### 1.1 Baseline and design inputs

| Input | Used for |
| --- | --- |
| [PA2 SRS](../../../pa/PA2/T04-PA2-SoftwareRequirementsSpecification.docx) — UC-09 to UC-13, FR/NFR/BR tables, AC-24 to AC-35 | Conditions, boundaries and expected results. PA2 is the requirements baseline. |
| [PA3 design](../../../pa/PA3/T04-PA3-SoftwareDesign.docx) and [`traceability.md`](../../design/traceability.md) | Design element IDs used in the traceability columns. |
| [`api-contract.md`](../../design/interfaces/api-contract.md) — API-01, API-OWN, API-NTF | Endpoints, roles (`PLAYER`, `FACILITY_OWNER`), string IDs, error codes, idempotency. |
| [`data-dictionary.md`](../../design/data/data-dictionary.md) — DB-TBL-04 to DB-TBL-08, DB-ATOM-06, DB-BV-04 to DB-BV-10, DB-HIS | Stored constraints (nonblank fields, `amount_per_slot ≥ 0`, opening hours, soft-deleted courts, price history, affected-item snapshot). |
| [`sequence-diagrams.md`](../../design/sequences/sequence-diagrams.md) — SEQ-04, SEQ-04B, SEQ-05 | Preview → confirm → apply flow and the two-step in-person flow. |
| [`state-machines.md`](../../design/states/state-machines.md) — STM-02, STM-03 | Slot and booking states after owner changes. |
| [`ui-design-specification.md`](../../design/ui/ui-design-specification.md) — UI-11 to UI-15 | Screens where the owner and player observe results. |

### 1.2 Boundaries with other PA4 test sets

| Topic | Owner of the test set | Treatment here |
| --- | --- | --- |
| Hold/confirm mechanics for players (5-minute hold, release ≤ 5 s, F5, heartbeat, concurrency NFR-02/NFR-03, 60-minute player cutoff, 3-hour cancellation) | 4.1.2 Booking & Hold (TC-101–199) | Not repeated. In-person cases only check what differs for owners: ownership, the cutoff exemption, the persisted `IN_PERSON` source and non-override of the shared schedule. |
| Registration, login, guest search and public availability display (UC-01 to UC-04) | 4.1.4 Account & Discovery (TC-001–099) | Used only as the observation point for NFR-04 (public data still visible) and NFR-08 (player reload). |
| End-to-end journeys, Chrome/Safari compatibility (NFR-01), usability (NFR-07) | 4.1.6 System & Acceptance (TC-301–399) | Not repeated. The owner journey “owner changes schedule → player sees update” is a candidate end-to-end scenario for 4.1.6. |
| Test environment, fixtures, clock control, severity and entry/exit criteria | 4.1.1 Test Plan | Assumptions in Section 1.3 are to be aligned with the Test Plan when it is published. |

### 1.3 Test data and environment assumptions (to align with 4.1.1)

- **Accounts (synthetic):** `owner-A` (`FACILITY_OWNER`, owns facility `F1`), `owner-B` (`FACILITY_OWNER`, owns facility `F2`), `player-P1`, `player-P2` (`PLAYER`), and an unauthenticated guest session.
- **Facility `F1`:** courts `C1` and `C2` (both `ACTIVE`), opening hours 06:00–22:00 every weekday, price VND 100,000 per 30-minute slot effective before the test window.
- **Clock:** server time is controllable in the test environment so that boundaries such as exactly 24 hours can be reproduced. Times are written in Asia/Ho_Chi_Minh; API timestamps are UTC (API-01).
- **Reset:** each case starts from the fixture above unless its preconditions add holds, bookings or blocks. No real personal data or secrets are used.
- **Observation:** owner results are observed through API responses and UI-13/UI-14/UI-15; player results through `GET /facilities/:facilityId/schedule` (UI-06) and `GET /notifications` (UI-11). Database inspection is used only where an NFR names it.

## 2. Requirement Map (UC → FR/BR/AC → Test Conditions)

| UC | Requirements | Acceptance criteria | Test conditions (TCOND) |
| --- | --- | --- | --- |
| UC-09 Create and update a facility | FR-03, FR-17, BR-10, NFR-04 | AC-34 | TCOND-01 create facility with valid data; TCOND-02 reject invalid/blank data; TCOND-03 one owner manages several separate facilities (A1); TCOND-04 reject updates by non-creator (E1); TCOND-05 add court / rename court |
| UC-10 Update prices | FR-03, FR-19, BR-10, NFR-04, NFR-08 | AC-34 | TCOND-06 valid price saved and displayed; TCOND-07 invalid price rejected (E1); TCOND-08 cancel before submission (A1); TCOND-09 new price shown on next load; TCOND-10 existing hold/booking totals keep historical price |
| UC-11 Mark time slots as unavailable | FR-03, FR-20, FR-22, FR-29, FR-30, BR-11, BR-12, BR-13, BR-16, NFR-08, NFR-09 | AC-28, AC-29, AC-30, AC-31, AC-32 | TCOND-11 block start ≥ 24 h; TCOND-12 affected hold → wait and retry; TCOND-13 affected booking < 24 h → reject all; TCOND-14 preview lists affected bookings and portions; TCOND-15 owner declines → unchanged; TCOND-16 confirm → cancel whole bookings, update schedule, notify; TCOND-17 affected set changed after preview → reconfirm |
| UC-12 Change operating hours or delete a court | FR-03, FR-17, FR-18, FR-22, FR-29, FR-30, BR-11, BR-16, NFR-08, NFR-09 | AC-29, AC-30, AC-34 | TCOND-18 hours change / court deletion with no affected bookings (A1); TCOND-19 same rules as TCOND-12 to TCOND-17; TCOND-20 invalid opening hours rejected; TCOND-21 deleted court no longer bookable, history kept |
| UC-13 Enter an in-person booking | FR-03, FR-10, FR-11, FR-12, FR-21, FR-22, FR-27, BR-03, BR-08, BR-10, BR-13, NFR-04, NFR-08 | AC-25, AC-33 | TCOND-22 two-step hold then confirm; TCOND-23 exempt from 60-minute cutoff (30 min ahead allowed); TCOND-24 no override of held, booked or blocked slots; TCOND-25 only on own facility; TCOND-26 multi-court consecutive selection (A1); TCOND-27 confirm after expiry rejected; TCOND-28 `IN_PERSON` context kept across reload/retry |
| Cross-cutting | NFR-04 | — | TCOND-29 guest/player/other owner rejected from owner functions; TCOND-30 public facility info still accessible |
| Cross-cutting | NFR-08 | — | TCOND-31 in-person booking, block, price and hours changes visible on next player load |
| Cross-cutting | NFR-09, BR-16, FR-30 | AC-32 | TCOND-32 cancellation notice only in-app with reason, booking and affected courts/slots; no email/phone function |

## 3. Equivalence Partitioning and Boundary Value Analysis

Only limits stated in PA2 or in the PA3 data/API design are tested. Where the baseline sets no limit (for example maximum text length or maximum price), no boundary is invented; such items are listed in Section 7.

### 3.1 Facility and court information (UC-09, FR-17)

| Field | Valid partitions | Invalid partitions | Source | TC |
| --- | --- | --- | --- | --- |
| Facility `name`, `address`, `district` | Nonblank text | Empty string; whitespace only; missing field | DB-TBL-04 (nonblank), UC-09 E1 | TC-201, TC-202, TC-203 |
| Facility `description` | Absent; any text | — | DB-TBL-04 (optional) | TC-201 |
| `sportId`, `amenityIds` | Existing IDs | Unknown ID | DB-TBL-04/05 foreign keys | TC-204 |
| Court `name` | Nonblank and unique within the facility | Blank; duplicate within the same facility | DB-TBL-07 UQ (facility_id, name) | TC-206, TC-207 |
| Facility being edited | Owned by caller | Owned by another owner | FR-03, BR-10, NFR-04 | TC-205, TC-240 |
| Number of facilities per owner | One; several separate facilities | — | UC-09 A1, BR-10 | TC-208 |

### 3.2 Prices (UC-10, FR-19)

| Field | Valid partitions | Invalid partitions | Boundary values | Source | TC |
| --- | --- | --- | --- | --- | --- |
| `amountPerSlot` (VND per 30 min) | ≥ 0 | < 0; non-numeric; missing | **0** (valid), **−1** (invalid), 100,000 (nominal) | API-OWN, DB-TBL-08 | TC-210, TC-211, TC-212 |
| `effectiveFrom` | Valid ISO 8601 timestamp | Missing; malformed | — | API-OWN | TC-213 |
| Price shown for a slot | Latest `effective_from ≤ slot.startTime` | — | Slot starting exactly at `effectiveFrom` uses the new price; slot 30 min earlier uses the old price | API-FAC, DB-TBL-08 | TC-214 |
| Existing hold/booking total | Unchanged after price update | — | — | DB-HIS, NE-4 | TC-215 |
| Edit abandoned | Owner cancels before submitting | — | — | UC-10 A1 | TC-209 |

### 3.3 Operating hours (UC-12, FR-18)

| Field | Valid partitions | Invalid partitions | Source | TC |
| --- | --- | --- | --- | --- |
| `day_of_week` | 1 (Mon) to 7 (Sun) | 0; 8 | DB-TBL-06 | TC-217 |
| `open_time` / `close_time` | `close_time > open_time`, same day | `close_time = open_time`; `close_time < open_time` (overnight) | DB-TBL-06, data design assumption “no overnight operation” | TC-216 |
| Missing weekday | Means closed | — | DB-TBL-06 | TC-218 |
| Court deletion | Existing `ACTIVE` court of own facility | Court of another facility; already `DELETED` court | DB-TBL-07 (soft delete), UC-12 | TC-219, TC-234 |

### 3.4 24-hour boundaries (FR-20, FR-29, BR-11, BR-12)

Times assume `serverNow = 10:00` on day D. One-minute steps follow the style of PA2 AC-24/AC-26.

| Rule | Below boundary (invalid) | On boundary (valid) | Above boundary (valid) | TC |
| --- | --- | --- | --- | --- |
| Block start − serverNow ≥ 24 h (BR-12, DB-BV-06) | Block starts D+1 09:59 (23 h 59 min) → reject | Block starts D+1 10:00 (exactly 24 h) → allowed | Block starts D+2 10:00 (48 h) → allowed | TC-221, TC-220, TC-222 |
| Affected booking earliest start − serverNow ≥ 24 h (BR-11, DB-BV-07) | Earliest start D+1 09:59 → reject whole change | Earliest start D+1 10:00 → allowed | D+2 10:00 → allowed | TC-226, TC-225, TC-227 |
| Earliest start measured across **all courts** of the booking (FR-29, DB-ATOM-06) | Affected court C1 starts at D+2 10:00 but the same booking has C2 at D+1 09:30 → reject | — | — | TC-228 |
| Re-check at apply (DB-BV-06/07) | Preview at exactly 24 h, apply one minute later (23 h 59 min) → reject at apply | — | — | TC-229 |

### 3.5 In-person booking time limits (FR-21, FR-27, BR-08, AC-25)

Times assume `serverNow = 17:30`.

| Condition | Partition | Boundary values | Expected | TC |
| --- | --- | --- | --- | --- |
| Lead time for `IN_PERSON` | Future slot, any lead time | Slot starts 18:00 (30 min, AC-25) → accepted; slot starts 18:30 (60 min) → accepted | Owner exempt from the 60-minute player cutoff | TC-250, TC-251 |
| Past time | Slot already started | Slot started 17:00 → rejected | “Cannot select past time” (DB-BV-04) | TC-252 |
| Same selection by a player | Player, 30 min ahead | Slot 18:00 → rejected with `SELECTION_INVALID` | Confirms the exemption applies only to the authorised owner flow | TC-253 |

## 4. Decision Tables

### 4.1 DT-01 — Owner schedule change (block, operating-hour change, court deletion)

Applies equally to `BLOCK`, `OPERATING_HOURS` and `DELETE_COURT` (BR-11, SEQ-04, SEQ-04B, DB-ATOM-06). “—” means the condition is not evaluated for that rule.

| Condition / Action | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C1 Caller is `FACILITY_OWNER` of this facility | N | Y | Y | Y | Y | Y | Y | Y |
| C2 Change input valid (block ≥ 24 h ahead; valid hours; existing active court) | — | N | Y | Y | Y | Y | Y | Y |
| C3 An affected hold is active | — | — | Y | N | N | N | N | N |
| C4 Affected confirmed bookings exist | — | — | — | N | Y | Y | Y | Y |
| C5 Every affected booking's earliest start ≥ 24 h | — | — | — | — | N | Y | Y | Y |
| C6 Owner confirms after preview/warning | — | — | — | Y | — | N | Y | Y |
| C7 Affected-booking set at apply equals `expectedBookingIds` | — | — | — | Y | — | — | N | Y |
| **A1** Reject access (`403 NOT_FACILITY_OWNER`), no change | X | | | | | | | |
| **A2** Reject input, no change | | X | | | | | | |
| **A3** Reject; owner waits for hold to end/confirm and retries; no change | | | X | | | | | |
| **A4** Apply change; no booking cancelled; no notification | | | | X | | | | |
| **A5** Reject entire change; no booking cancelled | | | | | X | | | |
| **A6** Nothing changed (preview only) | | | | | | X | | |
| **A7** `409 AFFECTED_BOOKINGS_CHANGED`; show new list; nothing changed; owner must reconfirm | | | | | | | X | |
| **A8** Apply change; cancel each affected booking in full (`CANCELLED_BY_OWNER`); update schedule; create in-app notices | | | | | | | | X |
| **Test cases** | TC-240, TC-241 | TC-221, TC-217, TC-234 | TC-223, TC-224 | TC-230, TC-231 | TC-226, TC-228 | TC-232 | TC-233 | TC-225, TC-235, TC-236 |

Notes:

- R3 is evaluated both at preview and again at apply (AC-30); TC-224 covers a hold that appears between preview and apply.
- R7 covers both an added and a removed booking (API-OWN “Reconfirmation”); TC-233 adds one, TC-237 removes one.
- R8 expected results include the notice content required by FR-30: reason (`BLOCKED_PERIOD`, `HOURS_CHANGED` or `COURT_DELETED`), the booking, and only the courts/slots that caused the cancellation (`affected_items` snapshot, NE-5), even when the booking has other unaffected courts.

### 4.2 DT-02 — In-person booking (UC-13)

| Condition / Action | R1 | R2 | R3 | R4 | R5 | R6 | R7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C1 Caller is `FACILITY_OWNER` of the selected facility | N | Y | Y | Y | Y | Y | Y |
| C2 Selection valid (one facility, active courts, consecutive 30-min slots per court, within opening hours, not in the past) | — | N | Y | Y | Y | Y | Y |
| C3 All selected slots free (no active hold, booking or block) | — | — | N | Y | Y | Y | Y |
| C4 Lead time < 60 min | — | — | — | Y | N | — | — |
| C5 Owner confirms strictly before `expiresAt` | — | — | — | Y | Y | N | Y |
| C6 Hold confirmed through the direct-hold confirm step of the same facility (`source = IN_PERSON`) | — | — | — | Y | Y | — | Y |
| **A1** `403 NOT_FACILITY_OWNER`; no hold | X | | | | | | |
| **A2** `422 SELECTION_INVALID`; no hold | | X | | | | | |
| **A3** `409 SLOT_CONFLICT`; nothing held; existing entry untouched | | | X | | | | |
| **A4** Hold created (`IN_PERSON`, `isDirect = true`), then booking `CONFIRMED`, slots unavailable in shared schedule | | | | X | X | | X |
| **A5** `409 HOLD_EXPIRED`; no booking written | | | | | | X | |
| **Test cases** | TC-254 | TC-252, TC-255, TC-256 | TC-257, TC-258, TC-259 | TC-250 | TC-251, TC-260 | TC-261 | TC-262 |

R7 covers the persisted context: after reloading UI-15 between the two steps, the restored hold still reports `isDirect = true` and confirmation succeeds even with < 60 minutes lead time (API-HOLD, DB-TBL-09).

## 5. In-Person Booking Test Design (UC-13)

The flow is two separate requests (SEQ-05, API-OWN):

1. `POST /owner/facilities/:facilityId/direct-holds` — server checks facility ownership, then creates a hold with `source = IN_PERSON`.
2. `POST /owner/facilities/:facilityId/direct-holds/:holdId/confirm` — server re-checks ownership and the persisted source, then confirms.

Design points:

- **Exemption scope.** Only the authorised direct-hold flow is exempt from the 60-minute cutoff (TC-250, TC-251). The same selection through the player endpoint is rejected (TC-253). An owner using the ordinary player flow at another owner's facility gets no exemption (TC-263).
- **No override.** A slot that is held by a player (TC-257), already booked (TC-258) or blocked (TC-259) is never overwritten; nothing in the selection is held (all-or-nothing, BR-05 applied via FR-21 “player flow”).
- **Shared schedule.** After confirmation the slots show as booked for players on the next load (TC-264, NFR-08) and are rejected for a competing player hold (TC-265).
- **Expiry.** In-person holds follow the same five-minute expiry as players; confirming after expiry returns `409 HOLD_EXPIRED` (TC-261). Detailed expiry timing is covered by 4.1.2.
- **Idempotency.** Retrying the confirm step with the same `Idempotency-Key` returns the original result and does not create a second booking (TC-266, API-01).

## 6. Non-Functional Verification

| NFR | Design | Expected result | TC |
| --- | --- | --- | --- |
| **NFR-04** Authorization | For each owner function (create/update facility, add/rename court, update price, preview/apply schedule change, both direct-hold steps), send the request as: guest (no token), `player-P1`, and `owner-B` against `F1`. Then call public endpoints `GET /facilities`, `GET /facilities/:id`, `GET /facilities/:id/schedule` as guest. | Guest → `401 UNAUTHORIZED`; player and other owner → rejected (`403`), no data changed; public endpoints still return `200`. Testing uses only the team's test environment; no attack techniques are designed. | TC-240 to TC-246 |
| **NFR-08** Data freshness | Owner performs each change type (in-person booking, block, price change, operating-hour change); a player then reloads the availability screen for the affected date. | Change appears on the next load or refresh. Automatic push updates are not required (FR-32 note). | TC-264, TC-270, TC-271, TC-272 |
| **NFR-09** In-app notifications only | (a) Inspect the system's functions/configuration for any email or SMS sending capability. (b) After an owner cancellation, the affected player opens the application. | (a) No email or phone notification function exists. (b) Notice appears in UI-11 with reason, booking and affected courts/slots; nothing is sent outside the application. | TC-236, TC-275, TC-276 |

## 7. Open Points for Reviewer and Related Owners

| # | Point | Proposed handling |
| --- | --- | --- |
| OP-1 | API-OWN states that apply rejects while affected holds remain and when an affected booking is under 24 hours, but does not name the error codes for these two rejections. | Expected results check “rejected, no data changed”. Exact codes to be confirmed with API owner before PA5 automation. |
| OP-2 | The HTTP code for a `PLAYER` calling an `/owner` endpoint is not stated separately from `403 NOT_FACILITY_OWNER`. | Expected result: request rejected with `403`; exact error code to confirm. |
| OP-3 | Whether an in-person slot starting exactly at `serverNow` counts as “past time” (DB-BV-04). | Not tested as a boundary until clarified; TC-252 uses a clearly past slot. |
| OP-4 | Whether `effectiveFrom` may be in the past, and whether opening hours must align to 00/30 minutes. | No boundary invented; cases use future, aligned values. |
| OP-5 | Fixtures, clock control and reset are assumed (Section 1.3). | Align with the Test Plan (4.1.1) when published. |
