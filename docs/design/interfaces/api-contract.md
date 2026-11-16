# Đặc tả Giao tiếp Frontend–Backend và Giữa các Module (Task 3.1.4 — Issue #12)

- **Mã đối tượng truy vết:** `API-01` (Quy ước chung, Idempotency & Ánh xạ lỗi), `API-AUTH` (Xác thực & Phân quyền), `API-FAC` (Tìm kiếm & Lịch sân), `API-HOLD` (Giữ chỗ 5 phút & Giải phóng), `API-BOOK` (Xác nhận, Lịch sử & Hủy đơn), `API-OWN` (Quản lý chủ sân, Đặt tại quầy 2 bước & Thay đổi lịch 24h), `API-NTF` (Thông báo In-app), `API-MOD` (Giao tiếp nội bộ giữa các Module)
- **Người thực hiện:** Lý Sĩ Vĩ (`@Lysivi2005` — tiếp nhận tạm thời theo chuyển giao ngày 15/11/2026)
- **Người kiểm tra:** Trí (`@nmt1206` — đối chiếu hợp đồng API với schema `#33`, sơ đồ trình tự `#27`, `STM-01..03` `#28` và baseline PA2)
- **Tài liệu đối chiếu:** Baseline PA2, `3.1.1` (`architecture-design.md`), `3.1.2` (`schema.sql` — PR `#33` commit `a2e1b72`), `3.2.1` (`ui-design-specification.md` — PR `#29`), `3.3.2` (`class-design.md` — PR `#31`), `3.3.3` (`sequence-diagrams.md` — PR `#27`), `3.3.4` (`state-machines.md` — PR `#28`)

---

## 1. [`API-01`] Quy ước chung, Thời gian Server, Idempotency & Ánh xạ lỗi

### 1.1. Chuẩn giao tiếp, Kiểu ID & Bảo mật
- **Giao thức:** RESTful JSON qua HTTPS, Base URL `/api/v1`.
- **Kiểu định danh (đồng bộ `#33`):** Mọi khóa chính (`userId`, `facilityId`, `courtId`, `holdId`, `bookingId`, `notificationId`, `expectedBookingIds[]`) dùng kiểu **`bigint`** (số nguyên dương 64-bit, tương ứng `GENERATED ALWAYS AS IDENTITY` trong `schema.sql`).
- **Vai trò người dùng (đồng bộ `#33`):** Enum **`"PLAYER" | "FACILITY_OWNER"`**.
- **Xác thực:** `Authorization: Bearer <jwt>` cho mọi endpoint yêu cầu đăng nhập; `Auth & RBAC Middleware` kiểm tra JWT và vai trò trước khi vào Controller (`NFR-04`).
- **Định dạng thời gian:** ISO-8601 UTC (`YYYY-MM-DDTHH:mm:ss.sssZ`).
- **Khung lỗi thống nhất (luôn kèm `serverNow`):**

```json
{
  "error": {
    "code": "SLOT_CONFLICT",
    "message": "Một hoặc nhiều khung giờ đã được giữ hoặc đặt trước.",
    "details": {
      "conflictedSlots": [
        { "courtId": 1, "startTime": "2026-11-17T18:00:00.000Z" }
      ]
    },
    "serverNow": "2026-11-16T11:00:00.000Z"
  }
}
```

### 1.2. Đồng bộ thời gian Server, Bảo toàn Hold khi F5 & Chống gửi lặp (Idempotency)
1. **Nguồn chân lý thời gian (`serverNow`, `expiresAt`):**
   - Backend tính `expiresAt = createdAt + 5 phút` theo đồng hồ server và lưu cố định trong DB (`hold.expires_at`).
   - Mọi phản hồi liên quan tới Hold đều trả cặp `{ "expiresAt": "...", "serverNow": "..." }`. Frontend tính độ lệch `offset = serverNow - clientNow` để đếm ngược, **không tự tính hoặc gia hạn 5 phút** (`FR-25`, `FR-31`).
2. **Bảo toàn khi tải lại trang (F5):**
   - Frontend **không** gọi API nhả chỗ trong `beforeunload` / `pagehide`. Khi F5 vào `UI-07`, client gọi `GET /api/v1/holds/active` để khôi phục `holdId`, danh sách slot, `expiresAt` và `serverNow` (`FR-25`, `AC-22`).
3. **Đặc tả gửi lại yêu cầu sau mất kết nối (`Idempotency-Key`):**
   - Áp dụng cho các thao tác ghi tạo/thay đổi trạng thái quan trọng: `POST /holds`, `POST /holds/:holdId/confirm`, `POST /owner/facilities/:facilityId/direct-holds`, `POST /owner/facilities/:facilityId/direct-holds/:holdId/confirm`, `POST /owner/facilities/:facilityId/schedule-changes/apply`.
   - **Phạm vi khóa:** `(userId, method, path, idempotencyKey)` (header `Idempotency-Key: <uuid-v4>`), lưu kèm `requestHash`, `status` (`IN_PROGRESS | COMPLETED`), `httpStatus` và `responseBody` trong bộ lưu trữ idempotency (bảng `idempotency_record` / cache TTL tối thiểu **24 giờ**).
   - **Hành vi khi nhận lại request:**
     - *Cùng key + cùng `requestHash` + đã `COMPLETED`:* trả lại đúng `httpStatus` và `responseBody` của lần đầu, **không** chạy lại giao dịch. Ví dụ: lần đầu `POST /holds/:holdId/confirm` đã commit tạo `bookingId = 201` nhưng client mất mạng không nhận được phản hồi; khi client gửi lại cùng `Idempotency-Key`, server trả lại `201` với đúng `bookingId = 201` và DB vẫn chỉ có **1 booking duy nhất**.
     - *Cùng key + khác `requestHash`:* từ chối ngay với `422 IDEMPOTENCY_KEY_REUSED`.
     - *Cùng key + đang `IN_PROGRESS`:* trả `409 IDEMPOTENCY_IN_FLIGHT` để client chờ rồi retry, tránh chạy song song hai luồng.

### 1.3. Bảng ánh xạ lỗi từ tầng nghiệp vụ (`3.3.2` / `#31`) sang HTTP (`#34`) & UI

| Kết quả nghiệp vụ (`3.3.2` — `#31`) | HTTP Status | Mã lỗi API (`error.code`) | Dữ liệu `details` & Hành vi UI |
|---|---|---|---|
| `SelectionInvalid(NOT_SINGLE_FACILITY \| INVALID_SEQUENCE \| OUTSIDE_HOURS \| TOO_LATE_60M \| COURT_INACTIVE)` | `422` | `SELECTION_INVALID` | `{ reason }`: UI giữ lựa chọn hoặc nhắc chọn lại đúng quy tắc 30 phút / $\ge 60$ phút. |
| `SelectionInvalid(SLOT_CONFLICT)` / `ConfirmRejected(SLOTS_INVALID)` | `409` | `SLOT_CONFLICT` | `{ conflictedSlots: [{ courtId, startTime }] }`: UI báo rõ khung xung đột, xóa chọn và làm mới ma trận (`UI-06`). |
| `ConfirmRejected(HOLD_NOT_FOUND)` / `ReleaseFailed(HOLD_NOT_FOUND)` | `404` | `HOLD_NOT_FOUND` | Thông báo lượt giữ không tồn tại. |
| `ConfirmRejected(NOT_OWNER)` / `ReleaseFailed(NOT_OWNER)` / `CancelNotAllowed(NOT_OWNER)` / `NotOwner` | `403` | `NOT_OWNER` / `NOT_FACILITY_OWNER` | Từ chối truy cập ngoài quyền sở hữu (`NFR-04`). |
| `ConfirmRejected(HOLD_EXPIRED)` | `409` | `HOLD_EXPIRED` | `{ holdId, expiresAt, serverNow }`: từ chối ngay, giữ nguyên bảng `booking`, khóa nút Xác nhận (`AC-35`). |
| `ReleaseFailed(RELEASE_ERROR)` | `503` | `RELEASE_FAILED` | `{ holdId, status: "EXPIRED", releaseState: "ReleaseFailed", expiresAt, serverNow }`: UI giữ nguyên màn hình và báo lỗi (`FR-14`). |
| `CancelNotAllowed(BOOKING_NOT_FOUND)` | `404` | `BOOKING_NOT_FOUND` | Thông báo không tìm thấy đơn đặt. |
| `CancelNotAllowed(UNDER_3_HOURS)` | `422` | `CANCEL_DEADLINE_PASSED` | `{ earliestStartTime, serverNow }`: từ chối hủy vì còn $< 3$ giờ (`BR-09`). |
| `CancelNotAllowed(INVALID_STATE)` | `409` | `BOOKING_INVALID_STATE` | `{ currentStatus }` (ví dụ `CANCELLED_BY_PLAYER`, `CANCELLED_BY_OWNER`, hoặc đã qua giờ sử dụng). |

---

## 2. Danh mục Endpoint & Hợp đồng chi tiết

### 2.1. [`API-AUTH`] Xác thực & Phân quyền (`UI-03`, `UI-04`, `UI-05`)

- **Đồng bộ `app_user` (`#33`):** Tách riêng `email` (định danh đăng nhập, `NOT NULL UNIQUE`) và `phone` (`NOT NULL UNIQUE`, $\ge 8$ ký tự); `role` là `"PLAYER" | "FACILITY_OWNER"`.

| Method & Endpoint | Quyền | Request / Validation | Response `200/201` | Lỗi nghiệp vụ |
|---|---|---|---|---|
| `POST /auth/register` | Public | `{ name, email, phone, password, role: "PLAYER" \| "FACILITY_OWNER" }` (`password` $\ge 8$ ký tự, băm bcrypt/argon2, `NFR-05`) | `201`: `{ user: { id, name, email, phone, role } }` | `409 EMAIL_OR_PHONE_EXISTS`, `400 VALIDATION_ERROR` |
| `POST /auth/login` | Public | `{ email, password }` | `200`: `{ accessToken, user: { id, name, email, phone, role } }` | `401 INVALID_CREDENTIALS` |
| `GET /auth/me` | `PLAYER`, `FACILITY_OWNER` | Header JWT | `200`: `{ id, name, email, phone, role }` | `401 UNAUTHORIZED` |

---

### 2.2. [`API-FAC`] Tìm kiếm Cơ sở & Xem Lịch trống (`UI-01`, `UI-02`, `UI-06`)

| Method & Endpoint | Quyền | Request / Query | Response `200` | Lỗi nghiệp vụ |
|---|---|---|---|---|
| `GET /facilities` | Public | `?sportId=&district=&keyword=&amenityIds=&page=&limit=` | `{ items: [{ id, name, address, district, sportId, minPrice, openTime, closeTime }], total }` | `400 VALIDATION_ERROR` |
| `GET /facilities/:facilityId` | Public | Path `facilityId: bigint` | `{ id, name, address, district, description, sportId, amenities, operatingHours, courts: [{ id, name, status, currentPricePerSlot }] }` | `404 FACILITY_NOT_FOUND` |
| `GET /facilities/:facilityId/schedule` | Public | `?date=YYYY-MM-DD` (mỗi slot chia chuẩn 30 phút, `BR-03`) | `{ date, serverNow, courts: [{ courtId, courtName, slots: [{ startTime, endTime, status: "AVAILABLE" \| "HELD" \| "BOOKED" \| "BLOCKED", price }] }] }` | `404 FACILITY_NOT_FOUND`, `400 INVALID_DATE` |

*(Ghi chú giá hiển thị từ `court_price` `#33`: mỗi slot dùng đơn giá có `effective_from <= slot.startTime` mới nhất; khi tạo Hold, đơn giá được chụp vào `schedule_entry.unit_price` để `totalPrice` không bị biến động trong 5 phút giữ chỗ.)*

---

### 2.3. [`API-HOLD`] Giữ chỗ 5 phút & Giải phóng (`UI-06`, `UI-07`, `SEQ-01`, `SEQ-02B`, `STM-01`)

#### A. Tạo lượt giữ chỗ (`POST /holds`)
- **Ánh xạ lớp (`3.3.2`):** `BookingService.createHold(userId, actorRole, facilityId, selections, isDirect = false)`
- **Quyền:** `PLAYER`, `FACILITY_OWNER` (luồng đặt thường qua app, `source = 'APP'`, `isDirect = false`).
- **Headers:** `Authorization: Bearer <jwt>`, `Idempotency-Key: <uuid-v4>`
- **Request Body:**
```json
{
  "facilityId": 12,
  "selections": [
    {
      "courtId": 1,
      "slotStartTimes": [
        "2026-11-17T18:00:00.000Z",
        "2026-11-17T18:30:00.000Z"
      ]
    }
  ]
}
```
- **Response `201 Created`:**
```json
{
  "holdId": 101,
  "facilityId": 12,
  "source": "APP",
  "isDirect": false,
  "status": "ACTIVE",
  "releaseState": "None",
  "totalPrice": 160000,
  "expiresAt": "2026-11-16T11:05:00.000Z",
  "serverNow": "2026-11-16T11:00:00.000Z",
  "items": [
    { "courtId": 1, "startTime": "2026-11-17T18:00:00.000Z", "endTime": "2026-11-17T18:30:00.000Z", "price": 80000 },
    { "courtId": 1, "startTime": "2026-11-17T18:30:00.000Z", "endTime": "2026-11-17T19:00:00.000Z", "price": 80000 }
  ]
}
```

#### B. Khôi phục khi F5 (`GET /holds/active`) & Kiểm tra theo đúng `holdId` (`GET /holds/:holdId`)
- **Các cặp trạng thái hợp lệ (đồng bộ `STM-01` & `#33`):**
  - `status: "ACTIVE"` $\rightarrow$ `releaseState: "None"` (`serverNow < expiresAt`)
  - `status: "EXPIRED"` $\rightarrow$ `releaseState: "Releasing"` (chưa nhả xong & `release_failed_at IS NULL`) hoặc `"ReleaseFailed"` (`release_failed_at IS NOT NULL` hoặc quá 5s)
  - `status: "RELEASED"` $\rightarrow$ `releaseState: "Released"`
  - `status: "CONFIRMED"` $\rightarrow$ `releaseState: "None"`
- **`GET /holds/active` (tùy chọn `?holdId=...`):** Khi F5 chưa giữ `holdId`, trả `{ "activeHold": <HoldObject | null>, "serverNow": "..." }` (trong `HoldObject` luôn có `isDirect: true | false` suy ra từ `hold.source === 'IN_PERSON'` để khôi phục đúng ngữ cảnh đặt tại quầy nếu F5 giữa 2 bước `UC-13`). Nếu truyền `?holdId=...`, trả trạng thái của đúng `holdId` đó.
- **`GET /holds/:holdId`:** Endpoint chuyên biệt khi `UI-07` **đã có `holdId`** (ví dụ sau `202 Releasing` hoặc `ReleaseFailed`) để hỏi trạng thái của đúng `holdId` đó, bảo đảm **không trả nhầm lượt giữ ở tab khác**:
  ```json
  {
    "holdId": 101,
    "status": "EXPIRED",
    "releaseState": "Releasing",
    "expiresAt": "2026-11-16T11:05:00.000Z",
    "serverNow": "2026-11-16T11:05:02.000Z"
  }
  ```

#### C. Nhả lượt giữ chỗ (`POST /holds/:holdId/release`)
- **Ánh xạ lớp (`3.3.2`):** `BookingService.releaseHold(userId, holdId)`
- **Quyền:** `PLAYER`, `FACILITY_OWNER` (`hold.user_id === userId`).
- **Response `200 OK` (`Released`):**
```json
{
  "holdId": 101,
  "status": "RELEASED",
  "releaseState": "Released",
  "expiresAt": "2026-11-16T11:05:00.000Z",
  "serverNow": "2026-11-16T11:02:10.000Z"
}
```
- **Phản hồi khi đang xử lý hoặc nhả lỗi (đồng bộ `UI-07`, `STM-01`, `SEQ-02B`):**
  - `202 Accepted`: `{ "holdId": 101, "status": "EXPIRED", "releaseState": "Releasing", "expiresAt": "2026-11-16T11:05:00.000Z", "serverNow": "..." }` $\rightarrow$ `UI-07` **tiếp tục chờ** và poll `GET /holds/101`, chưa cho quay về `UI-06`.
  - `503 Service Unavailable`:
    ```json
    {
      "error": {
        "code": "RELEASE_FAILED",
        "message": "Chưa giải phóng được khung giờ.",
        "details": { "holdId": 101, "status": "EXPIRED", "releaseState": "ReleaseFailed" },
        "serverNow": "2026-11-16T11:05:06.000Z"
      }
    }
    ```
    $\rightarrow$ `UI-07` **báo lỗi và giữ nguyên màn hình**, chỉ cho quay về `UI-06` khi nhận `Released` (`FR-14`, `AC-20`).

---

### 2.4. [`API-BOOK`] Xác nhận, Chi tiết & Hủy đơn (`UI-07`, `UI-08`, `UI-09`, `UI-10`, `SEQ-02`, `SEQ-03`)

- **`POST /holds/:holdId/confirm`** (`Idempotency-Key`): Gọi `BookingService.confirmBooking(userId, holdId, isDirect = false)`. Kiểm tra quyền sở hữu, `status === ACTIVE` và `serverNow < expiresAt`; tự động xác nhận (`CONFIRMED`), trả `201`: `{ bookingId, holdId, source: "APP", status: "CONFIRMED", totalPrice, earliestStartTime, createdAt }`. Nếu hết hạn trả `409 HOLD_EXPIRED`, dữ liệu `booking` giữ nguyên (`FR-11`, `AC-35`).
- **`GET /bookings`, `GET /bookings/:bookingId`**: Trả `status` kèm `latestEndTime` và `serverNow`; khi `status === "CONFIRMED"` và `serverNow >= latestEndTime`, UI suy diễn nhãn *"Đã hoàn thành"* (`STM-03`, `UI-09`).
- **`POST /bookings/:bookingId/cancel`**: Gọi `BookingService.cancelBookingByPlayer(userId, bookingId, reason?)`. Body `{ "reason": "..." }` (`reason` là **tùy chọn**). Kiểm tra `earliestStartTime - serverNow >= 3 giờ` (`BR-09`), hủy toàn bộ đơn (`CANCELLED_BY_PLAYER`).

---

### 2.5. [`API-OWN`] Quản lý Chủ sân, Đặt tại quầy 2 bước & Thay đổi lịch 24h (`UI-14`, `UI-15`, `SEQ-04`, `SEQ-05`)

*(Mọi endpoint nhóm `/owner/*` yêu cầu vai trò `FACILITY_OWNER` và kiểm tra `facility.owner_id === userId` tại Backend, `FR-03`, `NFR-04`.)*

1. **Tạo & Sửa thông tin cơ sở / sân / giá (`UC-09`, `UC-10`, `FR-17`, `FR-19`):**
   - `POST /owner/facilities`: Tạo cơ sở mới + giờ mở cửa + sân con + giá khởi điểm.
   - `PATCH /owner/facilities/:facilityId`: Sửa `name`, `address`, `district`, `description`, `amenityIds` (`403 NOT_FACILITY_OWNER`, `400 VALIDATION_ERROR`).
   - `POST /owner/facilities/:facilityId/courts` & `PATCH /owner/facilities/:facilityId/courts/:courtId`: Thêm sân mới hoặc đổi `name` sân (xóa sân và đổi `operating_hours` bắt buộc qua luồng preview/apply 24h của `UC-12`).
   - `PUT /owner/facilities/:facilityId/courts/:courtId/price`: Cập nhật giá mới `{ "amountPerSlot": 90000, "effectiveFrom": "2026-11-18T00:00:00.000Z" }` ghi vào `court_price(court_id, effective_from, amount_per_slot)` (`#33`). Nếu `amountPerSlot < 0` hoặc `effectiveFrom` không hợp lệ trả `400 VALIDATION_ERROR`. Khi đọc lại lịch (`GET /facilities/:id/schedule`), server lấy mức giá có `effective_from <= slot.startTime` mới nhất.

2. **Đặt tại quầy 2 bước riêng (`UC-13`, `FR-21`, `SEQ-05`, `UI-15`):**
   - **Bước 1 — Tạo Hold tại quầy (`POST /owner/facilities/:facilityId/direct-holds` + `Idempotency-Key`):**
     - `OwnerScheduleService` kiểm tra `Facility.isOwnedBy(ownerId)`, rồi gọi `BookingService.createHold(ownerId, "FACILITY_OWNER", facilityId, selections, isDirect = true)`.
     - Lưu `hold` với `source = 'IN_PERSON'` (`#33`), **miễn mốc 60 phút** (`AC-25`, đặt trước 30 phút vẫn hợp lệ) nhưng không đè Hold/Booking/Block hiện có.
     - Trả `201`: `{ holdId, facilityId, source: "IN_PERSON", isDirect: true, status: "ACTIVE", totalPrice, expiresAt, serverNow, items }`.
   - **Bước 2 — Xác nhận đặt tại quầy (`POST /owner/facilities/:facilityId/direct-holds/:holdId/confirm` + `Idempotency-Key`):**
     - `OwnerScheduleService` kiểm tra quyền sở hữu và đọc `hold.source === 'IN_PERSON'` (giữ ngữ cảnh `isDirect = true` qua hai bước), gọi `BookingService.confirmBooking(ownerId, holdId, true)`.
     - Trả `201`: `{ bookingId, holdId, source: "IN_PERSON", status: "CONFIRMED", totalPrice, createdAt }`. Nếu bấm xác nhận sau khi hết hạn trả `409 HOLD_EXPIRED`.

3. **Thay đổi lịch $\ge 24\text{h}$ (`UC-11`, `UC-12`, `SEQ-04`, `UI-14`):**
   - `POST /owner/facilities/:facilityId/schedule-changes/preview`: `change = { type: "BLOCK" | "OPERATING_HOURS" | "DELETE_COURT", courtId?, startTime?, endTime?, operatingHours?, reason? }`.
   - `POST /owner/facilities/:facilityId/schedule-changes/apply` (`Idempotency-Key`): nhận `{ change, expectedBookingIds: bigint[] }`.
   - **Cấu trúc dùng chung** cho cả response `200` của `preview` và lỗi `409 AFFECTED_BOOKINGS_CHANGED` của `apply` (hiển thị đủ từng sân/khung giờ bị ảnh hưởng trên `UI-14`):
     ```json
     {
       "affectedBookings": [
         {
           "bookingId": 201,
           "playerId": 45,
           "playerName": "Nguyễn Văn A",
           "earliestStartTime": "2026-11-18T18:00:00.000Z",
           "totalPrice": 160000,
           "affectedSlots": [
             { "courtId": 1, "courtName": "Sân 1", "startTime": "2026-11-18T18:00:00.000Z", "endTime": "2026-11-18T18:30:00.000Z" }
           ]
         }
       ],
       "expectedBookingIds": [201],
       "serverNow": "2026-11-16T15:00:00.000Z"
     }
     ```
   - Nếu trong lúc chủ sân xác nhận có **thêm hoặc bớt** đơn so với `expectedBookingIds`, `apply` trả `409 AFFECTED_BOOKINGS_CHANGED` với danh sách mới trên để `UI-14` hiển thị lại và gửi lại `expectedBookingIds` mới khi xác nhận lần nữa.

---

### 2.6. [`API-NTF`] Thông báo In-app (`UI-15`, `FR-30`, đồng bộ `#33`)

- **Quyết định đồng bộ với `schema.sql` (`#33` commit `a2e1b72`):** Bảng `notification` trong `#33` có đủ `id`, `user_id`, `booking_id`, `reason` (`BLOCKED_PERIOD | HOURS_CHANGED | COURT_DELETED`), `message`, `is_read`, `created_at` nên API giữ nguyên `unreadOnly`, `isRead`, `unreadCount` và `PATCH /notifications/:notificationId/read`.
- **`GET /notifications?unreadOnly=true|false&page=&limit=`:** Trả đủ thông tin hủy bắt buộc của `FR-30` (kể cả khi chỉ một phần của đơn nhiều sân bị tác động):
  ```json
  {
    "items": [
      {
        "id": 501,
        "bookingId": 201,
        "reason": "BLOCKED_PERIOD",
        "message": "Chủ sân bảo trì Sân 1.",
        "isRead": false,
        "createdAt": "2026-11-16T15:01:00.000Z",
        "affectedSummary": {
          "facilityName": "Sân Cầu Lông T04",
          "affectedItems": [
            { "courtId": 1, "courtName": "Sân 1", "startTime": "2026-11-18T18:00:00.000Z", "endTime": "2026-11-18T18:30:00.000Z" }
          ]
        }
      }
    ],
    "unreadCount": 1
  }
  ```
- **`PATCH /notifications/:notificationId/read`:** Kiểm tra `notification.user_id === userId`, trả `200`: `{ "id": 501, "isRead": true }`.

---

## 3. [`API-MOD`] Hợp đồng Giao tiếp Giữa các Module Backend

| Module gọi | Module nhận | Thao tác & Tham số | Ghi chú đồng bộ |
|---|---|---|---|
| `BookingController` | `BookingService` | `createHold(userId, actorRole, facilityId, selections, isDirect = false)` | Tạo Hold 5 phút All-or-Nothing (`SEQ-01`). |
| `BookingController` | `BookingService` | `confirmBooking(userId, holdId, isDirect = false)` | Recheck quyền, `now < expiresAt`, tạo `Booking` (`SEQ-02`). |
| `BookingController` | `BookingService` | `releaseHold(userId, holdId)` | Nhả Hold thủ công; trả `Releasing` / `ReleaseFailed` / `Released` (`SEQ-02B`). |
| `BookingController` | `BookingService` | `cancelBookingByPlayer(userId, bookingId, reason?)` | Hủy toàn bộ đơn $\ge 3\text{h}$ (`SEQ-03`). |
| `Hold Expiry Worker` (`ReleaseJob`) | `BookingService` | `releaseExpiredHolds(now)` | Chạy trong tiến trình Express, cập nhật Hold hết hạn `EXPIRED -> RELEASED`; thử lại ở chu kỳ sau nếu lỗi (`3.1.1`, `NFR-03`). |
| `OwnerController` | `OwnerScheduleService` | `createDirectHold(ownerId, facilityId, selections)` & `confirmDirectHold(ownerId, facilityId, holdId)` | Xác minh `Facility.isOwnedBy(ownerId)`, giữ `source = 'IN_PERSON'` (`isDirect = true`) qua 2 bước (`AC-25`, `SEQ-05`). |
| `OwnerController` | `OwnerScheduleService` | `previewScheduleChange(...)` / `applyScheduleChange(ownerId, change, expectedBookingIds, now)` | Kiểm tra Hold ảnh hưởng + mốc 24h; so sánh tập `expectedBookingIds` (`SEQ-04`). |
| `OwnerScheduleService` | `In-App Notification Module` | `createCancellationNotifications(bookings, reason)` | Tạo bản ghi `Notification` trong cùng Transaction khi hủy đơn $\ge 24\text{h}$ (`FR-30`). |

---

## 4. Thông tin gửi kèm Review (Theo Working Agreement Mục 5.3)

- **Danh sách sản phẩm:** `docs/design/interfaces/api-contract.md` (Mã đối tượng: `API-01`, `API-AUTH`, `API-FAC`, `API-HOLD`, `API-BOOK`, `API-OWN`, `API-NTF`, `API-MOD`).
- **Kết quả tự kiểm tra:**
  - [x] Đồng bộ kiểu `bigint`, vai trò `FACILITY_OWNER`, `email`/`phone`, `court_price.effective_from`, `hold.source = 'IN_PERSON'` và `notification.is_read` với `schema.sql` (`#33` commit `a2e1b72`).
  - [x] Làm rõ phạm vi & xử lý `Idempotency-Key`, `GET /holds/:holdId` theo đúng `holdId`, cặp trạng thái hợp lệ (`Releasing`/`ReleaseFailed`/`Released`), và bảng ánh xạ lỗi `#31` → `#34`.
  - [x] Bổ sung API sửa cơ sở/sân (`UC-09`), cập nhật giá (`UC-10`), tách 2 bước đặt tại quầy (`UC-13`), và chi tiết `affectedItems` cho `UC-11/12` & `FR-30`.
- **Điểm cần người kiểm tra xác nhận:**
  - `@nmt1206` (Trí) & `@buikhoa130406` (Khoa): xác nhận bản cập nhật đã xử lý đủ 8 góp ý trên PR `#34` và khớp hoàn toàn với `schema.sql` (`#33`), `SEQ` (`#27`), `STM` (`#28`) và `class-design.md` (`#31`).
