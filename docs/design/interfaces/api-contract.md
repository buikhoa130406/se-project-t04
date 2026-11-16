# Đặc tả Giao tiếp Frontend–Backend và Giữa các Module (Task 3.1.4 — Issue #12)

- **Mã đối tượng truy vết:** `API-01` (Quy ước chung & Idempotency), `API-AUTH` (Xác thực & Phân quyền), `API-FAC` (Tìm kiếm & Lịch sân), `API-HOLD` (Giữ chỗ 5 phút & Giải phóng), `API-BOOK` (Xác nhận, Lịch sử & Hủy đơn), `API-OWN` (Quản lý chủ sân & Thay đổi lịch 24h), `API-NTF` (Thông báo In-app), `API-MOD` (Giao tiếp nội bộ giữa các Module)
- **Người thực hiện:** Lý Sĩ Vĩ (`@Lysivi2005` — tiếp nhận tạm thời theo chuyển giao ngày 15/11/2026)
- **Người kiểm tra:** Trí (`@nmt1206` — đối chiếu hợp đồng API với sơ đồ trình tự `3.3.3`, `STM-01..03` và baseline PA2: validation, quyền và phản hồi lỗi)
- **Tài liệu đối chiếu:** Baseline PA2, `3.1.1` (`architecture-design.md`), `3.2.1` (`ui-design-specification.md`), `3.3.2` (`class-design.md`), `3.3.3` (`sequence-diagrams.md`), `3.3.4` (`state-machines.md`)

---

## 1. [`API-01`] Quy ước chung, Thời gian Server & Idempotency

### 1.1. Chuẩn giao tiếp & Bảo mật
- **Giao thức:** RESTful JSON qua HTTPS, Base URL `/api/v1`.
- **Xác thực:** `Authorization: Bearer <jwt>` cho mọi endpoint yêu cầu đăng nhập; `Auth & RBAC Middleware` kiểm tra JWT và vai trò (`PLAYER` hoặc `OWNER`) trước khi vào Controller (`NFR-04`).
- **Định dạng thời gian:** ISO-8601 UTC (`YYYY-MM-DDTHH:mm:ss.sssZ`), ví dụ `2026-11-16T11:05:00.000Z`.
- **Khung lỗi thống nhất:**

```json
{
  "error": {
    "code": "SLOT_CONFLICT",
    "message": "Một hoặc nhiều khung giờ đã được giữ hoặc đặt trước.",
    "details": {
      "conflictedSlots": [
        { "courtId": "c-01", "startTime": "2026-11-17T18:00:00.000Z" }
      ]
    },
    "serverNow": "2026-11-16T11:00:00.000Z"
  }
}
```

### 1.2. Đồng bộ thời gian Server, Bảo toàn Hold khi F5 & Chống gửi lặp (Idempotency)
1. **Nguồn chân lý thời gian (`serverNow`, `expiresAt`):**
   - Backend tính `expiresAt = createdAt + 5 phút` theo đồng hồ server và lưu cố định trong DB (`SlotHold`).
   - Mọi phản hồi liên quan tới Hold đều trả về cặp `{ "expiresAt": "...", "serverNow": "..." }`. Frontend tính độ lệch đồng hồ `offset = serverNow - clientNow` để đếm ngược chính xác, **không tự tính hoặc gia hạn 5 phút** (`FR-25`, `FR-31`).
2. **Bảo toàn khi tải lại trang (F5):**
   - Frontend **không** gọi API nhả chỗ trong `beforeunload` / `pagehide`. Khi F5 vào `UI-07`, client gọi `GET /api/v1/holds/active` để khôi phục `holdId`, danh sách slot, `expiresAt` và `serverNow` (`FR-25`, `AC-22`).
3. **Chống gửi lặp & Mất kết nối không rõ kết quả:**
   - Các thao tác ghi quan trọng (`POST /holds`, `POST /holds/:id/confirm`, `POST /owner/direct-bookings`, `POST /owner/schedule-changes/apply`) hỗ trợ header **`Idempotency-Key: <uuid-v4>`** (lưu kèm `userId` trong phạm vi phiên/giao dịch):
     - Nếu người dùng bấm đúp hoặc retry do rớt mạng với cùng `Idempotency-Key`, server trả lại kết quả của giao dịch đầu tiên, **không tạo Hold/Booking trùng**.
     - Với `confirmBooking`, tầng DB còn có khóa dòng/kiểm tra trạng thái `HoldStatus == ACTIVE` + `now < expiresAt` trong cùng Transaction nên không thể xác nhận 2 lần thành 2 Booking (`FR-11`, `NFR-02`).
   - Với thao tác **nhả chỗ** (`POST /holds/:id/release` hoặc khi Hold vừa hết hạn): phản hồi luôn mang trạng thái thực tế `releaseState` gồm **`Releasing`**, **`ReleaseFailed`**, hoặc **`Released`** (khớp `STM-01`, `SEQ-02B`, `UI-07`).

---

## 2. Danh mục Endpoint & Hợp đồng chi tiết

### 2.1. [`API-AUTH`] Xác thực & Phân quyền (`UI-03`, `UI-04`, `UI-05`)

| Method & Endpoint | Quyền | Request / Validation | Response `200/201` | Lỗi nghiệp vụ |
|---|---|---|---|---|
| `POST /auth/register` | Public | `{ fullName, email, password, phone, role: "PLAYER" \| "OWNER" }` (mật khẩu $\ge 8$ ký tự, băm bcrypt/argon2 trước khi lưu, `NFR-05`) | `201`: `{ user: { id, fullName, email, role } }` | `409 EMAIL_EXISTS`, `400 VALIDATION_ERROR` |
| `POST /auth/login` | Public | `{ email, password }` | `200`: `{ accessToken, user: { id, fullName, role } }` | `401 INVALID_CREDENTIALS` |
| `GET /auth/me` | `PLAYER`, `OWNER` | Header JWT | `200`: `{ id, fullName, email, role }` | `401 UNAUTHORIZED` |

---

### 2.2. [`API-FAC`] Tìm kiếm Cơ sở & Xem Lịch trống (`UI-01`, `UI-02`, `UI-06`)

| Method & Endpoint | Quyền | Request / Query | Response `200` | Lỗi nghiệp vụ |
|---|---|---|---|---|
| `GET /facilities` | Public | `?sportType=&district=&keyword=&amenities=&page=&limit=` | `{ items: [{ id, name, address, district, sportTypes, minPrice, openTime, closeTime }], total }` | `400 VALIDATION_ERROR` |
| `GET /facilities/:facilityId` | Public | Path `facilityId: UUID` | `{ id, name, address, description, openTime, closeTime, courts: [{ id, name, sportType, pricePer30m, isActive }] }` | `404 FACILITY_NOT_FOUND` |
| `GET /facilities/:facilityId/schedule` | Public | `?date=YYYY-MM-DD` (mỗi slot chia chuẩn 30 phút, `BR-03`) | `{ date, serverNow, courts: [{ courtId, courtName, slots: [{ startTime, endTime, status: "AVAILABLE" \| "HELD" \| "BOOKED" \| "BLOCKED", price }] }] }` | `404 FACILITY_NOT_FOUND`, `400 INVALID_DATE` |

---

### 2.3. [`API-HOLD`] Giữ chỗ 5 phút & Giải phóng (`UI-06`, `UI-07`, `SEQ-01`, `SEQ-02B`, `STM-01`)

#### A. Tạo lượt giữ chỗ (`POST /holds`)
- **Ánh xạ lớp (`3.3.2`):** `BookingService.createHold(userId, actorRole, facilityId, selections, isDirect = false)`
- **Quyền:** `PLAYER` (hoặc `OWNER` đặt qua luồng người chơi bình thường; đặt tại quầy dùng `POST /owner/direct-bookings` với `isDirect = true`).
- **Headers:** `Authorization: Bearer <jwt>`, `Idempotency-Key: <uuid>`
- **Request Body:**
```json
{
  "facilityId": "fac-01",
  "selections": [
    {
      "courtId": "court-01",
      "slotStartTimes": [
        "2026-11-17T18:00:00.000Z",
        "2026-11-17T18:30:00.000Z"
      ]
    }
  ]
}
```
- **Validation & Tác động dữ liệu:**
  1. Tất cả `courtId` thuộc cùng `facilityId`, sân đang `isActive = true`.
  2. Mỗi slot đúng bội số 30 phút, nằm trong giờ mở cửa, và **liên tiếp nhau trên từng sân** (`BR-03`, `FR-32`).
  3. Vì `isDirect = false`: khung bắt đầu sớm nhất phải cách `serverNow` **$\ge 60$ phút ($\ge 2$ slot)** (`FR-27`, `BR-08`).
  4. Thực thi **All-or-Nothing** trong 1 PostgreSQL Transaction: kiểm tra không xung đột `HELD` / `BOOKED` / `BLOCKED`; nếu hợp lệ $\rightarrow$ tạo `SlotHold` (`status = ACTIVE`, `expiresAt = serverNow + 5 phút`) và `HoldItem`. Nếu $\ge 1$ slot xung đột $\rightarrow$ rollback toàn bộ (`FR-13`, `NFR-02`).
- **Response `201 Created`:**
```json
{
  "holdId": "hold-101",
  "facilityId": "fac-01",
  "status": "ACTIVE",
  "isDirect": false,
  "totalPrice": 160000,
  "expiresAt": "2026-11-16T11:05:00.000Z",
  "serverNow": "2026-11-16T11:00:00.000Z",
  "items": [
    { "courtId": "court-01", "startTime": "2026-11-17T18:00:00.000Z", "endTime": "2026-11-17T18:30:00.000Z", "price": 80000 },
    { "courtId": "court-01", "startTime": "2026-11-17T18:30:00.000Z", "endTime": "2026-11-17T19:00:00.000Z", "price": 80000 }
  ]
}
```
- **Mã lỗi:**
  - `401 UNAUTHORIZED` (Khách chưa đăng nhập — UI chuyển `UI-03`, không tạo Hold, `FR-23`).
  - `422 SELECTION_INVALID` (`NON_CONSECUTIVE_SLOTS`, `OUT_OF_OPERATING_HOURS`, `LEAD_TIME_UNDER_60M`, `COURT_INACTIVE`).
  - `409 SLOT_CONFLICT` (trả kèm `details.conflictedSlots` để `UI-06` báo rõ khung bị trùng và làm mới ma trận).

#### B. Khôi phục lượt giữ khi F5 (`GET /holds/active`)
- **Quyền:** `PLAYER`, `OWNER`
- **Response `200 OK`:**
  - Nếu đang có Hold `ACTIVE` (`serverNow < expiresAt`): trả cấu trúc giống `POST /holds` kèm `expiresAt`, `serverNow`.
  - Nếu Hold vừa hết hạn (`serverNow >= expiresAt`) và worker đang/chưa nhả xong: trả `{ "activeHold": null, "lastHold": { "holdId": "...", "status": "EXPIRED", "releaseState": "Releasing" | "ReleaseFailed" | "Released", "serverNow": "..." } }` để `UI-07` đồng bộ đúng `STM-01`.
  - Nếu không có Hold nào: `{ "activeHold": null, "serverNow": "..." }`.

#### C. Nhả lượt giữ chỗ (`POST /holds/:holdId/release`)
- **Ánh xạ lớp (`3.3.2`):** `BookingService.releaseHold(userId, holdId)`
- **Quyền:** `PLAYER`, `OWNER` (phải là chủ sở hữu `SlotHold.userId === userId`).
- **Response `200 OK` (`Released`):**
```json
{
  "holdId": "hold-101",
  "status": "RELEASED",
  "releaseState": "Released",
  "serverNow": "2026-11-16T11:02:10.000Z"
}
```
- **Phản hồi khi đang xử lý hoặc nhả lỗi (đồng bộ `UI-07`, `STM-01`, `SEQ-02B`):**
  - `202 Accepted`: `{ "holdId": "hold-101", "status": "EXPIRED", "releaseState": "Releasing", "serverNow": "..." }` $\rightarrow$ `UI-07` **tiếp tục chờ**, chưa cho quay về `UI-06`.
  - `500 / 503 RELEASE_FAILED`: `{ "error": { "code": "RELEASE_FAILED", "message": "Chưa giải phóng được khung giờ.", "details": { "holdId": "hold-101", "status": "EXPIRED", "releaseState": "ReleaseFailed" } } }` $\rightarrow$ `UI-07` **báo lỗi và giữ nguyên màn hình**, chỉ cho quay về `UI-06` khi nhận `Released` (`FR-14`, `AC-20`).
  - `403 NOT_OWNER`, `404 HOLD_NOT_FOUND`.

---

### 2.4. [`API-BOOK`] Xác nhận, Chi tiết & Hủy đơn (`UI-07`, `UI-08`, `UI-09`, `UI-10`, `SEQ-02`, `SEQ-03`)

#### A. Xác nhận đặt sân (`POST /holds/:holdId/confirm`)
- **Ánh xạ lớp (`3.3.2`):** `BookingService.confirmBooking(userId, holdId, isDirect)` (với người chơi `isDirect = false`; với đặt tại quầy `isDirect = true` do `OwnerScheduleService` truyền sau khi xác minh quyền sở hữu).
- **Headers:** `Authorization: Bearer <jwt>`, `Idempotency-Key: <uuid>`
- **Validation & Tác động dữ liệu (trong 1 Transaction):**
  1. `SlotHold.userId === userId` (`AC-36`).
  2. `SlotHold.status === ACTIVE` và **`serverNow < expiresAt`** (kiểm tra tức thì theo thời gian thực, không phụ thuộc worker đã chạy hay chưa, `AC-35`, `AC-39`).
  3. Recheck tình trạng trống trên lịch chung; chuyển `SlotHold -> CONFIRMED`, tạo `Booking` (`status = CONFIRMED`, tự động xác nhận không chờ chủ sân duyệt, `FR-12`) và `BookingItem`.
- **Response `201 Created`:**
```json
{
  "bookingId": "bk-201",
  "holdId": "hold-101",
  "status": "CONFIRMED",
  "isDirectBooking": false,
  "totalPrice": 160000,
  "earliestStartTime": "2026-11-17T18:00:00.000Z",
  "createdAt": "2026-11-16T11:03:00.000Z"
}
```
- **Mã lỗi:** `404 HOLD_NOT_FOUND`, `403 NOT_OWNER`, `409 HOLD_EXPIRED` (từ chối ngay, dữ liệu `Booking` giữ nguyên), `409 SLOT_CONFLICT`.

#### B. Xem danh sách & Chi tiết đơn (`GET /bookings`, `GET /bookings/:bookingId`)
- **Quyền:** `PLAYER` (chỉ xem đơn của mình), `OWNER` (xem đơn thuộc cơ sở mình quản lý).
- **Ghi chú hiển thị (`STM-03`, `UI-09`):** Server trả `status = "CONFIRMED"` kèm `latestEndTime` và `serverNow`; khi `status === "CONFIRMED"` và `serverNow >= latestEndTime`, UI suy diễn nhãn hiển thị *"Đã hoàn thành"*.

#### C. Người chơi hủy toàn bộ đơn (`POST /bookings/:bookingId/cancel`)
- **Ánh xạ lớp (`3.3.2`):** `BookingService.cancelBookingByPlayer(userId, bookingId, reason?)`
- **Quyền:** `PLAYER` (chủ sở hữu đơn).
- **Request Body:** `{ "reason": "Bận việc đột xuất" }` (`reason` là **tùy chọn**, có thể để trống hoặc không gửi).
- **Validation:** `earliestStartTime - serverNow >= 3 giờ` (đúng 3 giờ vẫn hợp lệ, `FR-28`, `BR-09`). Không cho hủy lẻ từng sân/khung (`AC-27`).
- **Response `200 OK`:** `{ "bookingId": "bk-201", "status": "CANCELLED_BY_PLAYER", "cancelledAt": "..." }`
- **Mã lỗi:** `404 BOOKING_NOT_FOUND`, `403 NOT_OWNER`, `422 CANCEL_DEADLINE_PASSED` (`< 3 giờ`), `409 BOOKING_ALREADY_CANCELLED`.

---

### 2.5. [`API-OWN`] Quản lý Chủ sân, Đặt tại quầy & Thay đổi lịch $\ge 24\text{h}$ (`UI-14`, `UI-15`, `SEQ-04`, `SEQ-05`)

*(Mọi endpoint nhóm `/owner/*` yêu cầu vai trò `OWNER` và kiểm tra `facility.ownerId === userId` tại Backend, `FR-03`, `NFR-04`.)*

| Method & Endpoint | Ánh xạ lớp (`3.3.2`) | Request / Quy tắc | Response `200/201` | Lỗi nghiệp vụ |
|---|---|---|---|---|
| `POST /owner/facilities` | `OwnerScheduleService` | Tạo cơ sở, sân con, khung giá (`pricePer30m`), giờ mở/đóng cửa | `201`: `{ facility }` | `403 FORBIDDEN`, `400 VALIDATION_ERROR` |
| `POST /owner/facilities/:facilityId/direct-bookings` | `OwnerScheduleService.createDirectBooking(ownerId, facilityId, selections)` | Đặt tại quầy: kiểm tra quyền sở hữu trước $\rightarrow$ gọi `BookingService.createHold(..., isDirect = true)` và `confirmBooking(..., isDirect = true)` trong cùng luồng kiểm tra lịch chung. **Miễn mốc 60 phút** (đặt trước 30 phút vẫn hợp lệ, `AC-25`), nhưng không đè Hold/Booking/Block đang có (`FR-21`, `BR-08`). Hỗ trợ `Idempotency-Key`. | `201`: `{ bookingId, status: "CONFIRMED", isDirectBooking: true }` | `403 NOT_FACILITY_OWNER`, `409 SLOT_CONFLICT`, `422 SELECTION_INVALID` |
| `POST /owner/facilities/:facilityId/schedule-changes/preview` | `OwnerScheduleService.previewScheduleChange(ownerId, change)` | `change`: `{ type: "BLOCK" \| "OPERATING_HOURS" \| "DELETE_COURT", courtId?, startTime?, endTime?, reason? }`. Kiểm tra: (1) Nếu `BLOCK`: `startTime - serverNow >= 24 giờ` (`BR-12`); (2) Không có `SlotHold` `ACTIVE` bị ảnh hưởng (`FR-29`, `AC-30`); (3) Toàn bộ `Booking` bị ảnh hưởng có `earliestStartTime - serverNow >= 24 giờ` (`BR-11`, `AC-29`). | `200`: `{ affectedBookings: [{ bookingId, playerId, earliestStartTime, totalPrice }], count, serverNow }` | `403 NOT_FACILITY_OWNER`, `409 ACTIVE_HOLD_CONFLICT`, `422 BOOKING_UNDER_24H`, `422 BLOCK_UNDER_24H` |
| `POST /owner/facilities/:facilityId/schedule-changes/apply` | `OwnerScheduleService.applyScheduleChange(ownerId, change, expectedBookingIds, now)` | Gửi kèm `expectedBookingIds: UUID[]` từ bước preview và `Idempotency-Key`. Trong 1 Transaction: kiểm tra lại `ACTIVE_HOLD_CONFLICT`, `BOOKING_UNDER_24H`, và **so sánh toàn bộ tập `expectedBookingIds` với tập đơn bị ảnh hưởng mới**. Nếu **thêm hoặc bớt** lượt $\rightarrow$ trả lại danh sách mới để chủ sân xác nhận lại (`SEQ-04`). Nếu khớp hoàn toàn $\rightarrow$ hủy hàng loạt (`CANCELLED_BY_OWNER`), cập nhật lịch và tạo `Notification` In-app (`FR-30`). | `200`: `{ applied: true, cancelledBookingIds: [...] }`<br>hoặc `409 AFFECTED_BOOKINGS_CHANGED`: `{ affectedBookings: [...] }` | `403 NOT_FACILITY_OWNER`, `409 ACTIVE_HOLD_CONFLICT`, `409 AFFECTED_BOOKINGS_CHANGED`, `422 BOOKING_UNDER_24H` |

---

### 2.6. [`API-NTF`] Thông báo In-app (`UI-15`, `CLS-07`)

| Method & Endpoint | Quyền | Request / Query | Response `200` | Lỗi |
|---|---|---|---|---|
| `GET /notifications` | `PLAYER`, `OWNER` | `?unreadOnly=true\|false&page=&limit=` | `{ items: [{ id, type, title, message, relatedBookingId, isRead, createdAt }], unreadCount }` | `401 UNAUTHORIZED` |
| `PATCH /notifications/:notificationId/read` | `PLAYER`, `OWNER` | Kiểm tra `notification.userId === userId` | `{ id, isRead: true }` | `403 NOT_OWNER`, `404 NOT_FOUND` |

---

## 3. [`API-MOD`] Hợp đồng Giao tiếp Giữa các Module Backend

| Module gọi | Module nhận | Thao tác & Tham số | Ghi chú đồng bộ |
|---|---|---|---|
| `BookingController` | `BookingService` | `createHold(userId, actorRole, facilityId, selections, isDirect = false)` | Tạo Hold 5 phút All-or-Nothing (`SEQ-01`). |
| `BookingController` | `BookingService` | `confirmBooking(userId, holdId, isDirect = false)` | Recheck quyền, `now < expiresAt`, tạo `Booking` (`SEQ-02`). |
| `BookingController` | `BookingService` | `releaseHold(userId, holdId)` | Nhả Hold thủ công; trả `Releasing` / `ReleaseFailed` / `Released` (`SEQ-02B`). |
| `BookingController` | `BookingService` | `cancelBookingByPlayer(userId, bookingId, reason?)` | Hủy toàn bộ đơn $\ge 3\text{h}$ (`SEQ-03`). |
| `Hold Expiry Worker` (`ReleaseJob`) | `BookingService` | `releaseExpiredHolds(now)` | Chạy trong tiến trình Express, qua Repository cập nhật Hold hết hạn `EXPIRED -> RELEASED`; thử lại ở chu kỳ sau nếu DB lỗi (`3.1.1`, `NFR-03`). |
| `OwnerController` | `OwnerScheduleService` | `createDirectBooking(ownerId, facilityId, selections)` | Xác minh `Facility.isOwnedBy(ownerId)` trước khi gọi `BookingService.createHold/confirmBooking(..., isDirect = true)` (`AC-25`, `SEQ-05`). |
| `OwnerController` | `OwnerScheduleService` | `previewScheduleChange(...)` / `applyScheduleChange(ownerId, change, expectedBookingIds, now)` | Kiểm tra Hold ảnh hưởng + mốc 24h; so sánh tập `expectedBookingIds` (`SEQ-04`). |
| `OwnerScheduleService` | `In-App Notification Module` | `createCancellationNotifications(bookings, reason)` | Tạo bản ghi `Notification` trong cùng Transaction khi hủy đơn $\ge 24\text{h}$ (`FR-30`). |

---

## 4. Thông tin gửi kèm Review (Theo Working Agreement Mục 5.3)

- **Danh sách sản phẩm:** `docs/design/interfaces/api-contract.md` (Mã đối tượng: `API-01`, `API-AUTH`, `API-FAC`, `API-HOLD`, `API-BOOK`, `API-OWN`, `API-NTF`, `API-MOD`).
- **Kết quả tự kiểm tra:**
  - [x] Bao phủ đủ các nhóm giao tiếp: xác thực/RBAC, tìm kiếm/lịch sân, hold/booking/hủy, quản lý chủ sân 24h/đặt tại quầy, thông báo In-app và giao tiếp giữa các module.
  - [x] Làm rõ đồng bộ `serverNow` / `expiresAt` khi F5 (`FR-25`), `Idempotency-Key` chống tạo trùng khi retry, và 3 trạng thái `Releasing` / `ReleaseFailed` / `Released` (`UI-07`, `STM-01`, `SEQ-02B`).
  - [x] Khớp bảng chữ ký đề xuất với `class-design.md` (PR `#31`) và `sequence-diagrams.md` (PR `#27`).
- **Điểm cần người kiểm tra xác nhận:**
  - `@nmt1206` (Trí): xác nhận validation, kiểm tra quyền, mã lỗi nghiệp vụ và độ khớp với `SEQ-01..05` (`#19`), `STM-01..03` (`#20`) và baseline PA2.
