# Từ điển dữ liệu (`data-dictionary.md` — Task 3.1.2)

- **Nguồn DDL:** `docs/design/data/schema.sql` (PostgreSQL 16)
- **Quy ước:** Mọi khóa chính/khóa ngoại nội bộ dùng kiểu `bigint` (số nguyên 64-bit). Trên hợp đồng API `#34`, các khóa `bigint` được truyền dưới dạng chuỗi số nguyên dương (`string`, ví dụ `"101"`). Thời gian lưu ở dạng `timestamptz` (UTC).

---

## `DB-TBL-01`: `app_user`
- **Mục đích:** Lưu tài khoản người chơi và chủ sân.
- **Liên kết:** `CLS-01`, `API-AUTH` | **Yêu cầu:** `FR-01`, `FR-24`, `NFR-05`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK` | Định danh duy nhất của người dùng |
| `name` | `text` | NOT NULL | — | — | Họ tên hiển thị |
| `email` | `text` | NOT NULL | — | `UQ` | Email đăng nhập chính |
| `phone` | `text` | NOT NULL | — | `UQ` | Số điện thoại liên hệ |
| `password_hash` | `text` | NOT NULL | — | — | Chuỗi băm mật khẩu |
| `role` | `user_role` | NOT NULL | — | — | Vai trò (`PLAYER` hoặc `FACILITY_OWNER`) |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm tạo tài khoản |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `UQ (email)`, `UQ (phone)`, `CHECK` không rỗng trên `name`, `email`, `phone`, `password_hash`.

---

## `DB-TBL-02`: `sport`
- **Mục đích:** Danh mục môn thể thao của cơ sở.
- **Yêu cầu:** `FR-04`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK` | Định danh môn thể thao |
| `name` | `text` | NOT NULL | — | `UQ` | Tên môn thể thao |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `UQ (name)`, `CHECK (btrim(name) <> '')`.

---

## `DB-TBL-03`: `amenity`
- **Mục đích:** Danh mục tiện ích đi kèm tại cơ sở.
- **Yêu cầu:** `FR-05`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK` | Định danh tiện ích |
| `name` | `text` | NOT NULL | — | `UQ` | Tên tiện ích |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `UQ (name)`, `CHECK (btrim(name) <> '')`.

---

## `DB-TBL-04`: `facility`
- **Mục đích:** Thông tin cơ sở thể thao thuộc sở hữu của một chủ sân.
- **Yêu cầu:** `FR-03`, `FR-04`, `BR-10`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK` | Định danh cơ sở |
| `owner_id` | `bigint` | NOT NULL | — | `FK` | Tham chiếu `app_user.id` (chủ cơ sở) |
| `sport_id` | `bigint` | NOT NULL | — | `FK` | Tham chiếu `sport.id` (môn thể thao phục vụ) |
| `name` | `text` | NOT NULL | — | — | Tên cơ sở |
| `address` | `text` | NOT NULL | — | — | Địa chỉ chi tiết |
| `district` | `text` | NOT NULL | — | — | Quận/huyện phục vụ lọc khu vực |
| `description` | `text` | NULL | — | — | Mô tả bổ sung |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm tạo cơ sở |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `FK (owner_id) -> app_user(id) ON DELETE RESTRICT`, `FK (sport_id) -> sport(id) ON DELETE RESTRICT`, `CHECK` không rỗng trên `name`, `address`, `district`; chỉ mục `facility_owner_idx (owner_id)` và `facility_sport_area_idx (sport_id, district)`.

---

## `DB-TBL-05`: `facility_amenity`
- **Mục đích:** Bảng liên kết nhiều-nhiều giữa cơ sở và tiện ích.
- **Yêu cầu:** `FR-05`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `facility_id` | `bigint` | NOT NULL | — | `PK, FK` | Tham chiếu `facility.id` |
| `amenity_id` | `bigint` | NOT NULL | — | `PK, FK` | Tham chiếu `amenity.id` |

- **Ràng buộc & Chỉ mục:** `PK (facility_id, amenity_id)`, `FK (facility_id) -> facility(id) ON DELETE CASCADE`, `FK (amenity_id) -> amenity(id) ON DELETE RESTRICT`; chỉ mục `facility_amenity_rev_idx (amenity_id, facility_id)`.

---

## `DB-TBL-06`: `operating_hours`
- **Mục đích:** Khung giờ mở cửa và đóng cửa theo từng ngày trong tuần của cơ sở.
- **Yêu cầu:** `FR-18`, `FR-32`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `facility_id` | `bigint` | NOT NULL | — | `PK, FK` | Tham chiếu `facility.id` |
| `day_of_week` | `smallint` | NOT NULL | — | `PK` | Thứ trong tuần (`1` = Thứ Hai .. `7` = Chủ Nhật) |
| `open_time` | `time` | NOT NULL | — | — | Giờ mở cửa (giờ địa phương Asia/Ho_Chi_Minh) |
| `close_time` | `time` | NOT NULL | — | — | Giờ đóng cửa (`close_time > open_time`) |

- **Ràng buộc & Chỉ mục:** `PK (facility_id, day_of_week)`, `FK (facility_id) -> facility(id) ON DELETE CASCADE`, `CHECK (day_of_week BETWEEN 1 AND 7)`, `CHECK (close_time > open_time)`.

---

## `DB-TBL-07`: `court`
- **Mục đích:** Danh sách sân con thuộc cơ sở, hỗ trợ xóa mềm để bảo toàn lịch sử.
- **Liên kết:** `CLS-06` | **Yêu cầu:** `FR-16`, `DM-INV-07`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK, UQ` | Định danh sân (`UNIQUE (id, facility_id)`) |
| `facility_id` | `bigint` | NOT NULL | — | `FK, UQ` | Tham chiếu `facility.id` |
| `name` | `text` | NOT NULL | — | `UQ` | Tên sân (duy nhất trong cùng cơ sở) |
| `status` | `court_status` | NOT NULL | `'ACTIVE'` | — | Trạng thái (`ACTIVE` hoặc `DELETED`) |
| `deleted_at` | `timestamptz` | NULL | — | — | Thời điểm xóa mềm (`NOT NULL` khi `DELETED`) |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm tạo sân |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `UQ (id, facility_id)`, `UQ (facility_id, name)`, `FK (facility_id) -> facility(id) ON DELETE RESTRICT`, `CHECK ((status = 'ACTIVE' AND deleted_at IS NULL) OR (status = 'DELETED' AND deleted_at IS NOT NULL))`; chỉ mục `court_facility_active_idx (facility_id) WHERE status = 'ACTIVE'`.

---

## `DB-TBL-08`: `court_price`
- **Mục đích:** Lưu lịch sử bảng giá mỗi slot 30 phút theo thời điểm hiệu lực.
- **Yêu cầu:** `FR-07`, `FR-19`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `court_id` | `bigint` | NOT NULL | — | `PK, FK` | Tham chiếu `court.id` |
| `effective_from` | `timestamptz` | NOT NULL | — | `PK` | Thời điểm mức giá bắt đầu có hiệu lực |
| `amount_per_slot` | `numeric(12,2)` | NOT NULL | — | — | Đơn giá cho 1 slot 30 phút (`>= 0`) |

- **Ràng buộc & Chỉ mục:** `PK (court_id, effective_from)`, `FK (court_id) -> court(id) ON DELETE RESTRICT`, `CHECK (amount_per_slot >= 0)`.

---

## `DB-TBL-09`: `hold`
- **Mục đích:** Lưu lượt giữ chỗ tạm thời 5 phút của người dùng tại một cơ sở.
- **Liên kết:** `CLS-03` | **Yêu cầu:** `BR-01`, `BR-07`, `FR-14`, `FR-21`, `FR-25`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK, UQ` | Định danh lượt giữ chỗ |
| `user_id` | `bigint` | NOT NULL | — | `FK` | Người tạo giữ chỗ (`UNIQUE` từng phần khi `ACTIVE`) |
| `facility_id` | `bigint` | NOT NULL | — | `FK, UQ` | Cơ sở đặt sân |
| `source` | `booking_source` | NOT NULL | `'APP'` | `UQ` | Nguồn đặt (`APP` hoặc `IN_PERSON`) |
| `status` | `hold_status` | NOT NULL | `'ACTIVE'` | — | Trạng thái (`ACTIVE`, `CONFIRMED`, `RELEASED`, `EXPIRED`) |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm tạo giữ chỗ |
| `expires_at` | `timestamptz` | NOT NULL | `now() + 5m` | — | Thời điểm hết hạn (`= created_at + 5 phút`) |
| `released_at` | `timestamptz` | NULL | — | — | Thời điểm hoàn tất nhả chỗ (`NOT NULL` khi `RELEASED`) |
| `release_failed_at` | `timestamptz` | NULL | — | — | Thời điểm ghi nhận lỗi nhả chỗ (`NOT NULL` chỉ hợp lệ khi `EXPIRED`) |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `UQ (id, facility_id)`, `UQ (id, facility_id, source)`, `FK (user_id) -> app_user(id) ON DELETE RESTRICT`, `FK (facility_id) -> facility(id) ON DELETE RESTRICT`, `CHECK (expires_at = created_at + interval '5 minutes')`, `CHECK ((status = 'RELEASED' AND released_at IS NOT NULL) OR (status <> 'RELEASED' AND released_at IS NULL))`, `CHECK (release_failed_at IS NULL OR status = 'EXPIRED')`; chỉ mục `hold_user_active_idx (user_id) WHERE status = 'ACTIVE'`, `hold_expiry_idx (expires_at) WHERE status = 'ACTIVE'`, `hold_release_retry_idx (expires_at) WHERE status = 'EXPIRED'`.

---

## `DB-TBL-10`: `booking`
- **Mục đích:** Lưu đơn đặt sân đã xác nhận từ một lượt giữ chỗ.
- **Liên kết:** `CLS-05` | **Yêu cầu:** `BR-06`, `FR-21`, `FR-28`, `FR-30`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK, UQ` | Định danh đơn đặt sân |
| `hold_id` | `bigint` | NOT NULL | — | `UQ, FK` | Lượt giữ chỗ gốc (`1-1` với `hold`) |
| `user_id` | `bigint` | NOT NULL | — | `FK` | Người đặt sân |
| `facility_id` | `bigint` | NOT NULL | — | `FK, UQ` | Cơ sở đặt sân (kế thừa từ `hold`) |
| `source` | `booking_source` | NOT NULL | — | `FK` | Nguồn đặt kế thừa từ `hold` (`APP` / `IN_PERSON`) |
| `status` | `booking_status` | NOT NULL | `'CONFIRMED'` | — | Trạng thái (`CONFIRMED`, `CANCELLED_BY_PLAYER`, `CANCELLED_BY_OWNER`) |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm xác nhận đơn |
| `cancelled_at` | `timestamptz` | NULL | — | — | Thời điểm hủy đơn |
| `cancel_reason` | `owner_change_reason` | NULL | — | — | Lý do chủ sân hủy (bắt buộc khi `CANCELLED_BY_OWNER`) |
| `cancel_note` | `text` | NULL | — | — | Ghi chú hủy tùy chọn khi người chơi hủy |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `UQ (hold_id)`, `UQ (id, facility_id)`, `FK (hold_id, facility_id, source) -> hold(id, facility_id, source) ON DELETE RESTRICT`, `FK (user_id) -> app_user(id) ON DELETE RESTRICT`, `FK (facility_id) -> facility(id) ON DELETE RESTRICT`, `CHECK` nhất quán giữa `status`, `cancelled_at`, `cancel_reason`, `cancel_note`; chỉ mục `booking_user_idx (user_id, created_at DESC)` và `booking_facility_idx (facility_id, status)`.

---

## `DB-TBL-11`: `schedule_entry`
- **Mục đích:** Bảng lịch chung gộp `HOLD`, `BOOKING` và `BLOCK` để chống trùng slot bằng ràng buộc loại trừ GiST.
- **Liên kết:** `CLS-04` | **Yêu cầu:** `NFR-02`, `BR-02`, `BR-03`, `DM-INV-01..08`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK` | Định danh dòng lịch |
| `court_id` | `bigint` | NOT NULL | — | `FK` | Sân bị chiếm (`EXCLUDE` chống trùng theo `court_id`) |
| `facility_id` | `bigint` | NOT NULL | — | `FK` | Cơ sở (ép cùng cơ sở qua khóa ngoại ghép) |
| `start_time` | `timestamptz` | NOT NULL | — | — | Giờ bắt đầu dải (tròn phút, phút `00` hoặc `30`) |
| `end_time` | `timestamptz` | NOT NULL | — | — | Giờ kết thúc dải (`> start_time`, phút `00` hoặc `30`) |
| `entry_type` | `entry_type` | NOT NULL | — | — | Loại chiếm lịch (`HOLD`, `BOOKING`, `BLOCK`) |
| `hold_id` | `bigint` | NULL | — | `FK` | Tham chiếu `hold.id` (bắt buộc với `HOLD`/`BOOKING`) |
| `booking_id` | `bigint` | NULL | — | `FK` | Tham chiếu `booking.id` (bắt buộc với `BOOKING`) |
| `blocked_by` | `bigint` | NULL | — | `FK` | Chủ sân tạo khóa lịch (bắt buộc với `BLOCK`) |
| `unit_price` | `numeric(12,2)` | NULL | — | — | Đơn giá 1 slot 30 phút chụp tại lúc tạo hold theo giờ bắt đầu từng slot (`effective_from <= slot.startTime`), áp dụng cho `HOLD` và `BOOKING` |
| `is_active` | `boolean` | NOT NULL | `true` | — | Cờ hiệu lực trên chỉ mục GiST (`false` khi nhả/hủy) |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm ghi dòng lịch |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `FK (court_id, facility_id) -> court(id, facility_id)`, `FK (hold_id, facility_id) -> hold(id, facility_id)`, `FK (booking_id, facility_id) -> booking(id, facility_id)`, `FK (blocked_by) -> app_user(id)`, `CHECK (end_time > start_time)`, `CHECK` căn lề 30 phút trên `start_time` và `end_time`, `CHECK` bộ cột theo `entry_type`, `CHECK (is_active OR entry_type <> 'BLOCK')`, `CONSTRAINT schedule_entry_no_overlap EXCLUDE USING gist (court_id WITH =, tstzrange(start_time, end_time, '[)') WITH &&) WHERE (is_active)`; chỉ mục `schedule_entry_hold_court_start_uk (hold_id, court_id, start_time) WHERE hold_id IS NOT NULL`, `schedule_entry_booking_idx`, `schedule_entry_hold_idx`.

---

## `DB-TBL-12`: `notification`
- **Mục đích:** Lưu thông báo gửi tới người chơi khi đơn đặt bị hủy do chủ sân thay đổi lịch/sân.
- **Liên kết:** `CLS-07`, `API-NTF` | **Yêu cầu:** `FR-30`, `BR-16`

| Cột | Kiểu dữ liệu | Null | Mặc định | Khóa | Mô tả |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `bigint` | NOT NULL | Identity | `PK` | Định danh thông báo |
| `user_id` | `bigint` | NOT NULL | — | `FK` | Người chơi nhận thông báo |
| `booking_id` | `bigint` | NOT NULL | — | `FK` | Đơn đặt sân bị hủy liên quan |
| `reason` | `owner_change_reason` | NOT NULL | — | — | Nguyên nhân hủy (`BLOCKED_PERIOD`, `HOURS_CHANGED`, `COURT_DELETED`) |
| `message` | `text` | NOT NULL | — | — | Nội dung thông báo hiển thị |
| `is_read` | `boolean` | NOT NULL | `false` | — | Trạng thái đã đọc (`API-NTF`) |
| `affected_items` | `jsonb` | NOT NULL | `'[]'::jsonb` | — | Mảng JSON các sân và khung giờ thực sự bị tác động |
| `created_at` | `timestamptz` | NOT NULL | `now()` | — | Thời điểm tạo thông báo |

- **Ràng buộc & Chỉ mục:** `PK (id)`, `FK (user_id) -> app_user(id) ON DELETE RESTRICT`, `FK (booking_id) -> booking(id) ON DELETE RESTRICT`, `CHECK (btrim(message) <> '')`, `CHECK (jsonb_typeof(affected_items) = 'array')`; chỉ mục `notification_user_idx (user_id, is_read, created_at DESC)`.
