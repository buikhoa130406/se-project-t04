# Giải thích Nguyên tắc và Mẫu Thiết kế Áp dụng (Task 3.3.5 — Issue #21)

- **Mã đối tượng truy vết:** `PRI-01`..`PRI-05` (Nguyên tắc thiết kế), `PAT-01`..`PAT-05` (Mẫu thiết kế), `PAT-MAP` (Bảng tổng hợp & Loại trừ phạm vi)
- **Người thực hiện:** Lý Sĩ Vĩ (`@Lysivi2005`)
- **Người kiểm tra:** Trí (`@nmt1206` — đầu mối dữ liệu `#10`), Khoa (`@buikhoa130406` — lập luận, bằng chứng `#7` & cập nhật `ADR-002`)
- **Tài liệu liên quan:**
  - Tổng quan & Mục tiêu kiến trúc (`3.0.1`): `docs/design/design-overview.md` (`OVW-01`, `ASR-G1`..`ASR-G9`)
  - Kiến trúc hệ thống (`3.1.1`): `docs/design/architecture/architecture-design.md` (`ARC-01`, `C4-*`)
  - Thiết kế lớp (`3.3.2`): `docs/design/classes/class-design.md` (`CLS-01`..`CLS-08`)
  - Thiết kế UI/UX (`3.2.1`): `docs/design/ui/ui-design-specification.md` (`UI-01`..`UI-15`)
  - Baseline PA2: `pa/PA2/T04-PA2-SoftwareRequirementsSpecification.docx`

---

## 1. Các Nguyên tắc Thiết kế Áp dụng (Design Principles)

### 1.1. [`PRI-01`] Separation of Concerns (Phân tách mối quan tâm)
- **Nội dung nguyên tắc:** Chia hệ thống thành các phần riêng biệt, mỗi phần đảm nhận một nhóm trách nhiệm rõ ràng về giao diện, điều phối nghiệp vụ hoặc lưu trữ dữ liệu.
- **Bằng chứng áp dụng:**
  - Trong `architecture-design.md` (`ARC-01`, `C4-CMP`): Hệ thống tách biệt **React SPA** (tầng hiển thị) khỏi **Node.js + Express API** (tầng xử lý) và tổ chức Backend theo 3 lớp `Controller -> Service -> Repository`, chia thành 5 module độc lập (*Auth, Facility & Search, Booking & Hold, Owner Schedule, In-App Notification*).
  - Trong `class-design.md` (`CLS-04`, `CLS-05`, `CLS-08`): Lớp thực thể chỉ giữ dữ liệu và quy tắc cục bộ của đối tượng (`Booking.canCancelByPlayer()`), còn luồng điều phối giao dịch và kiểm tra chéo nằm ở `BookingService` và `OwnerScheduleService`.
- **Lợi ích & Đáp ứng yêu cầu:** Đảm bảo mọi kiểm tra phân quyền (`NFR-04`), tính hợp lệ 30 phút và mốc 3h/24h được thực thi tập trung ở Backend; Frontend (`ui-design-specification.md`) chỉ tập trung xử lý tương tác và hiển thị trạng thái.

---

### 1.2. [`PRI-02`] Single Responsibility Principle (SRP — Đơn trách nhiệm)
- **Nội dung nguyên tắc:** Mỗi lớp hoặc module chỉ nên có một lý do duy nhất để thay đổi, chịu trách nhiệm cho một khía cạnh nghiệp vụ cụ thể.
- **Bằng chứng áp dụng:**
  - Trong `class-design.md`:
    - `SlotHold` (`CLS-04`) chỉ quản lý vòng đời lượt giữ chỗ 5 phút (`expiresAt`, `isExpired()`, `remainingSeconds()`, `belongsTo()`).
    - `Booking` (`CLS-05`) chỉ đại diện đơn đặt sân đã xác nhận (`canCancelByPlayer()`, `isAffectedUnder24Hours()`, `isCompleted()`).
    - `ScheduleBlock` (`CLS-06`) chỉ quản lý khoảng khóa lịch của chủ sân (`isAtLeast24HoursAhead()`, `overlaps()`).
    - `Notification` (`CLS-07`) chỉ lưu trữ thông báo hủy đơn In-app (`relatedBookingId`, `message`, `createdAt`).
- **Lợi ích & Đáp ứng yêu cầu:** Tách `SlotHold` khỏi `Booking` giúp tránh trộn lẫn dữ liệu giữ chỗ tạm thời với đơn đặt chính thức, ngăn lỗi rò rỉ lịch ảo khi lượt giữ hết hạn 5 phút (`FR-14`, `NFR-03`, `ASR-G2`).

---

### 1.3. [`PRI-03`] Dependency Inversion Principle (DIP — Đảo ngược phụ thuộc)
- **Nội dung nguyên tắc:** Các module nghiệp vụ cấp cao không nên phụ thuộc trực tiếp vào chi tiết cài đặt lưu trữ cấp thấp, mà cả hai nên phụ thuộc vào lớp trừu tượng (interface).
- **Bằng chứng áp dụng:**
  - Trong `class-design.md` (`CLS-08`): `BookingService` và `OwnerScheduleService` khai báo phụ thuộc thông qua các Repository (`BookingRepository`, `HoldRepository`, `ScheduleRepository`, `FacilityRepository`) thay vì nhúng trực tiếp câu truy vấn SQL của PostgreSQL vào tầng Service.
- **Lợi ích & Đáp ứng yêu cầu:** Giúp việc kiểm thử đơn vị (Jest unit test) có thể giả lập (*mock*) tầng dữ liệu dễ dàng, đồng thời cho phép tối ưu chỉ mục/khóa dòng PostgreSQL trong Repository mà không sửa logic nghiệp vụ (`NFR-02`, `NFR-06`).

---

### 1.4. [`PRI-04`] Don't Repeat Yourself (DRY — Tái sử dụng logic dùng chung)
- **Nội dung nguyên tắc:** Không lặp lại cùng một quy tắc hoặc luồng xử lý ở nhiều nơi; thay vào đó tập trung vào một hàm/module dùng chung và tham số hóa điểm khác biệt.
- **Bằng chứng áp dụng:**
  - **Đặt trực tiếp (`UC-13`) tái sử dụng luồng đặt qua app (`UC-05`, `UC-06`):** Trong `class-design.md` (`CLS-08`), `OwnerScheduleService.createDirectBooking(...)` gọi lại cơ chế kiểm tra xung đột và hold/confirm nguyên tử của `BookingService` trên cùng **Lịch chung**, chỉ bỏ qua điều kiện giới hạn đặt trước 2 khung (`validateLeadTime` với `isDirect = true` theo `FR-21`, `BR-08`).
  - **Bộ quy tắc 24 giờ dùng chung cho Chủ sân (`UC-11`, `UC-12`):** `createScheduleBlock`, `updateOperatingHours` và `deleteCourt` cùng sử dụng hai hàm kiểm tra dùng chung `assertNoActiveHoldConflict` và `assertAllAffectedBookingsOver24h` (`FR-29`, `BR-11`, tương đồng cơ chế `previewChange`/`applyChange` ở `SEQ-04B`).
- **Lợi ích & Đáp ứng yêu cầu:** Đảm bảo không xảy ra tình trạng đặt trực tiếp ghi đè lên giữ chỗ/đơn đã đặt (`BR-13`) và đồng bộ tuyệt đối quy tắc 24 giờ giữa các màn hình quản lý (`UI-13`, `UI-14`, `UI-15`).

---

### 1.5. [`PRI-05`] Fail-Safe Defaults & Least Privilege (Mặc định an toàn & Quyền tối thiểu)
- **Nội dung nguyên tắc:** Khi xảy ra lỗi hoặc không đủ quyền, hệ thống phải từ chối an toàn và không làm thay đổi dữ liệu; người dùng chỉ được cấp quyền đúng với vai trò sở hữu.
- **Bằng chứng áp dụng:**
  - **Quyền tối thiểu:** `Auth & RBAC Middleware` (`3.1.1`, `ADR-003`) kết hợp `Facility.isOwnedBy(userId)` (`CLS-02`) chặn 100% truy cập trái phép từ Khách/Người chơi hoặc Chủ sân khác (`NFR-04`). `SlotHold.belongsTo(userId)` ngăn xác nhận chéo lượt giữ (`FR-11`).
  - **Mặc định an toàn (*All-or-Nothing*):** Khi tiến hành đặt sân (`UI-06`, `BookingService.createHold`), nếu có dù chỉ 1 khung xung đột thì hủy toàn bộ yêu cầu giữ chỗ (`BR-05`, `ADR-002`). Khi hết hạn 5 phút trên `UI-07`, giao diện khóa nút Xác nhận ngay và chỉ cho chọn lại sau khi nhả chỗ thành công (`FR-14`, `STM-01`).

---

## 2. Các Mẫu Thiết kế Áp dụng (Design Patterns)

### 2.1. [`PAT-01`] Modular Monolith & Layered Architecture (Mẫu Kiến trúc Phân tầng)
- **Vấn đề cần giải quyết:** Nhóm gồm 4 thành viên với thời hạn 10 tuần (`CON-03`, `CON-04`) cần một kiến trúc dễ phát triển và kiểm thử, nhưng vẫn phải đảm bảo giao dịch ACID cho lịch chung (`ASR-G5`) và phản hồi $\le 2$ giây cho 50 người dùng đồng thời (`NFR-06`).
- **Cách áp dụng & Bằng chứng:** Tổ chức Backend thành một ứng dụng thống nhất chia module theo miền nghiệp vụ và phân tầng `Controller -> Service -> Repository` (`architecture-design.md` — `ARC-01`, `C4-CNT`, `C4-CMP`; tương ứng `ADR-001`).
- **Lý do chọn & Đánh đổi (Trade-off):** Chọn *Modular Monolith* thay vì *Microservices* vì Microservices làm phát sinh giao dịch phân tán phức tạp (2-Phase Commit) khi kiểm tra chéo `SlotHold`, `Booking` và `ScheduleBlock`, gây rủi ro trễ hạn môn học và làm giảm độ ổn định của ràng buộc chống trùng slot (`NFR-02`).

---

### 2.2. [`PAT-02`] Repository Pattern (Mẫu Kho lưu trữ dữ liệu)
- **Vấn đề cần giải quyết:** Tách biệt logic nghiệp vụ phức tạp (kiểm tra liên tiếp 30 phút, tính mốc 3h/24h, xử lý hủy đơn hàng loạt) khỏi các thao tác truy vấn PostgreSQL và quản lý Transaction.
- **Cách áp dụng & Bằng chứng:** Định nghĩa các Repository (`BookingRepository`, `HoldRepository`, `ScheduleRepository`, `FacilityRepository`) trong `architecture-design.md` (`C4-CMP`) và làm thuộc tính phụ thuộc của các Service trong `class-design.md` (`CLS-08`).
- **Lý do chọn & Đánh đổi (Trade-off):** Giúp cô lập tầng dữ liệu để kiểm thử độc lập và gom toàn bộ câu lệnh kiểm soát tranh chấp (khóa dòng hoặc ràng buộc duy nhất sau khi chốt ở `#10`) và truy vấn suy diễn `derivedStatus` về một nơi duy nhất, dù phải viết thêm lớp interface trung gian.

---

### 2.3. [`PAT-03`] State-driven Lifecycle Pattern (Quản lý vòng đời theo Trạng thái)
- **Vấn đề cần giải quyết:** `SlotHold` và `Booking` chuyển đổi qua nhiều trạng thái theo hành động người dùng và theo thời gian thực (`5 phút`, `3 giờ`, `24 giờ`), đòi hỏi tính nhất quán giữa DB, Service và UI (`STM-01`, `STM-03`, `UI-06`, `UI-07`, `UI-09`, `UI-10`).
- **Cách áp dụng & Bằng chứng:** Chuẩn hóa trạng thái qua Enum (`HoldStatus`: `ACTIVE`, `CONFIRMED`, `RELEASED`, `EXPIRED`; `BookingStatus`: `CONFIRMED`, `CANCELLED_BY_PLAYER`, `CANCELLED_BY_OWNER`) kết hợp các phương thức kiểm tra điều kiện chuyển trạng thái và suy diễn thời gian trực tiếp trên Entity (`SlotHold.isExpired()`, `Booking.canCancelByPlayer()`, `Booking.isAffectedUnder24Hours()`, `Booking.isCompleted()` trong `class-design.md`).
- **Lý do chọn & Đánh đổi (Trade-off):** Dùng Enum kết hợp *guard methods* trên Entity và suy diễn trạng thái "Đã hoàn thành" theo thời gian (`now >= latestEndTime`) thay vì tách thành nhiều lớp con `ActiveHoldState`, `ExpiredHoldState` (GoF State class hierarchy) hoặc chạy job cập nhật DB hàng loạt, giữ thiết kế gọn nhẹ cho nhóm triển khai ở PA5.

---

### 2.4. [`PAT-04`] Atomic Transaction & Concurrency Control *(Locking / Unique Constraint đang chờ `#10` & `ADR-002`)*
- **Vấn đề cần giải quyết:** Ngăn chặn điều kiện tranh chấp (*race condition*) khi nhiều người cùng bấm *Tiến hành đặt sân* cho cùng một khung giờ (`FR-13`, `NFR-02`), đảm bảo quy tắc *All-or-Nothing* (`BR-05`, `ADR-002`) và đảm bảo việc chủ sân hủy đơn + tạo thông báo In-app xảy ra đồng bộ (`FR-29`, `FR-30`).
- **Phần đã thống nhất & Bằng chứng (`ADR-002`, `3.1.1`, `3.3.2`, `3.3.3`):** Toàn bộ thao tác kiểm tra xung đột và ghi dữ liệu của `createHold`, `confirmBooking`, `applyScheduleChange` bắt buộc thực thi trọn vẹn trong **1 PostgreSQL ACID Transaction (*All-or-Nothing*)** tại tầng Repository (`CLS-08`, `SEQ-01`, `SEQ-02`, `SEQ-04`). Nếu bất kỳ khung giờ nào lỗi hoặc có xung đột, toàn bộ giao dịch được rollback và giữ 0 khung.
- **Phần đang chờ xác nhận chi tiết (`Pending #10 / ADR-002`):** Cơ chế chống đặt trùng cụ thể ở tầng cơ sở dữ liệu — lựa chọn giữa **khóa bi quan theo dòng (`SELECT ... FOR UPDATE`)** hoặc **ràng buộc duy nhất (`UNIQUE / Exclusion Constraint`) theo `(court_id, slot_start)`** — hiện đang chờ **Trí** (`@nmt1206`) chốt phương án cuối trong thiết kế dữ liệu `#10`, sau đó **Khoa** (`@buikhoa130406`) sẽ cập nhật trạng thái `ADR-002` (và phụ trách phần thử kết nối `#7`). Sau khi `#10` chốt, tài liệu sẽ dẫn chiếu trực tiếp đến tên ràng buộc/thao tác cụ thể trong `docs/design/data/`.
- **Đánh đổi (Trade-off):** Dùng giao dịch ACID trực tiếp tại PostgreSQL đánh đổi một phần nhỏ thông lượng ghi đồng thời nhưng ưu tiên cao nhất tính đúng đắn **0 đơn trùng** (`NFR-02`) ở quy mô 50 người dùng đồng thời (`NFR-06`).

---

### 2.5. [`PAT-05`] Hybrid Expiry Pattern (Lazy Check + Background Polling Worker)
- **Vấn đề cần giải quyết:** Lượt giữ chỗ chỉ kéo dài tối đa 5 phút, **không tự gia hạn khi tải lại trang (F5)** (`FR-25`), phải từ chối xác nhận ngay tại mốc hết hạn và hướng tới hoàn tất nhả chỗ trong **mục tiêu tối đa 5 giây** (`FR-14`, `FR-26`, `NFR-03`, `ASR-G2`).
- **Cách áp dụng & Bằng chứng:**
  - **Lưu mốc cố định & Lazy Check:** `SlotHold` lưu `expiresAt = createdAt + 5 phút` trên DB (`CLS-04`). Khi F5, Frontend gọi API (`getActiveHold`) nhận `expiresAt` và `serverNow` (đồng bộ hợp đồng với `UI-07` và API `#12`) để tính và đếm ngược đúng thời gian còn lại. Khi người chơi bấm *Xác nhận*, `SlotHold.isExpired(now)` kiểm tra tức thì `now >= expiresAt` để từ chối xác nhận ngay tại giây hết hạn mà không phụ thuộc worker đã chạy kịp hay chưa (`STM-01`).
  - **Background Polling Worker (`ReleaseJob`):** `Hold Expiry Worker` (`3.1.1` `C4-CNT`/`C4-CMP`) gọi `BookingService.releaseExpiredHolds(now)` theo tham số thiết kế chu kỳ $\le 1$ giây để chuyển các `SlotHold` quá hạn sang `RELEASED` (nếu lỗi giữ nguyên `EXPIRED` và thử lại ở chu kỳ sau, `SEQ-02B`).
- **Mục tiêu `NFR-03` & Cách đo kiểm chứng:** Mốc **$\le 5$ giây** là **mục tiêu hiệu năng của `NFR-03` cần đo kiểm**, được xác định từ thời điểm `expiresAt` đến khi transaction giải phóng trên PostgreSQL hoàn tất ghi `RELEASED` và truy vấn lịch chung mở lại slot về trạng thái `AVAILABLE` (bao gồm cả thời gian trễ quét + xử lý + ghi DB). Kết quả thử nghiệm kết nối **`#7` (`2.3.1`)** chỉ làm bằng chứng cho phạm vi kết nối/kịch bản mà bài thử đó thực sự đo được, không tự suy rộng sang `NFR-03` nếu chưa chạy benchmark hết hạn/tranh chấp riêng.
- **Lý do chọn & Đánh đổi (Trade-off):** Tránh phải dựng thêm Redis TTL hay hệ thống hàng đợi tin nhắn (RabbitMQ/BullMQ) nằm ngoài stack chuẩn PA2 (`CON-01`), giữ hạ tầng gọn trên Cloud Linux và dễ kiểm thử.

---

## 3. Bảng Tổng hợp Truy vết Nguyên tắc & Mẫu Thiết kế (`PAT-MAP`)

| Mã | Tên Nguyên tắc / Pattern | Bằng chứng Thiết kế Liên quan | Yêu cầu / NFR / ASR Đáp ứng |
|---|---|---|---|
| `PRI-01` | Separation of Concerns | `architecture-design.md` (`ARC-01`, `C4-CMP`), `class-design.md` | FR-01–FR-30, NFR-04, ASR-G4 |
| `PRI-02` | Single Responsibility Principle | `CLS-04` (`SlotHold`), `CLS-05` (`Booking`), `CLS-06`, `CLS-07` | FR-10, FR-14, FR-20, FR-30 |
| `PRI-03` | Dependency Inversion Principle | `CLS-08` (`BookingService`, `OwnerScheduleService` & Repositories) | NFR-02, NFR-06 (khả năng test Jest) |
| `PRI-04` | Don't Repeat Yourself (DRY) | `createDirectBooking` dùng lại `BookingService`; bộ kiểm tra 24h | FR-21, FR-29, BR-08, BR-11, BR-13 |
| `PRI-05` | Fail-Safe Defaults & Least Privilege | `Auth & RBAC Middleware`, `Facility.isOwnedBy()`, `UI-06`, `UI-07` | FR-11, FR-13, FR-14, NFR-04, BR-05 |
| `PAT-01` | Modular Monolith & Layered Architecture | `architecture-design.md` (`ARC-01`, `C4-CNT`, `C4-CMP`), `ADR-001` | CON-01, CON-03, CON-04, NFR-06 |
| `PAT-02` | Repository Pattern | `architecture-design.md` (`C4-CMP`), `class-design.md` (`CLS-08`) | Tách SQL khỏi nghiệp vụ, dễ test |
| `PAT-03` | State-driven Lifecycle | `HoldStatus`, `BookingStatus`, `UI-06`, `UI-07`, `UI-09`, `UI-10`, `STM-01`..`03` | FR-14, FR-15, FR-16, FR-28, BR-09 |
| `PAT-04` | Atomic Transaction & Concurrency Control *(chốt Transaction; Lock/Unique chờ `#10`)* | `BookingService.createHold/confirm`, `OwnerScheduleService`, `ADR-002` | FR-13, FR-29, NFR-02, BR-05 |
| `PAT-05` | Hybrid Expiry (Lazy Check + Worker — *mục tiêu `NFR-03` cần đo*) | `Hold Expiry Worker` (`3.1.1`), `SlotHold.isExpired` (`CLS-04`), `SEQ-02B` | FR-14, FR-25, FR-26, NFR-03 |

---

## 4. Các Mẫu & Thành phần Chủ động Loại trừ (Scope Boundaries)

Để tuân thủ chặt chẽ phạm vi của tài liệu PA2 (`CON-05`, `BR-15`) và đảm bảo tính khả thi trong 10 tuần (`CON-03`), thiết kế **chủ động không áp dụng** các mẫu/thành phần sau:

| Thành phần / Mẫu loại trừ | Lý do loại trừ & Bằng chứng tuân thủ PA2 |
|---|---|
| **Payment Gateway Adapter** (VNPay/MoMo Strategy) | PA2 loại trừ thanh toán trực tuyến/đặt cọc (`BR-15`); tiền sân do Người chơi và Chủ sân tự thỏa thuận ngoài hệ thống. |
| **Email / SMS Notification Strategy** | PA2 chỉ yêu cầu thông báo In-app (`CLS-07`, `Notification`, `NFR-09`), không gửi Email hay SMS bên thứ ba. |
| **Microservices & Event Bus / Redis** | Quy mô 50 người dùng đồng thời (`NFR-06`) và 4 thành viên / 10 tuần phù hợp với Modular Monolith + PostgreSQL ACID (`PAT-01`, `PAT-04`, `PAT-05`). |
| **GoF State Class Hierarchy** | Vòng đời `HoldStatus` và `BookingStatus` chỉ có 3–4 trạng thái cố định, dùng Enum + guard methods trên Entity gọn hơn (`PAT-03`). |

---

## 5. Thông tin gửi kèm Review (Theo Working Agreement Mục 5.3)

- **Danh sách sản phẩm:** `docs/design/principles-patterns.md` (Mã đối tượng: `PRI-01`..`PRI-05`, `PAT-01`..`PAT-05`, `PAT-MAP`).
- **Kết quả tự kiểm tra:**
  - [x] Mọi nguyên tắc và pattern đều có bằng chứng dẫn chiếu trực tiếp đến `3.1.1`, `3.3.2`, `3.2.1` và các quyết định của nhóm (`OVW-01`, `ADR-001`..`003`, `STM-01`..`03`, `SEQ-01`..`05`).
  - [x] Có phân tích Trade-off và phần loại trừ phạm vi theo baseline PA2.
- **Điểm cần người kiểm tra xác nhận:**
  - `@nmt1206` (Trí — đầu mối dữ liệu `#10`): xác nhận phương án chống đặt trùng chi tiết (khóa dòng hoặc ràng buộc duy nhất) trong `#10` để hoàn tất `PAT-04`.
  - `@buikhoa130406` (Khoa): cập nhật `ADR-002` sau khi cơ chế ở `#10` được thống nhất, đối chiếu phạm vi thử kết nối `#7`, và xác nhận lập luận/bằng chứng `PRI-*`, `PAT-*` đủ căn cứ chốt hồ sơ PA3 (`3.2.3`, `3.2.4`).
