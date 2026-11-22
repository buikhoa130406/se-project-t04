## Interface Design

### Common interface rules (API-01)

Protocol. The frontend–backend interface uses HTTPS and REST JSON under /api/v1.

Identifiers. All IDs, including expectedBookingIds, are decimal strings on JSON and URL paths; the server parses them as PostgreSQL bigint values.

Access control. JWT bearer authentication, role checks and resource ownership checks run on the server. Roles are PLAYER and FACILITY_OWNER.

Time zone. Timestamps are ISO 8601 UTC values; opening-hour dates and times are interpreted in Asia/Ho_Chi_Minh.

Expiry and reload. The server fixes expiresAt = createdAt + five minutes. Hold responses supply expiresAt and serverNow; the client offsets its countdown from server time and never resets or extends expiry on reload. beforeunload and pagehide do not release the hold because they also occur during reload. UI-07 reports presence by authenticated heartbeat; a missing heartbeat permits best-effort early release as specified in API-HOLD.

Scope. Idempotency-Key (UUID v4) applies to hold creation, hold confirmation, both direct-hold steps and schedule-change apply.

Stored record. PostgreSQL api_request_result is an operational table separate from the twelve business-data tables in Section 5. Its composite primary key is (user_id, method, path, request_key); it stores request_hash, status, http_status, response_body, created_at and retain_until. request_key is UUID, user_id is bigint, request_hash/method/path/status are text, http_status is smallint, response_body is jsonb and both time fields are timestamptz. Only COMPLETED records have a response status/body. Keep completed results for at least 24 hours; cleanup deletes only records past retain_until.

Completed retry. Replaying a completed request with the same hash returns its original status/body without repeating the transaction. For a cached hold response, fetch the owned hold again before restoring a countdown; use fresh serverNow and current status, while preserving the original expiresAt.

Atomic execution. Acquire a PostgreSQL transaction-scoped advisory lock for the complete request-key scope without waiting; failure returns IDEMPOTENCY_IN_FLIGHT. With the lock held, reject a different stored request hash or replay an existing completed result. Otherwise insert IN_PROGRESS, execute the business action and record COMPLETED plus its response and retain_until in the same transaction. A crash or database failure rolls back both action and record. A business rejection can be recorded with no business-data changes. This prevents a committed booking without its replay result.

Rejected retry. Another payload with the same key returns 422 IDEMPOTENCY_KEY_REUSED; an in-progress request returns 409 IDEMPOTENCY_IN_FLIGHT.

Errors use { error: { code, message, details, serverNow } }.

| HTTP response and error code | Meaning and client action |
| --- | --- |
| 422 SELECTION_INVALID | Selection invalid: facility, sequence, hours, cutoff or inactive court. details.reason explains the rejected selection. |
| 409 SLOT_CONFLICT | Slot conflict or invalid held slots. conflictedSlots contains courtId and startTime for each conflicting 30-minute slot; clear selection and refresh UI-06. |
| 404 HOLD_NOT_FOUND | Hold not found. Display the missing-hold result. |
| 403 NOT_OWNER / NOT_FACILITY_OWNER | Resource belongs to another user/facility. Deny access. |
| 409 HOLD_EXPIRED | Hold expired. holdId, expiresAt, serverNow; disable Confirm; no booking is written. |
| 503 RELEASE_FAILED | Release failure. holdId, EXPIRED / ReleaseFailed; keep UI-07 visible until release completes. |
| 404 BOOKING_NOT_FOUND | Booking not found. Display the missing-booking result. |
| 422 CANCEL_DEADLINE_PASSED | Player cancellation under three hours. earliestStartTime and serverNow. |
| 409 BOOKING_INVALID_STATE | Cancelled or past-use booking. currentStatus; do not repeat cancellation. |

### Authentication and access (API-AUTH)

POST /auth/register

Access and input. Public; name, email, phone, password, role. Password ≥ 8 characters; phone ≥ 8 characters.

Response and errors. 201 user { id, name, email, phone, role }; 409 EMAIL_OR_PHONE_EXISTS; 400 VALIDATION_ERROR. Store a bcrypt/Argon2 hash.

POST /auth/login

Access and input. Public; email and password.

Response and errors. 200 accessToken and user; 401 INVALID_CREDENTIALS.

GET /auth/me

Access and input. Authenticated PLAYER or FACILITY_OWNER.

Response and errors. 200 id, name, email, phone, role; 401 UNAUTHORIZED.

### Facility search and availability (API-FAC)

GET /facilities

Access and input. Public; sportId, district, keyword, amenityIds, page, limit.

Response. 200 items { id, name, address, district, sportId, minPrice, openTime, closeTime } and total; 400 VALIDATION_ERROR.

GET /facilities/:facilityId

Access and input. Public; decimal-string facilityId.

Response. 200 facility details, amenities, operatingHours and courts { id, name, status, currentPricePerSlot }; 404 FACILITY_NOT_FOUND.

GET /facilities/:facilityId/schedule

Access and input. Public; date=YYYY-MM-DD.

Response. 200 date, serverNow, courts { courtId, courtName, slots { startTime, endTime, status, price } }; status AVAILABLE / HELD / BOOKED / BLOCKED. 400 INVALID_DATE or 404 FACILITY_NOT_FOUND.

For every 30-minute slot, choose the latest court_price row whose effective_from ≤ slot.startTime. At hold creation, copy that amount to schedule_entry.unit_price; later court-price changes do not alter the held or confirmed total.

### Hold creation reload and release (API-HOLD)

POST /holds requires authentication and Idempotency-Key. Both roles may use this ordinary APP flow. It calls createHold(userId, actorRole, facilityId, selections, false) and either holds the complete valid selection or rejects it without partial writes. Each selections item supplies courtId and slotStartTimes. Example:

{

"facilityId": "12",

"selections": [

{

"courtId": "1",

"slotStartTimes": [

"2026-11-23T18:00:00.000Z",

"2026-11-23T18:30:00.000Z"

]

}

]

}

201 Created returns holdId, facilityId, source, isDirect, status, releaseState, totalPrice, expiresAt, serverNow and items. Each item contains courtId, startTime, endTime and price. For an APP hold: source=APP, isDirect=false, status=ACTIVE and releaseState=None. A hold created at 11:00 UTC expires at 11:05 UTC, regardless of the selected playing date.

GET /holds/active restores the current user’s hold after F5 and returns { activeHold: HoldObject | null, serverNow }. HoldObject includes isDirect derived from source=IN_PERSON. With ?holdId=..., or with GET /holds/:holdId, fetch exactly that owned hold; UI-07 must poll the known ID while release is pending, avoiding a hold from another tab.

| Hold / release state | Meaning | UI-07 action |
| --- | --- | --- |
| ACTIVE / None | serverNow < expiresAt. | Continue the original countdown. |
| EXPIRED / Releasing | Release has been requested and is pending, including fixed expiry. No failure is recorded; the five-second overdue test applies after expiresAt. | Disable Confirm; poll the same hold; wait. |
| EXPIRED / ReleaseFailed | Release failed, or over five seconds beyond expiry. | Show error and remain on UI-07; background worker retries. |
| RELEASED / Released | Release completed; released_at is present. | Return to UI-06 and reload availability. |
| CONFIRMED / None | Converted atomically to a booking. | Show confirmation rather than a release action. |

POST /holds/:holdId/release calls releaseHold(userId, holdId), with ownership checks. It returns 200 { holdId, status: RELEASED, releaseState: Released, expiresAt, serverNow }, 202 with EXPIRED/Releasing, or 503 RELEASE_FAILED with EXPIRED/ReleaseFailed. A pending or failed release does not permit the UI to behave as though the slots were free.

Presence and early release (FR-26). UI-07 sends POST /holds/:holdId/heartbeat every 10 seconds and immediately after restoring the same hold. Authentication and ownership are required. The response contains status, releaseState, fixed expiresAt and fresh serverNow. The server records lastSeen in a volatile per-hold map in the single Express process; heartbeat never changes expiry. ReleaseJob attempts release after 30 seconds without heartbeat. Heartbeat and early release are serialised per hold, and the worker rechecks presence and ACTIVE status before closing the hold. Reload resumes the same hold within this grace period. A process restart or unknown presence does not imply abandonment: use the original five-minute expiry. Both abandonment and normal expiry use the same transactional release and retry handling. The 10/30-second intervals are design parameters, not measured results.

### Booking confirmation history and cancellation (API-BOOK)

POST /holds/:holdId/confirm

Contract. Idempotency-Key; confirmBooking(userId, holdId, false). Recheck ownership, ACTIVE status and serverNow < expiresAt. 201 bookingId, holdId, source=APP, status=CONFIRMED, totalPrice, earliestStartTime, createdAt. At expiry return 409 HOLD_EXPIRED and leave booking data unchanged.

GET /bookings; GET /bookings/:bookingId

Contract. Return booking details/history with status, latestEndTime and serverNow. UI derives Completed when a CONFIRMED booking reaches latestEndTime; no COMPLETED status is stored.

POST /bookings/:bookingId/cancel

Contract. cancelBookingByPlayer(userId, bookingId, reason?). Optional body reason. Require earliestStartTime − serverNow ≥ three hours and cancel the entire booking as CANCELLED_BY_PLAYER.

### Owner management and direct bookings (API-OWN)

All /owner endpoints require FACILITY_OWNER and facility.owner_id = userId. Standard validation errors return 400 VALIDATION_ERROR; ownership errors return 403 NOT_FACILITY_OWNER.

POST /owner/facilities

Contract. Create facility, opening hours, courts and initial prices.

PATCH /owner/facilities/:facilityId

Contract. Update name, address, district, description and amenityIds.

POST /owner/facilities/:facilityId/courts; PATCH /owner/facilities/:facilityId/courts/:courtId

Contract. Add a court or change its name. Court deletion and operating-hour changes use schedule-change preview/apply.

PUT /owner/facilities/:facilityId/courts/:courtId/price

Contract. amountPerSlot ≥ 0 and valid effectiveFrom. Insert a court_price row; availability reads the applicable price at each slot start.

POST /owner/facilities/:facilityId/direct-holds

Contract. Idempotency-Key; createDirectHold checks ownership then calls createHold(ownerId, FACILITY_OWNER, facilityId, selections, true). 201 ordinary hold fields with source=IN_PERSON and isDirect=true.

POST /owner/facilities/:facilityId/direct-holds/:holdId/confirm

Contract. Idempotency-Key; confirmDirectHold verifies ownership and persisted source=IN_PERSON, then confirmBooking(ownerId, holdId, true). 201 bookingId, holdId, source=IN_PERSON, CONFIRMED, totalPrice, createdAt; 409 HOLD_EXPIRED if late.

Direct booking remains a two-step hold/confirm flow. It is exempt from the ordinary 60-minute advance rule (30 minutes ahead is valid), but never overwrites an existing hold, booking or block. Persisted source preserves this context through reload and retry.

### Owner schedule changes (API-OWN)

POST /owner/facilities/:facilityId/schedule-changes/preview takes change = { type: BLOCK | OPERATING_HOURS | DELETE_COURT, courtId?, startTime?, endTime?, operatingHours?, reason? }. The apply endpoint at the same prefix takes { change, expectedBookingIds: string[] } and Idempotency-Key. Apply locks and rechecks the affected rows, holds and 24-hour rules before changing any data.

Response envelope. Preview 200 and apply 409 AFFECTED_BOOKINGS_CHANGED share affectedBookings, expectedBookingIds and serverNow.

Affected items. Each affected booking includes bookingId, playerId, playerName, earliestStartTime, totalPrice and affectedSlots. Each affected slot includes courtId, courtName, startTime and endTime.

Reconfirmation. If bookings were added or removed after preview, display the new list and request confirmation again with its new expectedBookingIds.

### In-app cancellation notices (API-NTF)

List notices. GET /notifications?unreadOnly=true|false&page=&limit= returns items and unreadCount. Each item contains id, bookingId, reason, message, isRead, createdAt and affectedSummary { facilityName, affectedItems }.

Affected items. Each affected item contains courtId (string), courtName, startTime and endTime. Reasons are BLOCKED_PERIOD, HOURS_CHANGED and COURT_DELETED.

Historical snapshot. Persist affected_items when applying the change so a whole-booking cancellation still identifies only the courts and ranges that caused it.

PATCH /notifications/:notificationId/read checks notification.user_id = userId and returns 200 { id, isRead: true }. The persisted flag is notification.is_read (default false).

### Backend module contracts (API-MOD)

BookingController → BookingService

Operation. createHold(userId, actorRole, facilityId, selections, isDirect=false)

Responsibility. All-or-nothing five-minute hold (SEQ-01).

BookingController → BookingService

Operation. confirmBooking(userId, holdId, isDirect=false)

Responsibility. Ownership, expiry and complete-slot revalidation (SEQ-02).

BookingController → BookingService

Operation. releaseHold(userId, holdId)

Responsibility. Releasing / ReleaseFailed / Released (SEQ-02B).

BookingController → BookingService

Operation. cancelBookingByPlayer(userId, bookingId, reason?)

Responsibility. Whole-booking cancellation at least three hours ahead (SEQ-03).

ReleaseJob → BookingService

Operation. releaseExpiredHolds(now); releaseAbandonedHolds(now); heartbeat(userId, holdId)

Responsibility. Check fixed expiry and retry release in the Express process. The same worker checks missing presence; heartbeat updates only volatile presence metadata.

OwnerController → OwnerScheduleService

Operation. createDirectHold(ownerId, facilityId, selections); confirmDirectHold(ownerId, facilityId, holdId)

Responsibility. Check ownership and retain IN_PERSON through both steps (SEQ-05).

OwnerController → OwnerScheduleService

Operation. previewScheduleChange(...); applyScheduleChange(ownerId, change, expectedBookingIds, now)

Responsibility. Recheck holds, 24-hour boundaries and affected-booking set (SEQ-04).

OwnerScheduleService → Notification Module

Operation. createCancellationNotifications(bookings, reason)

Responsibility. Insert notices within the cancellation transaction (FR-30).

# Object-Oriented Design
