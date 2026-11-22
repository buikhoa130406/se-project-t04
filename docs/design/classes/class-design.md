## Class Diagram

The class model separates accounts, facilities and courts from reservations, schedule blocks and in-app notices. Each hold and booking belongs to one facility and contains one or more consecutive slot ranges.

![class-entities](../diagram-sources/output/class-entities.png)

Figure 4.2. CLS-DIAG • Entity classes and associations.

![class-services](../diagram-sources/output/class-services.png)

Figure 4.3. CLS-DIAG • Service responsibilities; operation contracts in Sections 3.7 and 4.3.

## Class Specifications

Logical identifiers map to PostgreSQL bigint values and decimal strings in JSON/URLs. The account roles are PLAYER and FACILITY_OWNER.

The model uses logical fields: identifiers are Id (decimal strings at the interface), text fields are String, flags are Boolean, timestamps are DateTime and amounts are Decimal. Arrays represent owned items or hours. Earliest/latest booking time and isDirectBooking are derived from schedule items and source; priceHistory maps to court_price. Public entity queries include User.verifyPassword(rawPassword): Boolean, Facility.isOwnedBy(userId): Boolean, Facility.isWithinOperatingHours(start,end): Boolean, Court.calculatePrice(slotStartTimes): Decimal and Booking.canCancelByPlayer(now): Boolean. These operations apply the constraints already specified in Sections 3.7 and 5.

| ID | Class | Key members | Responsibility |
| --- | --- | --- | --- |
| CLS-01 | User | id, fullName, email, phone, passwordHash, role, createdAt | Represents a registered account. verifyPassword validates credentials and isOwner identifies the owner role. Ownership of a particular facility is checked separately. |
| CLS-02 | Facility, OperatingHours | id, ownerId, name, address, district, sportType, amenities and operatingHours. An hours entry has dayOfWeek, openTime and closeTime. | One owner manages the facility. isOwnedBy checks ownership and isWithinOperatingHours validates the proposed interval. Each facility has one sport. |
| CLS-03 | Court | id, facilityId, courtCode, priceHistory and isActive | Identifies a court inside a facility. calculatePrice(slotStartTimes) resolves each selected slot’s effective price and sums the amounts; it does not multiply every slot by one current price. isActive maps to the stored court status while preserving history. |
| CLS-04 | SlotHold, HoldSlotItem | id, userId, facilityId, status, createdAt, expiresAt. Each item identifies the court and slot start and end. | Holds the full valid selection for five minutes at most. isExpired(now): Boolean, remainingSeconds(now): Integer and belongsTo(userId): Boolean support expiry, reload and ownership checks. ACTIVE may become CONFIRMED or RELEASED. EXPIRED is the stored non-confirmable release-pending state after expiry or a failed release request. |
| CLS-05 | Booking, BookingItem | id, bookingCode, userId, facilityId, status, isDirectBooking, earliestStartTime, latestEndTime, cancelReason and cancelNote. Items identify the court and time range. | Represents a booking in the shared schedule. Checks the player's three-hour cancellation limit and the owner's 24-hour condition. Derives the display label Completed from the latest end time of a confirmed booking. |
| CLS-06 | ScheduleBlock | id, facilityId, courtId, ownerId, startTime, endTime, createdAt | Represents an unavailable interval on the shared schedule. Checks the 24-hour lead time and whether intervals overlap. |
| CLS-07 | Notification | id, userId, bookingId, reason, message, isRead, affectedItems, createdAt | Stores an in-app owner-cancellation notice, read state and a historical snapshot of the courts and ranges that actually caused the cancellation. |
| CLS-08 | BookingService, OwnerScheduleService | Booking, hold, schedule and facility repositories. OwnerScheduleService uses BookingService and the notification module. | Coordinates the booking transactions and the owner operations. The owner service checks ownership, manages prices, previews changes and revalidates the affected bookings before applying them. |

### Shared booking operations (CLS-08 and SEQ-OPS)

The calling service supplies userId first for all four user-initiated booking operations. ReleaseJob calls releaseExpiredHolds(now) and releaseAbandonedHolds(now). Supporting queries are getActiveHold(userId, holdId?) and heartbeat(userId, holdId); neither extends expiry.

The sequence diagrams use logical participants: AuthService is the authentication/ownership module; ScheduleService.validateSelection is shared scheduling validation; its previewChange/applyChange map to OwnerScheduleService.previewScheduleChange/applyScheduleChange.

FacilityController is the owner controller adapter; previewBlock/confirmBlock adapt the common preview/apply contract. NotificationService.notify maps to createCancellationNotifications. Database messages summarise repository operations and SQL transactions. The service diagram shows responsibilities; the operation contracts here and in Section 3.7 specify the calls.

| Operation | BookingService call | Business outcome |
| --- | --- | --- |
| Acquire hold | createHold(userId, actorRole, facilityId, selections, isDirect) | Creates one active hold for the complete selection, or rejects the whole selection on validation failure or conflict. |
| Confirm | confirmBooking(userId, holdId, isDirect) | Checks ownership, server-side expiry and availability. Creates a confirmed booking or keeps booking data unchanged on rejection. |
| Release | releaseHold(userId, holdId) | Frees the held slots. UI waits during Releasing, shows the failure for ReleaseFailed and opens slot selection after Released. |
| Cancel | cancelBookingByPlayer(userId, bookingId, reason?) | Cancels the entire confirmed booking when the earliest slot is at least three hours away. The reason is optional. |

Cancellation accepts an optional reason, persisted as booking.cancel_note for player cancellation. Counter bookings retain source = IN_PERSON through both hold and confirmation. Notification.isRead maps to notification.is_read; affectedItems records the courts and time ranges that caused an owner cancellation.
