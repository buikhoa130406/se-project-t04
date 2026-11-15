# Giải thích Nguyên tắc và Mẫu Thiết kế Áp dụng (Task 3.3.5 — Issue #21)

- **Người thực hiện:** Lý Sĩ Vĩ (`@Lysivi2005`)
- **Người kiểm tra:** Khôi (`@KhoiVuong2210` — khả năng hiện thực), Khoa (`@buikhoa130406` — lập luận và bằng chứng)
- **Tài liệu liên quan:**
  - Kiến trúc hệ thống (`3.1.1`): `docs/design/architecture/architecture-design.md`
  - Thiết kế lớp (`3.3.2`): `docs/design/classes/class-design.md`
  - Thiết kế UI/UX (`3.2.1`): `docs/design/ui/ui-design-specification.md`
  - Baseline PA2: `pa/PA2/T04-PA2-SoftwareRequirementsSpecification.docx`

---

## 1. Các Nguyên tắc Thiết kế Áp dụng (Design Principles)

### 1.1. [`PRI-01`] Separation of Concerns (Phân tách mối quan tâm)
- **Nội dung nguyên tắc:** Chia hệ thống thành các phần riêng biệt, mỗi phần đảm nhận một nhóm trách nhiệm rõ ràng về giao diện, điều phối nghiệp vụ hoặc lưu trữ dữ liệu.
- **Bằng chứng áp dụng:**
  - Trong `architecture-design.md` (Mục 1 & Mục 4): Hệ thống tách biệt **React SPA** (tầng hiển thị) khỏi **Node.js + Express API** (tầng xử lý) và tổ chức Backend theo 3 lớp `Controller → Service → Repository`, chia thành 5 module độc lập (*Auth, Facility & Search, Booking & Hold, Owner Schedule, In-App Notification*).
  - Trong `class-design.md` (`CLS-04`, `CLS-05`, `CLS-08`): Lớp thực thể chỉ giữ dữ liệu và quy tắc cục bộ của đối tượng (`Booking.canCancelByPlayer()`), còn luồng điều phối giao dịch và kiểm tra chéo nằm ở `BookingService` và `OwnerScheduleService`.
- **Lợi ích & Đáp ứng yêu cầu:** Đảm bảo mọi kiểm tra phân quyền (`NFR-04`), tính hợp lệ 30 phút và mốc 3h/24h được thực thi tập trung ở Backend; Frontend (`ui-design-specification.md`) chỉ tập trung xử lý tương tác và hiển thị trạng thái.

---

### 1.2. [`PRI-02`] Single Responsibility Principle (SRP — Đơn trách nhiệm)
- **Nội dung nguyên tắc:** Mỗi lớp hoặc module chỉ nên có một lý do duy nhất để thay đổi, chịu trách nhiệm cho một khía cạnh nghiệp vụ cụ thể.
- **Bằng chứng áp dụng:**
  - Trong `class-design.md`:
    - `SlotHold` (`CLS-04`) chỉ quản lý vòng đời lượt giữ chỗ 5 phút (`expiresAt`, `isExpired()`, `remainingSeconds()`, `belongsTo()`).
    - `Booking` (`CLS-05`) chỉ đại diện đơn đặt sân đã xác nhận (`canCancelByPlayer()`, `isAffectedUnder24Hours()`).
    - `ScheduleBlock` (`CLS-06`) chỉ quản lý khoảng khóa lịch của chủ sân (`isAtLeast24HoursAhead()`, `overlaps()`).
    - `Notification` (`CLS-07`) chỉ quản lý thông báo In-app (`markAsRead()`).
- **Lợi ích & Đáp ứng yêu cầu:** Tách `SlotHold` khỏi `Booking` giúp tránh trộn lẫn dữ liệu giữ chỗ tạm thời với đơn đặt chính thức, ngăn lỗi rò rỉ lịch ảo khi lượt giữ hết hạn 5 phút (`FR-14`, `NFR-03`).

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
  - **Bộ quy tắc 24 giờ dùng chung cho Chủ sân (`UC-11`, `UC-12`):** `createScheduleBlock`, `updateOperatingHours` và `deleteCourt` cùng sử dụng hai hàm kiểm tra dùng chung `assertNoActiveHoldConflict` và `assertAllAffectedBookingsOver24h` (`FR-29`, `BR-11`).
- **Lợi ích & Đáp ứng yêu cầu:** Đảm bảo không xảy ra tình trạng đặt trực tiếp ghi đè lên giữ chỗ/đơn đã đặt (`BR-13`) và đồng bộ tuyệt đối quy tắc 24 giờ giữa các màn hình quản lý (`UI-13`, `UI-14`, `UI-15`).

---

### 1.5. [`PRI-05`] Fail-Safe Defaults & Least Privilege (Mặc định an toàn & Quyền tối thiểu)
- **Nội dung nguyên tắc:** Khi xảy ra lỗi hoặc không đủ quyền, hệ thống phải từ chối an toàn và không làm thay đổi dữ liệu; người dùng chỉ được cấp quyền đúng với vai trò sở hữu.
- **Bằng chứng áp dụng:**
  - **Quyền tối thiểu:** `Auth & RBAC Middleware` (`3.1.1`) kết hợp `Facility.isOwnedBy(userId)` (`CLS-02`) chặn 100% truy cập trái phép từ Khách/Người chơi hoặc Chủ sân khác (`NFR-04`). `SlotHold.belongsTo(userId)` ngăn xác nhận chéo lượt giữ (`FR-11`).
  - **Mặc định an toàn (*All-or-Nothing*):** Khi tiến hành đặt sân (`UI-06`, `BookingService.createHold`), nếu có dù chỉ 1 khung xung đột thì hủy toàn bộ yêu cầu giữ chỗ (`BR-05`). Khi hết hạn 5 phút trên `UI-07`, giao diện khóa nút Xác nhận ngay và chỉ cho chọn lại sau khi nhả chỗ thành công (`FR-14`).

---

## 2. Các Mẫu Thiết kế Áp dụng (Design Patterns)

### 2.1. [`PAT-01`] Modular Monolith & Layered Architecture (Mẫu Kiến trúc Phân tầng)
- **Vấn đề cần giải quyết:** Nhóm gồm 4 thành viên với thời hạn 10 tuần cần một kiến trúc dễ phát triển và kiểm thử, nhưng vẫn phải đảm bảo giao dịch ACID cho lịch chung và phản hồi $\le 2$ giây cho 50 người dùng đồng thời (`NFR-06`).
- **Cách áp dụng & Bằng chứng:** Tổ chức Backend thành một ứng dụng thống nhất chia module theo miền nghiệp vụ và phân tầng `Controller → Service → Repository` (`architecture-design.md` — Mục 1, Mục 3, Mục 4).
- **Lý do chọn & Đánh đổi (Trade-off):** Chọn *Modular Monolith* thay vì *Microservices* vì Microservices làm phát sinh giao dịch phân tán phức tạp (2-Phase Commit) khi kiểm tra chéo `SlotHold`, `Booking` và `ScheduleBlock`, gây rủi ro trễ hạn môn học và làm giảm độ ổn định của ràng buộc chống trùng slot (`NFR-02`).

---

### 2.2. [`PAT-02`] Repository Pattern (Mẫu Kho lưu trữ dữ liệu)
- **Vấn đề cần giải quyết:** Tách biệt logic nghiệp vụ phức tạp (kiểm tra liên tiếp 30 phút, tính mốc 3h/24h, xử lý hủy đơn hàng loạt) khỏi các thao tác truy vấn PostgreSQL và quản lý Transaction.
- **Cách áp dụng & Bằng chứng:** Định nghĩa các Repository (`BookingRepository`, `HoldRepository`, `ScheduleRepository`, `FacilityRepository`) trong `architecture-design.md` (Mục 4) và làm thuộc tính phụ thuộc của các Service trong `class-design.md` (`CLS-08`).
- **Lý do chọn & Đánh đổi (Trade-off):** Giúp cô lập tầng dữ liệu để kiểm thử độc lập và gom toàn bộ câu lệnh khóa dòng (`SELECT ... FOR UPDATE`) hoặc ràng buộc duy nhất về một nơi duy nhất, dù phải viết thêm lớp interface trung gian.

---

### 2.3. [`PAT-03`] State-driven Lifecycle Pattern (Quản lý vòng đời theo Trạng thái)
- **Vấn đề cần giải quyết:** `SlotHold` và `Booking` chuyển đổi qua nhiều trạng thái theo hành động người dùng và theo thời gian thực (`5 phút`, `3 giờ`, `24 giờ`), đòi hỏi tính nhất quán giữa DB, Service và UI (`UI-06`, `UI-07`, `UI-10`).
- **Cách áp dụng & Bằng chứng:** Chuẩn hóa trạng thái qua Enum (`HoldStatus`: `ACTIVE`, `CONFIRMED`, `RELEASED`, `EXPIRED`; `BookingStatus`: `CONFIRMED`, `CANCELLED_BY_PLAYER`, `CANCELLED_BY_OWNER`) kết hợp các phương thức kiểm tra điều kiện chuyển trạng thái trực tiếp trên Entity (`SlotHold.isExpired()`, `Booking.canCancelByPlayer()`, `Booking.isAffectedUnder24Hours()` trong `class-design.md`).
- **Lý do chọn & Đánh đổi (Trade-off):** Dùng Enum kết hợp *guard methods* trên Entity thay vì tách thành nhiều lớp con `ActiveHoldState`, `ExpiredHoldState` (GoF State class hierarchy) để tránh phình số lượng lớp không cần thiết khi hệ thống chỉ có 3–4 trạng thái cố định, giữ code gọn nhẹ cho nhóm triển khai ở PA5.

---

### 2.4. [`PAT-04`] Atomic Transaction & Pessimistic Locking / Unit of Work
- **Vấn đề cần giải quyết:** Ngăn chặn điều kiện tranh chấp (*race condition*) khi nhiều người cùng bấm *Tiến hành đặt sân* cho cùng một khung giờ (`FR-13`, `NFR-02`), đảm bảo quy tắc *All-or-Nothing* (`BR-05`) và đảm bảo việc chủ sân hủy đơn + tạo thông báo In-app xảy ra đồng bộ (`FR-29`, `FR-30`).
- **Cách áp dụng & Bằng chứng:**
  - Trong `architecture-design.md` (Mục 6) và `class-design.md` (`CLS-08`): Toàn bộ thao tác của `createHold`, `confirmBooking`, `createScheduleBlock` được bọc trong một **PostgreSQL ACID Transaction** tại tầng Repository.
  - Khi tạo Hold hoặc xác nhận, giao dịch khóa các dòng khung giờ liên quan (hoặc dựa vào ràng buộc duy nhất trên `(court_id, slot_start)` của lịch chung) nên tại một thời điểm chỉ **duy nhất 1 yêu cầu** giữ chỗ thành công; nếu có lỗi bất kỳ bước nào, toàn bộ giao dịch được rollback.
- **Lý do chọn & Đánh đổi (Trade-off):** Khóa bi quan / Transaction ACID ở DB đánh đổi một phần nhỏ thông lượng ghi đồng thời nhưng đây là lựa chọn an toàn nhất để bảo đảm tuyệt đối **0 đơn trùng** (`NFR-02`) với quy mô 50 người dùng đồng thời (`NFR-06`).

---

### 2.5. [`PAT-05`] Hybrid Expiry Pattern (Lazy Check + Background Polling Worker)
- **Vấn đề cần giải quyết:** Lượt giữ chỗ chỉ kéo dài tối đa 5 phút, **không tự gia hạn khi tải lại trang (F5)** (`FR-25`), phải từ chối xác nhận ngay tại mốc hết hạn và hoàn tất nhả chỗ trong **tối đa 5 giây** (`FR-14`, `NFR-03`).
- **Cách áp dụng & Bằng chứng:**
  - **Lưu mốc cố định & Lazy Check:** `SlotHold` lưu `expiresAt = createdAt + 5 phút` trên DB (`CLS-04`). Khi F5, Frontend lấy lại `remainingSeconds(now)` từ API (`UI-07`). Khi người chơi bấm *Xác nhận* hoặc hệ thống đọc lịch, `SlotHold.isExpired(now)` kiểm tra tức thì `now >= expiresAt` để từ chối xác nhận ngay tại giây hết hạn mà không phụ thuộc worker đã chạy kịp hay chưa.
  - **Background Polling Worker:** `Hold Expiry Worker` (`3.1.1` C4 Container) gọi `BookingService.releaseExpiredHolds(now)` mỗi 1–2 giây để chuyển các `SlotHold` quá hạn sang `EXPIRED` và mở trống lại trên lịch chung trong $\le 5$ giây.
- **Lý do chọn & Đánh đổi (Trade-off):** Tránh phải dựng thêm Redis TTL hay hệ thống hàng đợi tin nhắn (RabbitMQ/BullMQ) nằm ngoài stack chuẩn PA2, vừa giữ hạ tầng triển khai gọn trên Cloud Linux vừa đảm bảo đúng SLA $\le 5$ giây của `NFR-03`.

---

## 3. Bảng Tổng hợp Truy vết Nguyên tắc & Mẫu Thiết kế

| Mã | Tên Nguyên tắc / Pattern | Bằng chứng Thiết kế Liên quan | Yêu cầu / NFR Đáp ứng |
|---|---|---|---|
| `PRI-01` | Separation of Concerns | `architecture-design.md` (C4 Container/Component), `class-design.md` | FR-01–FR-30, NFR-04 |
| `PRI-02` | Single Responsibility Principle | `CLS-04` (`SlotHold`), `CLS-05` (`Booking`), `CLS-06`, `CLS-07` | FR-10, FR-14, FR-20, FR-30 |
| `PRI-03` | Dependency Inversion Principle | `CLS-08` (`BookingService`, `OwnerScheduleService` & Repositories) | NFR-02, NFR-06 (khả năng test Jest) |
| `PRI-04` | Don't Repeat Yourself (DRY) | `createDirectBooking` dùng lại `BookingService`; bộ kiểm tra 24h | FR-21, FR-29, BR-08, BR-11, BR-13 |
| `PRI-05` | Fail-Safe Defaults & Least Privilege | `Auth & RBAC Middleware`, `Facility.isOwnedBy()`, `UI-06`, `UI-07` | FR-11, FR-13, FR-14, NFR-04, BR-05 |
| `PAT-01` | Modular Monolith & Layered Architecture | `architecture-design.md` (Mục 1, 3, 4, 5) | Ràng buộc 4 người / 10 tuần, NFR-06 |
| `PAT-02` | Repository Pattern | `architecture-design.md` (Component), `class-design.md` (`CLS-08`) | Tách SQL khỏi nghiệp vụ, dễ test |
| `PAT-03` | State-driven Lifecycle | `HoldStatus`, `BookingStatus`, `UI-06`, `UI-07`, `UI-10` | FR-14, FR-16, FR-28, BR-09 |
| `PAT-04` | Atomic Transaction & Pessimistic Locking | `BookingService.createHold/confirm`, `OwnerScheduleService` | FR-13, FR-29, NFR-02, BR-05 |
| `PAT-05` | Hybrid Expiry (Lazy Check + Worker) | `Hold Expiry Worker` (`3.1.1`), `SlotHold.isExpired` (`CLS-04`) | FR-14, FR-25, NFR-03 |

---

## 4. Các Mẫu & Thành phần Chủ động Loại trừ (Scope Boundaries)

Để tuân thủ chặt chẽ phạm vi của tài liệu PA2 và đảm bảo tính khả thi trong 10 tuần, thiết kế **chủ động không áp dụng** các mẫu/thành phần sau:

| Thành phần / Mẫu loại trừ | Lý do loại trừ & Bằng chứng tuân thủ PA2 |
|---|---|
| **Payment Gateway Adapter** (VNPay/MoMo Strategy) | PA2 loại trừ thanh toán trực tuyến/đặt cọc; tiền sân do Người chơi và Chủ sân tự thỏa thuận ngoài hệ thống. |
| **Email / SMS Notification Strategy** | PA2 chỉ yêu cầu thông báo In-app (`CLS-07`, `Notification`), không gửi Email hay SMS bên thứ ba. |
| **Microservices & Event Bus / Redis** | Quy mô 50 người dùng đồng thời (`NFR-06`) và 4 thành viên / 10 tuần phù hợp với Modular Monolith + PostgreSQL ACID (`PAT-01`, `PAT-04`, `PAT-05`). |
| **GoF State Class Hierarchy** | Vòng đời `HoldStatus` và `BookingStatus` chỉ có 3–4 trạng thái cố định, dùng Enum + guard methods trên Entity gọn hơn (`PAT-03`). |
