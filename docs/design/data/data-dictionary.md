# Data Design

## Data Diagram

DB-01 • PostgreSQL 16 stores twelve business-data tables. A shared schedule_entry table represents held, booked and blocked ranges, allowing one exclusion constraint to prevent overlap across all three. Logical TimeSlot availability is derived; no slot table is pre-generated. Each hold and booking belongs to one facility, and confirmation converts existing schedule rows without making them temporarily available. The separate api_request_result operational table is specified in API-01; it is not included in the business-data ERD.

![erd-overview](../diagram-sources/output/erd-overview.png)

Figure 5.1. DB-01 • Physical table and key overview.

Keys: PK = primary key; FK = foreign key. Account, facility, court, hold, booking and notice identifiers are bigint internally and decimal strings externally.

## Data Specification

DB-TBL-01–12 • The NULL / default column shows whether NULL is allowed, followed by the default value. Identity columns use GENERATED ALWAYS AS IDENTITY. timestamptz denotes a timestamp with time zone (UTC); local time denotes a time without time zone interpreted in Asia/Ho_Chi_Minh. UQ* denotes a composite unique key.

### DB-TBL-01 • app_user

Registered account with separate login email and contact phone; exactly one role: PLAYER or FACILITY_OWNER.

PA2 references: FR-01, FR-24, NFR-05

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK | Generated primary key. |
| name | text | No / — | — | Nonblank display name. |
| email | text | No / — | UQ | Unique email used for login. |
| phone | text | No / — | UQ | Unique required contact phone. |
| password_​hash | text | No / — | — | Password hash; never plaintext. |
| role | user_​role | No / — | — | PLAYER or FACILITY_OWNER. |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |

Constraints

• Unique email and phone.

• Name, email, phone and password_hash must be nonblank.

• The service checks FACILITY_OWNER when assigning facility ownership.

### DB-TBL-02 • sport

Sport classification; one sport per facility.

PA2 references: FR-04

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK | Generated primary key. |
| name | text | No / — | UQ | Nonblank display name. |

Constraints: Unique, nonblank name.

### DB-TBL-03 • amenity

Reusable amenity used for facility filtering.

PA2 references: FR-05

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK | Generated primary key. |
| name | text | No / — | UQ | Nonblank display name. |

Constraints: Unique, nonblank name.

### DB-TBL-04 • facility

One branch owned by one facility owner.

PA2 references: FR-03, FR-04, FR-17, BR-10

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK | Generated primary key. |
| owner_​id | bigint | No / — | FK → app_​user | Facility-owning account. |
| sport_​id | bigint | No / — | FK → sport | Facility sport. |
| name | text | No / — | — | Nonblank display name. |
| address | text | No / — | — | Full facility address. |
| district | text | No / — | — | Area used for location filtering. |
| description | text | Yes / — | — | Optional free-text description. |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |

Constraints: owner_id → app_user(id) and sport_id → sport(id), ON DELETE RESTRICT. Name, address and district must be nonblank.

### DB-TBL-05 • facility_amenity

Many-to-many link between facilities and amenities.

PA2 references: FR-05

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| facility_​id | bigint | No / — | PK, FK → facility | Facility identifier. |
| amenity_​id | bigint | No / — | PK, FK → amenity | Amenity identifier. |

Constraints: Composite PK (facility_id, amenity_id). Facility deletion cascades only to its link rows; amenity deletion is restricted.

### DB-TBL-06 • operating_hours

One non-overnight opening interval per facility and ISO weekday. A missing weekday means closed.

PA2 references: FR-18

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| facility_​id | bigint | No / — | PK, FK → facility | Facility identifier. |
| day_​of_​week | smallint | No / — | PK | ISO weekday: Monday 1 to Sunday 7. |
| open_​time | local time | No / — | — | Local opening time. |
| close_​time | local time | No / — | — | Local closing time, later than opening. |

Constraints

• Composite PK (facility_id, day_of_week).

• Weekday is 1–7; close_time > open_time.

• Facility deletion cascades to its opening-hour rows.

### DB-TBL-07 • court

Court within a facility; soft deletion preserves reservation history.

PA2 references: FR-06, FR-17, FR-29

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK, UQ* | Generated primary key. |
| facility_​id | bigint | No / — | UQ*, FK → facility | Facility identifier. |
| name | text | No / — | UQ* | Nonblank display name. |
| status | court_​status | No / 'ACTIVE' | — | Lifecycle status; see rules below. |
| deleted_​at | timestamptz | Yes / — | — | Timestamp required for DELETED courts. |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |

Constraints

• UQ (id, facility_id) and (facility_id, name). facility_id → facility(id), RESTRICT.

• Nonblank name.

• ACTIVE requires deleted_at NULL; DELETED requires a deletion timestamp.

### DB-TBL-08 • court_price

Effective-dated price per 30-minute slot. Select the latest effective_from not later than the slot start.

PA2 references: FR-07, FR-19

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| court_​id | bigint | No / — | PK, FK → court | Court identifier. |
| effective_​from | timestamptz | No / — | PK | Price effective from this timestamp. |
| amount_​per_​slot | numeric(12,2) | No / — | — | Nonnegative VND price per 30 minutes. |

Constraints: Composite PK (court_id, effective_from); court_id → court(id), RESTRICT. amount_per_slot ≥ 0.

### DB-TBL-09 • hold

Fixed five-minute reservation. source retains APP or IN_PERSON through reload, confirmation and retry.

PA2 references: FR-10, FR-14, FR-21, FR-25, FR-31, BR-01, BR-07, AC-25

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK, UQ* | Generated primary key. |
| user_​id | bigint | No / — | FK → app_​user | Owning or receiving account. |
| facility_​id | bigint | No / — | UQ*, FK → facility | Facility identifier. |
| source | booking_​source | No / 'APP' | UQ* | APP or IN_PERSON; direct flow is persisted. |
| status | hold_​status | No / 'ACTIVE' | — | ACTIVE, CONFIRMED, RELEASED or EXPIRED (non-confirmable, release pending after expiry or a release request). |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |
| expires_​at | timestamptz | No / now() + 5 min | — | Fixed created_at + five minutes. |
| released_​at | timestamptz | Yes / — | — | Timestamp present only after release. |
| release_​failed_​at | timestamptz | Yes / — | — | Last failed release timestamp; only EXPIRED. |

Constraints: UQ (id, facility_id) and (id, facility_id, source); user_id and facility_id reference their parent IDs with RESTRICT. expires_at = created_at + five minutes. released_at is present exactly when RELEASED. release_failed_at may be present only when EXPIRED. A partial unique index permits at most one ACTIVE hold per user.

### DB-TBL-10 • booking

A confirmed reservation from exactly one hold, inheriting its facility and source. Cancellation changes status rather than deleting history.

PA2 references: FR-11, FR-12, FR-16, FR-21, FR-28, FR-29, FR-30

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK, UQ* | Generated primary key. |
| hold_​id | bigint | No / — | UQ, FK → hold | Originating hold identifier. |
| user_​id | bigint | No / — | FK → app_​user | Owning or receiving account. |
| facility_​id | bigint | No / — | UQ*, FK → facility, FK → hold | Facility identifier. |
| source | booking_​source | No / — | FK → hold | APP or IN_PERSON; direct flow is persisted. |
| status | booking_​status | No / 'CONFIRMED' | — | CONFIRMED, CANCELLED_BY_PLAYER or CANCELLED_BY_OWNER; Completed is derived. |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |
| cancelled_​at | timestamptz | Yes / — | — | Timestamp present for cancelled bookings. |
| cancel_​reason | owner_​change_​reason | Yes / — | — | Owner reason: BLOCKED_PERIOD, HOURS_CHANGED or COURT_DELETED. |
| cancel_​note | text | Yes / — | — | Optional player cancellation reason; NULL otherwise. |

Constraints for booking

• hold_id is unique.

• UQ (id, facility_id).

• Composite FK (hold_id, facility_id, source) → hold(id, facility_id, source); facility_id → facility(id), user_id → app_user(id), all RESTRICT.

• CONFIRMED has no cancellation fields; CANCELLED_BY_PLAYER has cancelled_at and optional cancel_note, without cancel_reason; CANCELLED_BY_OWNER has cancelled_at and cancel_reason, without cancel_note.

### DB-TBL-11 • schedule_entry

One court and one consecutive, equal-price range. HOLD, BOOKING and BLOCK share this table; only active rows occupy the schedule.

PA2 references: FR-07, FR-09, FR-13, FR-16, FR-20, FR-22, NFR-02, BR-02, BR-03, BR-13

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK | Generated primary key. |
| court_​id | bigint | No / — | UQ*, FK → court | Court identifier. |
| facility_​id | bigint | No / — | FK → booking, FK → court, FK → hold | Repeated facility ID for composite foreign keys. |
| start_​time | timestamptz | No / — | UQ* | Inclusive range start; exact 00/30-minute mark. |
| end_​time | timestamptz | No / — | — | Exclusive range end; exact 00/30-minute mark. |
| entry_​type | entry_​type | No / — | — | HOLD, BOOKING or BLOCK. |
| hold_​id | bigint | Yes / — | UQ*, FK → hold | Original hold for HOLD/BOOKING; NULL for BLOCK. |
| booking_​id | bigint | Yes / — | FK → booking | Related booking identifier. |
| blocked_​by | bigint | Yes / — | FK → app_​user | Owner who created a BLOCK. |
| unit_​price | numeric(12,2) | Yes / — | — | Historical VND price per 30 minutes; NULL for BLOCK. |
| is_​active | boolean | No / true | — | Occupies schedule when true; retained as history when false. |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |

Constraints for schedule_entry

• Composite FKs (court_id, facility_id), (hold_id, facility_id), (booking_id, facility_id) enforce one facility; blocked_by → app_user(id), all RESTRICT. end_time > start_time; both bounds must be exact 00/30-minute marks.

• HOLD has hold_id and unit_price ≥ 0 only; BOOKING additionally has booking_id; BLOCK has blocked_by only and no price.

• BLOCK cannot become inactive.

• Active ranges on one court must not overlap. (hold_id, court_id, start_time) is unique whenever hold_id is present, including historical rows.

### DB-TBL-12 • notification

In-app notice for owner cancellation, with read state and a snapshot of only the courts and ranges actually affected.

PA2 references: FR-30, NFR-09, BR-16

| Column | Type | NULL / default | Key | Meaning |
| --- | --- | --- | --- | --- |
| id | bigint | No / identity | PK | Generated primary key. |
| user_​id | bigint | No / — | FK → app_​user | Owning or receiving account. |
| booking_​id | bigint | No / — | FK → booking | Related booking identifier. |
| reason | owner_​change_​reason | No / — | — | BLOCKED_PERIOD, HOURS_CHANGED or COURT_DELETED. |
| message | text | No / — | — | Nonblank display message. |
| is_​read | boolean | No / false | — | Read flag; maps to isRead, unreadOnly and unreadCount. |
| affected_​items | jsonb | No / '[]' | — | Snapshot array of courtId (string), courtName, startTime and endTime that caused owner cancellation. |
| created_​at | timestamptz | No / now() | — | Creation timestamp. |

Constraints: user_id → app_user(id), booking_id → booking(id), RESTRICT. Message is nonblank. affected_items must be a JSON array.

### DB-ATOM • Atomicity and concurrency

| ID | Database protection |
| --- | --- |
| DB-CON-01 | Partial GiST EXCLUDE: equal court_id and overlapping [start_time, end_time) ranges are forbidden WHERE is_active. Requires btree_gist. Covers HOLD, BOOKING and BLOCK together. |
| DB-CON-02 | Unique hold/court/start ranges plus one ACTIVE hold per user; price changes may split consecutive selections into multiple equal-price ranges. |
| DB-CON-03 | Composite court/hold/booking foreign keys bind every schedule row to one facility; booking also inherits hold.source. |
| DB-CON-04 | Fixed five-minute expiry and release-failure state consistency. |
| DB-CON-05 | Positive duration and exact 00/30-minute bounds, including seconds and fractional seconds. |
| DB-CON-06 | entry_type selects the permitted foreign-key fields and price nullability. |
| DB-CON-07 | One booking per hold; cancellation fields agree with booking status. |
| DB-CON-08 | BLOCK rows remain active; no unblock operation is in scope. |
| DB-CON-09 | Historical references use ON DELETE RESTRICT; soft deletion and inactive rows preserve history. |

### DB-ATOM-02 • Create a hold

Use one READ COMMITTED transaction. Lock active courts in ascending ID order FOR SHARE; check one facility and owner rights for IN_PERSON. After acquiring the lock, read opening hours again, validate every range and the ordinary 60-minute cutoff. Before splitting at price changes, check that selected 30-minute slots are consecutive on each court and do not overlap. Find each slot’s effective price, group adjacent slots with the same price, then insert the hold and all ranges in ascending (court_id, start_time) order. Any invalid selection or conflict rolls back the complete hold. After rollback, return each conflicting 30-minute slot as courtId/startTime.

### DB-ATOM-03 • Contention and ordering

The exclusion constraint waits for a competing transaction: if it commits, the overlapping insert fails (23P01); if it rolls back, the waiting insert may succeed. Consistent court/time ordering reduces deadlocks. On a deadlock (40P01), roll back the whole transaction and report a slot conflict rather than retain a partial reservation.

### DB-ATOM-04 • Confirm and expire

Lock the hold FOR UPDATE. Recheck the user, facility ownership for IN_PERSON, persisted source, ACTIVE state and real database time clock_timestamp() < expires_at; now() is unsuitable for the expiry check after waiting on locks. Revalidate active courts and the complete held ranges. Insert one booking inheriting source/facility, mark the hold CONFIRMED and convert its active HOLD rows to BOOKING without releasing them, all in one transaction. At or after expiry, create no booking.

### DB-REL • Release reload and presence

ReleaseJob runs in the Express process at a designed interval of at most one second. It also checks the volatile presence map described in API-HOLD. On fixed expiry or a confirmed release request (explicit or detected abandonment), prevent confirmation and use EXPIRED as the release-pending state. Deactivate all held schedule rows and mark RELEASED atomically. On failure, retain EXPIRED and release_failed_at for retry. UI mapping is Releasing while pending, ReleaseFailed after an error or more than five seconds beyond fixed expiry, and Released only after completion. Poll the known hold by ID and user; reload restores the same owned hold and its fixed expiry, then sends heartbeat. A missing presence record after restart falls back to expiry.

### DB-ATOM-05 • Player cancellation

Lock the booking, check existence, ownership, CONFIRMED status and earliest slot start minus real server time ≥ three hours. Set CANCELLED_BY_PLAYER, cancelled_at and the optional trimmed cancel_note; deactivate every schedule row for that booking in the same transaction.

### DB-ATOM-06 • Owner schedule changes

Preview is read-only. Apply locks affected courts FOR UPDATE in ascending order, then re-reads affected active ranges. Reject while affected holds remain. Recheck all affected bookings using the earliest start across their entire booking, including unaffected courts: every booking must be at least 24 hours away. Compare the complete affected-booking ID set with expectedBookingIds; if it changed, roll back and return the new preview. Before deactivating ranges, snapshot only the intersections that actually caused the change into notification.affected_items. Cancel whole affected bookings, deactivate all their schedule rows, apply the block/hours change/soft deletion and insert notices atomically. Shared court locks serialize new holds with owner changes; creators re-read hours after waiting.

Price example: two consecutive slots at 18:00 and 18:30 cross a price change from VND 100,000 to VND 120,000 effective at 18:30. Store two equal-price ranges under one hold, total VND 220,000. Selecting 18:00 and 19:00 while omitting 18:30 is rejected before price splitting. Different courts may have different time ranges.

### DB-BV • Time boundaries and ownership

| ID | Boundary and enforcement |
| --- | --- |
| DB-BV-01 | Exact 30-minute slots; service checks per-court consecutiveness before price splitting. Database CHECK validates precise aligned bounds. |
| DB-BV-02 | Hold is exactly five minutes; confirmation is valid only strictly before expiresAt. |
| DB-BV-03 | Release target ≤ five seconds after expiry; worker interval ≤ one second is a design choice requiring measured validation. |
| DB-BV-04 | APP proceed requires earliestStartTime − serverNow ≥ 60 minutes. IN_PERSON is exempt after owner checks, but cannot select past time. |
| DB-BV-05 | Player cancellation is allowed at exactly three hours and rejected below three hours. |
| DB-BV-06 | A block begins at least 24 hours ahead; validate in preview and again in apply. |
| DB-BV-07 | Every affected booking begins at least 24 hours ahead, based on its earliest slot across all courts. Exactly 24 hours is allowed; one earlier booking rejects the whole change. |
| DB-BV-08 | Affected active holds prevent owner changes until they finish; never overwrite them. |
| DB-BV-09 | Every range fits current opening hours and an active court; read hours after acquiring the court lock. |
| DB-BV-10 | Check facility ownership for owner operations and both IN_PERSON steps; check user ownership for holds and bookings. |

### DB-HIS • Historical information

Retain cancelled bookings and inactive schedule rows. Soft-delete courts and restrict deletion of referenced users/facilities. Store historical unit_price instead of recalculating history from current court_price. Compute totalPrice as Σ(unit_price × range duration / 30 minutes). Preserve cancel_reason/cancel_note and the original notification.affected_items. Completed and visible slot status are derived from time and active schedule entries, preventing duplicate status sources.

## Normalisation and Indexes

### DB-NF • Normalisation and deliberate exceptions

Account, sport, amenity, facility, facility–amenity, opening-hours, court and price attributes follow their complete keys (3NF). The following controlled redundancies or historical snapshots support consistency and history:

| Exception | Reason and protection |
| --- | --- |
| NE-1 • schedule_entry.facility_id | Repeats the court’s facility so composite FKs enforce one facility across court, hold and booking. |
| NE-2 • booking.facility_id/source | Repeats hold data, guarded by the composite FK; supports facility/source filtering. |
| NE-3 • hold.expires_at | Derived from created_at but stored for expiry indexing; CHECK fixes the five-minute interval. |
| NE-4 • schedule_entry.unit_price | Historical price snapshot; later price edits cannot change hold/booking totals. |
| NE-5 • notification.affected_items | JSON historical snapshot of the exact change intersections; later schedule edits do not rewrite cancellation evidence. |

schedule_entry uses nullable foreign-key/price fields for its three entry types. CHECK constraints enforce the valid combinations; this tradeoff lets one exclusion constraint protect every occupied range.

### DB-Q • Query and index plan

| ID / query | Supporting index or key |
| --- | --- |
| DB-Q01 • Sport and area search | facility_sport_area_idx (sport_id, district). |
| DB-Q02 • Amenity filter | facility_amenity composite PK and facility_amenity_rev_idx (amenity_id, facility_id). |
| DB-Q03 • Court/day availability and price | Partial GiST exclusion index on active ranges; court_facility_active_idx; court_price PK (court_id, effective_from). Generate 30-minute slots within opening hours and derive status from active overlaps. |
| DB-Q04 • User history and facility bookings | booking_user_idx (user_id, created_at DESC); booking_facility_idx (facility_id, status). Return totalPrice, earliestStartTime, latestEndTime. |
| DB-Q05 • Booking items and earliest start | schedule_entry_booking_idx (booking_id), filtered when booking_id is present. |
| DB-Q06 • Affected ranges | GiST range overlap lookup on the court, as in DB-Q03. |
| DB-Q07 • Expiry and release retry | hold_expiry_idx for ACTIVE and hold_release_retry_idx for EXPIRED, both on expires_at. |
| DB-Q08 • Hold recovery or exact-ID lookup | hold_user_active_idx: unique user_id WHERE ACTIVE; hold primary key for a known ID. |
| DB-Q09 • Notices, unread count and read state | notification_user_idx (user_id, is_read, created_at DESC). |
| DB-Q10 • Owner facilities | facility_owner_idx (owner_id). |

### DB-EVD • Validation scope and assumptions

The schema checks cover overlap, rollback, precise time alignment, source inheritance, price changes, affected-item snapshots and consecutive selections. Trí reports 29/29 checks passing on PostgreSQL 16.

The React–Express–PostgreSQL feasibility spike verifies connectivity and price read/write. Release within five seconds, concurrency capacity, query latency and the three-minute booking flow require separate tests.

Design assumptions: district is an owner-entered filter; email is the login field and phone is required; PostgreSQL must permit btree_gist; each account has one role and each facility one sport; opening hours have one interval per weekday without overnight operation; courts are soft-deleted; no unblock/edit-block use case is introduced.
