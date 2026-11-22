# Từ điển dữ liệu (Task 3.1.2)

* **Mã đối tượng truy vết:** `DB-TBL-01`..`DB-TBL-12` (mỗi bảng một mã, theo thứ tự trong file), `DB-CON-xx` (ràng buộc, xem `README.md`)

* **Issue liên quan:** `#10` — 3.1.2 Thiết kế dữ liệu và ràng buộc lịch đặt sân

* **Người chịu trách nhiệm chính:** Nguyễn Minh Trí (`@nmt1206`, tiếp nhận tạm thời từ 15/11/2026)

* **Nguồn DDL:** `schema.sql` (PostgreSQL 16). Bảng dưới được sinh trực tiếp từ cơ sở dữ liệu đã nạp `schema.sql`, nên kiểu, NULL, mặc định, ràng buộc và chỉ mục khớp với DDL.

Quy ước: `PK` khóa chính, `FK` khóa ngoại, `UQ` duy nhất, `CK` ràng buộc CHECK, `EX` ràng buộc loại trừ (exclusion). Thời điểm dùng `timestamptz` (UTC); ngày và giờ mở cửa tính theo Asia/Ho_Chi_Minh ở tầng ứng dụng. Trong PostgreSQL dùng kiểu `bigint` (`GENERATED ALWAYS AS IDENTITY`), đồng bộ trực tiếp với đặc tả API `#34` (commit `fe55c40`: truyền chuỗi số nguyên trên JSON/URL, ví dụ `"courtId": "1"`, `"expectedBookingIds": ["201"]`, ở tầng SQL luôn ép kiểu `$1::bigint`).

## DB-TBL-01: `app_user`

Tài khoản đăng nhập; mỗi tài khoản một vai trò (DB-ASM-05). Đồng bộ với `API-AUTH` (`#34`) và `CLS-01` (`#31`): tách riêng `email` (dùng để đăng nhập) và `phone` bắt buộc; dùng thống nhất tên vai trò `PLAYER` | `FACILITY_OWNER`.

* **Khái niệm miền:** DM-ENT-01 (`CLS-01`)

* **Truy vết PA2:** FR-01, FR-24, NFR-05

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK | Khóa chính. | 
| `name` | `text` | NOT NULL |  |  | Tên hiển thị, không rỗng. | 
| `email` | `text` | NOT NULL |  | UQ | Địa chỉ email dùng để đăng nhập và kiểm tra trùng (`API-AUTH` `#34`); duy nhất. | 
| `phone` | `text` | NOT NULL |  | UQ | Số điện thoại liên hệ bắt buộc khi đăng ký (`API-AUTH` `#34`); duy nhất. | 
| `password_hash` | `text` | NOT NULL |  |  | Mật khẩu đã băm; không bao giờ lưu plaintext (NFR-05). | 
| `role` | `user_role` | NOT NULL |  |  | Vai trò duy nhất của tài khoản: `PLAYER` hoặc `FACILITY_OWNER` (dùng thống nhất trên cả DB và API `#34`, `fe55c40`). | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm tạo tài khoản. | 

**Ràng buộc:**

* `app_user_pkey` (PK): `PRIMARY KEY (id)`

* `app_user_email_key` (UQ): `UNIQUE (email)`

* `app_user_phone_key` (UQ): `UNIQUE (phone)`

* `app_user_name_check` (CK): `CHECK ((btrim(name) <> ''::text))`

* `app_user_email_check` (CK): `CHECK ((btrim(email) <> ''::text))`

* `app_user_phone_check` (CK): `CHECK ((btrim(phone) <> ''::text))`

* `app_user_password_hash_check` (CK): `CHECK ((btrim(password_hash) <> ''::text))`

## DB-TBL-02: `sport`

Môn thể thao; mỗi cơ sở hỗ trợ đúng một môn (DB-ASM-06).

* **Khái niệm miền:** DM-ENT-04

* **Truy vết PA2:** FR-04

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK | Khóa chính. | 
| `name` | `text` | NOT NULL |  | UQ | Tên môn, duy nhất. | 

**Ràng buộc:**

* `sport_pkey` (PK): `PRIMARY KEY (id)`

* `sport_name_key` (UQ): `UNIQUE (name)`

* `sport_name_check` (CK): `CHECK ((btrim(name) <> ''::text))`

## DB-TBL-03: `amenity`

Tiện ích dùng để lọc cơ sở.

* **Khái niệm miền:** DM-ENT-04

* **Truy vết PA2:** FR-05

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK | Khóa chính. | 
| `name` | `text` | NOT NULL |  | UQ | Tên tiện ích, duy nhất. | 

**Ràng buộc:**

* `amenity_pkey` (PK): `PRIMARY KEY (id)`

* `amenity_name_key` (UQ): `UNIQUE (name)`

* `amenity_name_check` (CK): `CHECK ((btrim(name) <> ''::text))`

## DB-TBL-04: `facility`

Cơ sở/chi nhánh thuộc một chủ sân; mỗi chi nhánh là một dòng.

* **Khái niệm miền:** DM-ENT-02 (`CLS-02`)

* **Truy vết PA2:** FR-03, FR-04, FR-17, BR-10

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK | Khóa chính. | 
| `owner_id` | `bigint` | NOT NULL |  | FK→app_user | Chủ sân sở hữu cơ sở (BR-10). Vai trò `FACILITY_OWNER` do dịch vụ kiểm tra. | 
| `sport_id` | `bigint` | NOT NULL |  | FK→sport | Môn thể thao của cơ sở. | 
| `name` | `text` | NOT NULL |  |  | Tên cơ sở, không rỗng. | 
| `address` | `text` | NOT NULL |  |  | Địa chỉ đầy đủ. | 
| `district` | `text` | NOT NULL |  |  | Khu vực/quận dùng để lọc theo vị trí (FR-04); chủ sân nhập khi tạo cơ sở. | 
| `description` | `text` | NULL |  |  | Mô tả tự do. | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm tạo cơ sở. | 

**Ràng buộc:**

* `facility_pkey` (PK): `PRIMARY KEY (id)`

* `facility_owner_id_fkey` (FK): `FOREIGN KEY (owner_id) REFERENCES app_user(id) ON DELETE RESTRICT`

* `facility_sport_id_fkey` (FK): `FOREIGN KEY (sport_id) REFERENCES sport(id) ON DELETE RESTRICT`

* `facility_name_check` (CK): `CHECK ((btrim(name) <> ''::text))`

* `facility_address_check` (CK): `CHECK ((btrim(address) <> ''::text))`

* `facility_district_check` (CK): `CHECK ((btrim(district) <> ''::text))`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `facility_owner_idx`: `INDEX facility_owner_idx ... facility USING btree (owner_id)`

* `facility_sport_area_idx`: `INDEX facility_sport_area_idx ... facility USING btree (sport_id, district)`

## DB-TBL-05: `facility_amenity`

Bảng nối cơ sở – tiện ích (quan hệ nhiều-nhiều).

* **Khái niệm miền:** DM-ENT-04

* **Truy vết PA2:** FR-05

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `facility_id` | `bigint` | NOT NULL |  | PK, FK→facility | Cơ sở (khóa ngoại, xóa cơ sở thì xóa dòng nối). | 
| `amenity_id` | `bigint` | NOT NULL |  | PK, FK→amenity | Tiện ích (khóa ngoại). | 

**Ràng buộc:**

* `facility_amenity_pkey` (PK): `PRIMARY KEY (facility_id, amenity_id)`

* `facility_amenity_amenity_id_fkey` (FK): `FOREIGN KEY (amenity_id) REFERENCES amenity(id) ON DELETE RESTRICT`

* `facility_amenity_facility_id_fkey` (FK): `FOREIGN KEY (facility_id) REFERENCES facility(id) ON DELETE CASCADE`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `facility_amenity_rev_idx`: `INDEX facility_amenity_rev_idx ... facility_amenity USING btree (amenity_id, facility_id)`

## DB-TBL-06: `operating_hours`

Giờ mở/đóng cửa của cơ sở theo thứ trong tuần; một khoảng mỗi ngày, không qua đêm (DB-ASM-10).

* **Khái niệm miền:** DM-ENT-05

* **Truy vết PA2:** FR-18

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `facility_id` | `bigint` | NOT NULL |  | PK, FK→facility | Cơ sở. | 
| `day_of_week` | `smallint` | NOT NULL |  | PK | Thứ trong tuần theo ISO: 1 = thứ Hai … 7 = Chủ nhật. Không có dòng = đóng cửa cả ngày. | 
| `open_time` | `time without time zone` | NOT NULL |  |  | Giờ mở cửa (giờ địa phương Asia/Ho_Chi_Minh). | 
| `close_time` | `time without time zone` | NOT NULL |  |  | Giờ đóng cửa, phải sau giờ mở (không hỗ trợ qua đêm). | 

**Ràng buộc:**

* `operating_hours_pkey` (PK): `PRIMARY KEY (facility_id, day_of_week)`

* `operating_hours_facility_id_fkey` (FK): `FOREIGN KEY (facility_id) REFERENCES facility(id) ON DELETE CASCADE`

* `operating_hours_check` (CK): `CHECK ((close_time > open_time))`

* `operating_hours_day_of_week_check` (CK): `CHECK (((day_of_week >= 1) AND (day_of_week <= 7)))`

## DB-TBL-07: `court`

Sân con trong cơ sở. Xóa mềm (`status`) để giữ lịch sử booking (DB-ASM-11).

* **Khái niệm miền:** DM-ENT-03 (`CLS-06`)

* **Truy vết PA2:** FR-06, FR-17, FR-29

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK, UQ(ghép) | Khóa chính. | 
| `facility_id` | `bigint` | NOT NULL |  | UQ(ghép), FK→facility | Cơ sở chứa sân. | 
| `name` | `text` | NOT NULL |  | UQ(ghép) | Tên/số hiệu sân, duy nhất trong cơ sở. | 
| `status` | `court_status` | NOT NULL | `'ACTIVE'::court_status` |  | `ACTIVE` hoặc `DELETED` (xóa mềm, UC-12). | 
| `deleted_at` | `timestamp with time zone` | NULL |  |  | Thời điểm xóa; có giá trị khi và chỉ khi `status = DELETED`. | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm tạo sân. | 

**Ràng buộc:**

* `court_pkey` (PK): `PRIMARY KEY (id)`

* `court_id_facility_id_key` (UQ): `UNIQUE (id, facility_id)`

* `court_facility_id_name_key` (UQ): `UNIQUE (facility_id, name)`

* `court_facility_id_fkey` (FK): `FOREIGN KEY (facility_id) REFERENCES facility(id) ON DELETE RESTRICT`

* `court_check` (CK): `CHECK ((((status = 'ACTIVE'::court_status) AND (deleted_at IS NULL)) OR ((status = 'DELETED'::court_status) AND (deleted_at IS NOT NULL))))`

* `court_name_check` (CK): `CHECK ((btrim(name) <> ''::text))`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `court_facility_active_idx`: `INDEX court_facility_active_idx ... court USING btree (facility_id) WHERE (status = 'ACTIVE'::court_status)`

## DB-TBL-08: `court_price`

Giá của sân theo thời điểm hiệu lực; mỗi sân có một hoặc nhiều dòng giá. Đồng bộ với `#34` (§2.2): mỗi slot 30 phút áp mức giá từ dòng mới nhất có `effective_from <= slot.startTime`, và đơn giá đó được chụp vào `schedule_entry.unit_price` khi tạo hold (DB-ASM-09).

* **Khái niệm miền:** DM-ENT-06

* **Truy vết PA2:** FR-07, FR-19

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `court_id` | `bigint` | NOT NULL |  | PK, FK→court | Sân. | 
| `effective_from` | `timestamp with time zone` | NOT NULL |  | PK | Thời điểm bắt đầu áp dụng mức giá này. | 
| `amount_per_slot` | `numeric(12,2)` | NOT NULL |  |  | Giá mỗi slot 30 phút (VND), không âm. | 

**Ràng buộc:**

* `court_price_pkey` (PK): `PRIMARY KEY (court_id, effective_from)`

* `court_price_court_id_fkey` (FK): `FOREIGN KEY (court_id) REFERENCES court(id) ON DELETE RESTRICT`

* `court_price_amount_per_slot_check` (CK): `CHECK ((amount_per_slot >= (0)::numeric))`

## DB-TBL-09: `hold`

Giữ chỗ tạm thời tối đa 5 phút, không gia hạn. Lưu trực tiếp `source` (`APP` / `IN_PERSON`) để giữ ngữ cảnh đặt tại quầy (UC-13) qua hai bước.

* **Khái niệm miền:** DM-ENT-08 (`CLS-03`)

* **Truy vết PA2:** FR-10, FR-14, FR-21, FR-25, FR-31, BR-01, BR-07, AC-25

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK, UQ(ghép) | Khóa chính. | 
| `user_id` | `bigint` | NOT NULL |  | FK→app_user | Người giữ chỗ (người chơi, hoặc chủ sân với booking tại quầy). Mỗi user tối đa 1 hold `ACTIVE` tại một thời điểm. | 
| `facility_id` | `bigint` | NOT NULL |  | UQ(ghép), FK→facility | Cơ sở của hold; mọi dải slot của hold phải thuộc cơ sở này (DM-INV-01). | 
| `source` | `booking_source` | NOT NULL | `'APP'::booking_source` | UQ(ghép) | `APP` (người chơi đặt online, `isDirect = false`) hoặc `IN_PERSON` (chủ sân đặt tại quầy, `isDirect = true`). | 
| `status` | `hold_status` | NOT NULL | `'ACTIVE'::hold_status` |  | `ACTIVE` → `CONFIRMED` / `RELEASED` / `EXPIRED` (xem STM-01). `EXPIRED` = đã quá hạn nhưng slot chưa nhả xong. | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm tạo hold (giờ DB). | 
| `expires_at` | `timestamp with time zone` | NOT NULL | `(now() + '00:05:00'::interval)` |  | Luôn bằng `created_at + 5 phút`, không đổi (BR-01, BR-07); có CHECK. | 
| `released_at` | `timestamp with time zone` | NULL |  |  | Thời điểm nhả xong; có giá trị khi và chỉ khi `status = RELEASED`. | 
| `release_failed_at` | `timestamp with time zone` | NULL |  |  | Thời điểm lần nhả gần nhất thất bại; chỉ hợp lệ khi `status = EXPIRED`; xóa (`NULL`) khi nhả thành công. Giúp API trả `ReleaseFailed` (FR-14). | 

**Ràng buộc:**

* `hold_pkey` (PK): `PRIMARY KEY (id)`

* `hold_id_facility_id_key` (UQ): `UNIQUE (id, facility_id)`

* `hold_id_facility_id_source_key` (UQ): `UNIQUE (id, facility_id, source)`

* `hold_facility_id_fkey` (FK): `FOREIGN KEY (facility_id) REFERENCES facility(id) ON DELETE RESTRICT`

* `hold_user_id_fkey` (FK): `FOREIGN KEY (user_id) REFERENCES app_user(id) ON DELETE RESTRICT`

* `hold_check` (CK): `CHECK ((expires_at = (created_at + '00:05:00'::interval)))`

* `hold_check1` (CK): `CHECK ((((status = 'RELEASED'::hold_status) AND (released_at IS NOT NULL)) OR ((status <> 'RELEASED'::hold_status) AND (released_at IS NULL))))`

* `hold_check2` (CK): `CHECK (((release_failed_at IS NULL) OR (status = 'EXPIRED'::hold_status)))`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `hold_expiry_idx`: `INDEX hold_expiry_idx ... hold USING btree (expires_at) WHERE (status = 'ACTIVE'::hold_status)`

* `hold_release_retry_idx`: `INDEX hold_release_retry_idx ... hold USING btree (expires_at) WHERE (status = 'EXPIRED'::hold_status)`

* `hold_user_active_idx` (UQ): `UNIQUE INDEX hold_user_active_idx ... hold USING btree (user_id) WHERE (status = 'ACTIVE'::hold_status)`

## DB-TBL-10: `booking`

Đặt chỗ đã xác nhận; luôn sinh ra từ đúng một hold và kế thừa `source` của hold đó. Hủy là đổi trạng thái, không xóa.

* **Khái niệm miền:** DM-ENT-09 (`CLS-05`)

* **Truy vết PA2:** FR-11, FR-12, FR-16, FR-21, FR-28, FR-29, FR-30

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK, UQ(ghép) | Khóa chính. | 
| `hold_id` | `bigint` | NOT NULL |  | UQ, FK→hold | Hold sinh ra booking; duy nhất, mỗi booking đúng một hold (kể cả booking tại quầy). | 
| `user_id` | `bigint` | NOT NULL |  | FK→app_user | Người đặt: người chơi, hoặc chủ sân với `source = IN_PERSON`. | 
| `facility_id` | `bigint` | NOT NULL |  | UQ(ghép), FK→facility, FK→hold | Cơ sở; bằng `facility_id` của hold nhờ khóa ngoại ghép. | 
| `source` | `booking_source` | NOT NULL |  | FK→hold | `APP` hoặc `IN_PERSON`; bằng `source` của hold nhờ khóa ngoại ghép `(hold_id, facility_id, source)`. | 
| `status` | `booking_status` | NOT NULL | `'CONFIRMED'::booking_status` |  | `CONFIRMED`, `CANCELLED_BY_PLAYER`, `CANCELLED_BY_OWNER`. 'Đã hoàn thành' suy ra từ thời gian, không lưu. | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm xác nhận booking. | 
| `cancelled_at` | `timestamp with time zone` | NULL |  |  | Thời điểm hủy; có giá trị khi và chỉ khi đã bị hủy. | 
| `cancel_reason` | `owner_change_reason` | NULL |  |  | Lý do chuẩn hóa bắt buộc khi chủ sân hủy (FR-30); `NULL` khi còn hiệu lực hoặc người chơi hủy. | 
| `cancel_note` | `text` | NULL |  |  | Lý do/ghi chú tùy chọn khi người chơi tự hủy (`reason?` trong `cancelBookingByPlayer`, `#31`/`#34`); `NULL` khi `status = CONFIRMED`, khi chủ sân hủy, hoặc khi người chơi không nhập. | 

**Ràng buộc:**

* `booking_pkey` (PK): `PRIMARY KEY (id)`

* `booking_hold_id_key` (UQ): `UNIQUE (hold_id)`

* `booking_id_facility_id_key` (UQ): `UNIQUE (id, facility_id)`

* `booking_facility_id_fkey` (FK): `FOREIGN KEY (facility_id) REFERENCES facility(id) ON DELETE RESTRICT`

* `booking_hold_id_facility_id_source_fkey` (FK): `FOREIGN KEY (hold_id, facility_id, source) REFERENCES hold(id, facility_id, source) ON DELETE RESTRICT`

* `booking_user_id_fkey` (FK): `FOREIGN KEY (user_id) REFERENCES app_user(id) ON DELETE RESTRICT`

* `booking_check` (CK): `CHECK ((((status = 'CONFIRMED'::booking_status) AND (cancelled_at IS NULL) AND (cancel_reason IS NULL) AND (cancel_note IS NULL)) OR ((status = 'CANCELLED_BY_PLAYER'::booking_status) AND (cancelled_at IS NOT NULL) AND (cancel_reason IS NULL)) OR ((status = 'CANCELLED_BY_OWNER'::booking_status) AND (cancelled_at IS NOT NULL) AND (cancel_reason IS NOT NULL) AND (cancel_note IS NULL))))`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `booking_facility_idx`: `INDEX booking_facility_idx ... booking USING btree (facility_id, status)`

* `booking_user_idx`: `INDEX booking_user_idx ... booking USING btree (user_id, created_at DESC)`

## DB-TBL-11: `schedule_entry`

Lịch chung: mỗi dòng là một sân cùng một dải slot 30 phút liên tiếp có cùng đơn giá đang bị chiếm bởi `HOLD`, `BOOKING` hoặc `BLOCK`. Gộp `HoldItem`, `BookingItem` và `BlockedPeriod` để một ràng buộc chống chồng lấn bao phủ cả ba, đồng thời lưu `unit_price` chụp tại thời điểm tạo hold (theo `effective_from <= slot.startTime`) để tính `totalPrice` nhất quán (`#34`).

* **Khái niệm miền:** DM-ENT-10, DM-ENT-11, DM-ENT-13 (`CLS-04`)

* **Truy vết PA2:** FR-07, FR-09, FR-13, FR-16, FR-20, FR-22, NFR-02, BR-02, BR-03, BR-13

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK | Khóa chính. | 
| `court_id` | `bigint` | NOT NULL |  | UQ(ghép), FK→court | Sân bị chiếm. | 
| `facility_id` | `bigint` | NOT NULL |  | FK→booking, FK→court, FK→hold | Cơ sở của sân (cố ý lặp để khóa ngoại ghép buộc hold/booking/sân cùng một cơ sở; xem mục chuẩn hóa). | 
| `start_time` | `timestamp with time zone` | NOT NULL |  | UQ(ghép) | Đầu dải, tròn phút (`date_trunc('minute', start_time)`) và phút chia hết cho 30. | 
| `end_time` | `timestamp with time zone` | NOT NULL |  |  | Cuối dải (không gồm), tròn phút (`date_trunc('minute', end_time)`) và phút chia hết cho 30, sau `start_time`. Dải = `[start_time, end_time)`. | 
| `entry_type` | `entry_type` | NOT NULL |  |  | `HOLD`, `BOOKING` hoặc `BLOCK`. `HOLD` chuyển thành `BOOKING` khi xác nhận. | 
| `hold_id` | `bigint` | NULL |  | UQ(ghép), FK→hold | Hold gốc (`HOLD` và `BOOKING`); `NULL` với `BLOCK`. | 
| `booking_id` | `bigint` | NULL |  | FK→booking | Booking (chỉ `BOOKING`); `NULL` với `HOLD` và `BLOCK`. | 
| `blocked_by` | `bigint` | NULL |  | FK→app_user | Chủ sân tạo khoảng khóa (chỉ `BLOCK`). | 
| `unit_price` | `numeric(12,2)` | NULL |  |  | Đơn giá 1 slot 30 phút (VND) chụp từ `court_price` theo `effective_from <= start_time` tại thời điểm tạo hold (`NOT NULL` và `>= 0` với `HOLD` và `BOOKING`, `NULL` với `BLOCK`). Dùng để tính `totalPrice` trên API `#34`. | 
| `is_active` | `boolean` | NOT NULL | `true` |  | `true` = đang chiếm chỗ. Nhả hold, hủy booking thì chuyển `false` và giữ lại làm lịch sử. `BLOCK` luôn `true` (không có thao tác gỡ khóa, DB-ASM-07). | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm tạo dòng. | 

**Ràng buộc:**

* `schedule_entry_pkey` (PK): `PRIMARY KEY (id)`

* `schedule_entry_blocked_by_fkey` (FK): `FOREIGN KEY (blocked_by) REFERENCES app_user(id) ON DELETE RESTRICT`

* `schedule_entry_booking_id_facility_id_fkey` (FK): `FOREIGN KEY (booking_id, facility_id) REFERENCES booking(id, facility_id) ON DELETE RESTRICT`

* `schedule_entry_court_id_facility_id_fkey` (FK): `FOREIGN KEY (court_id, facility_id) REFERENCES court(id, facility_id) ON DELETE RESTRICT`

* `schedule_entry_hold_id_facility_id_fkey` (FK): `FOREIGN KEY (hold_id, facility_id) REFERENCES hold(id, facility_id) ON DELETE RESTRICT`

* `schedule_entry_no_overlap` (EX): `EXCLUDE USING gist (court_id WITH =, tstzrange(start_time, end_time, '[)'::text) WITH &&) WHERE (is_active)`

* `schedule_entry_check` (CK): `CHECK ((end_time > start_time))`

* `schedule_entry_check1` (CK): `CHECK (((start_time = date_trunc('minute'::text, start_time)) AND (((EXTRACT(minute FROM start_time))::integer % 30) = 0)))`

* `schedule_entry_check2` (CK): `CHECK (((end_time = date_trunc('minute'::text, end_time)) AND (((EXTRACT(minute FROM end_time))::integer % 30) = 0)))`

* `schedule_entry_check3` (CK): `CHECK ((((entry_type = 'HOLD'::entry_type) AND (hold_id IS NOT NULL) AND (booking_id IS NULL) AND (blocked_by IS NULL) AND (unit_price IS NOT NULL) AND (unit_price >= (0)::numeric)) OR ((entry_type = 'BOOKING'::entry_type) AND (hold_id IS NOT NULL) AND (booking_id IS NOT NULL) AND (blocked_by IS NULL) AND (unit_price IS NOT NULL) AND (unit_price >= (0)::numeric)) OR ((entry_type = 'BLOCK'::entry_type) AND (hold_id IS NULL) AND (booking_id IS NULL) AND (blocked_by IS NOT NULL) AND (unit_price IS NULL))))`

* `schedule_entry_check4` (CK): `CHECK ((is_active OR (entry_type <> 'BLOCK'::entry_type)))`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `schedule_entry_hold_court_start_uk` (UQ): `UNIQUE INDEX schedule_entry_hold_court_start_uk ... schedule_entry USING btree (hold_id, court_id, start_time) WHERE (hold_id IS NOT NULL)`

* `schedule_entry_booking_idx`: `INDEX schedule_entry_booking_idx ... schedule_entry USING btree (booking_id) WHERE (booking_id IS NOT NULL)`

* `schedule_entry_hold_idx`: `INDEX schedule_entry_hold_idx ... schedule_entry USING btree (hold_id) WHERE (hold_id IS NOT NULL)`

## DB-TBL-12: `notification`

Thông báo trong ứng dụng gửi cho người chơi khi chủ sân hủy booking. Có trạng thái đã đọc (`is_read`) và danh sách các sân/khung giờ thực sự bị ảnh hưởng (`affected_items`) đồng bộ với `API-NTF` (`#34` §2.6, commit `fe55c40`, `DB-ASM-08`).

* **Khái niệm miền:** DM-ENT-12 (`CLS-07`)

* **Truy vết PA2:** FR-30, NFR-09, BR-16

| Cột | Kiểu | NULL | Mặc định | Khóa | Mô tả | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| `id` | `bigint` | NOT NULL | `identity` | PK | Khóa chính (truyền chuỗi số nguyên trên API `#34`, `fe55c40`). | 
| `user_id` | `bigint` | NOT NULL |  | FK→app_user | Người nhận. | 
| `booking_id` | `bigint` | NOT NULL |  | FK→booking | Booking bị hủy liên quan. | 
| `reason` | `owner_change_reason` | NOT NULL |  |  | Lý do chuẩn hóa: `BLOCKED_PERIOD`, `HOURS_CHANGED`, `COURT_DELETED` (DB-ASM-04). | 
| `message` | `text` | NOT NULL |  |  | Nội dung hiển thị. | 
| `is_read` | `boolean` | NOT NULL | `false` |  | Trạng thái đã đọc (`false` = chưa đọc, `true` = đã đọc) phục vụ `isRead`, `unreadOnly`, `unreadCount` và `PATCH /notifications/:notificationId/read` (`#34` §2.6, `fe55c40`). | 
| `affected_items` | `jsonb` | NOT NULL | `'[]'::jsonb` |  | Mảng JSON `[{"courtId": "1", "courtName": "...", "startTime": "...", "endTime": "..."}]` (`courtId` dạng chuỗi số nguyên, `fe55c40`) chụp các sân và khung giờ thực sự bị tác động ngay tại thời điểm áp dụng thay đổi lịch (bảo đảm khi hủy cả đơn nhiều sân chỉ liệt kê đúng phần bị ảnh hưởng, FR-30). | 
| `created_at` | `timestamp with time zone` | NOT NULL | `now()` |  | Thời điểm tạo. | 

**Ràng buộc:**

* `notification_pkey` (PK): `PRIMARY KEY (id)`

* `notification_booking_id_fkey` (FK): `FOREIGN KEY (booking_id) REFERENCES booking(id) ON DELETE RESTRICT`

* `notification_user_id_fkey` (FK): `FOREIGN KEY (user_id) REFERENCES app_user(id) ON DELETE RESTRICT`

* `notification_message_check` (CK): `CHECK ((btrim(message) <> ''::text))`

* `notification_affected_items_check` (CK): `CHECK ((jsonb_typeof(affected_items) = 'array'::text))`

**Chỉ mục (ngoài các chỉ mục do ràng buộc tạo ra):**

* `notification_user_idx`: `INDEX notification_user_idx ... notification USING btree (user_id, is_read, created_at DESC)`