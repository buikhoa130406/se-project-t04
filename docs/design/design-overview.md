# 2.1 Mục tiêu và ràng buộc thiết kế (3.0.1)

- **Mã đối tượng truy vết:** `OVW-01` (gồm các mục tiêu `ASR-G1`..`ASR-G9`, ràng buộc `CON-01`..`CON-05`, đầu vào `IN-01`..`IN-10` và giả định `ASM-01`..`ASM-09`)
- **Issue liên quan:** `#8` — 3.0.1 Xác định mục tiêu, ràng buộc và đầu vào thiết kế
- **Người chịu trách nhiệm chính:** Nguyễn Minh Trí (`@nmt1206`)
- **Người kiểm tra:** Khoa (`@buikhoa130406` — kiểm tra baseline và phạm vi); Vĩ (`@Lysivi2005`) & Khôi (`@KhoiVuong2210` — cung cấp/xác nhận ràng buộc kỹ thuật).

---

## 1. Các yêu cầu có ảnh hưởng lớn đến kiến trúc (`OVW-ASR`)

Thiết kế được định hình bởi các yêu cầu dưới đây. Đây là các yêu cầu có ảnh hưởng lớn đến kiến trúc (ASR) lấy từ PA2: những yêu cầu quyết định cách tổ chức việc đặt sân, giữ chỗ (hold) và lịch chung. Các yêu cầu còn lại được xử lý bằng thiết kế thông thường nên không liệt kê ở đây. Cột "Tác động thiết kế" nêu **yêu cầu đối với thiết kế**; cơ chế cụ thể thuộc quyền quyết định của chủ task tương ứng (3.1.1, 3.1.2, 3.1.4).

| Mã truy vết | Yêu cầu | Nguồn PA2 | Tác động thiết kế |
| :--- | :--- | :--- | :--- |
| **`ASR-G1`** | Không có hai booking đã xác nhận cùng chiếm một sân và một slot. Khi hai yêu cầu cùng tranh một slot, chỉ một yêu cầu giữ được chỗ. Khi xác nhận, hold và slot được kiểm tra lại trước khi tạo booking. | NFR-02, FR-11, FR-13, BR-02, AC-18 | Kiểm tra xung đột và ghi hold phải là **một thao tác nguyên tử** (một transaction, tất cả hoặc không có gì). Việc kiểm tra lại hold và slot khi xác nhận (FR-11) cũng nằm trong transaction tạo booking. Cơ chế chống trùng cụ thể (ràng buộc dữ liệu, khóa, mức cô lập) do task 3.1.2 chọn. |
| **`ASR-G2`** | Hold kéo dài tối đa 5 phút, không gia hạn. Hết hạn thì từ chối xác nhận ngay và nhả slot trong 5 giây. Thời gian còn lại vẫn đúng khi tải lại trang; đóng tab hoặc mất kết nối sẽ cố gắng phát hiện sớm để nhả, nếu không sẽ nhả khi hết hạn. | NFR-03, FR-14, FR-25, FR-26, FR-31, BR-01, BR-07 | Server lưu `expiresAt` và tính đếm ngược theo giờ server. Việc từ chối xác nhận dựa trên `now >= expiresAt`, không phụ thuộc tác vụ nhả đã chạy hay chưa. Một tác vụ nền định kỳ nhả các hold hết hạn trong vòng 5 giây. |
| **`ASR-G3`** | Chọn slot chưa tạo hold. Khi bấm `Proceed to booking`, toàn bộ lựa chọn (cùng một cơ sở, các slot 30 phút liên tiếp trên từng sân, người chơi phải đặt trước ít nhất 2 slot tức 60 phút, chủ sân đặt tại quầy được miễn) được kiểm tra lại. Nếu có phần nào không hợp lệ thì không giữ slot nào. | FR-09, FR-10, FR-13, FR-21, FR-27, FR-32, BR-03, BR-04, BR-05, BR-08 | Tạo hold theo kiểu tất cả hoặc không có gì (All-or-Nothing). Luật lựa chọn nằm ở logic lịch tại backend (`ScheduleService`), không chỉ ở giao diện; việc kiểm tra xung đột slot nằm **trong** transaction ghi hold. |
| **`ASR-G4`** | Khách (guest) được xem sân và chọn thử slot nhưng phải đăng nhập khi bấm `Proceed to booking` (không tạo hold, đăng nhập xong về trang chủ chọn lại). Người chơi quản lý booking của mình; chủ sân chỉ quản lý cơ sở do mình tạo (không ủy quyền). | NFR-04, FR-01, FR-02, FR-03, FR-23, FR-24, BR-10, BR-14 | Kiểm tra xác thực và vai trò ở mọi API cần bảo vệ, kèm kiểm tra quyền sở hữu cơ sở và booking tại backend. |
| **`ASR-G5`** | Booking đặt trên ứng dụng, booking chủ sân nhập tại quầy và khoảng thời gian bị khóa dùng chung một lịch. | FR-21, FR-22, BR-13, NFR-08 | Một mô hình tình trạng sân và một cách kiểm tra xung đột dùng chung cho cả ba nguồn; thay đổi hiển thị ngay ở lần tải kế tiếp. |
| **`ASR-G6`** | Người chơi chỉ được hủy toàn bộ booking khi còn ít nhất 3 giờ trước giờ bắt đầu sớm nhất (đúng 3 giờ vẫn được). Thay đổi của chủ sân làm mất slot (khóa slot, xóa sân, đổi giờ hoạt động): khoảng khóa phải bắt đầu sau ít nhất 24 giờ; chủ sân phải **chờ các hold bị ảnh hưởng kết thúc hoặc được xác nhận, sau đó thử lại và kiểm tra lại**. Mốc 24 giờ được tính từ **giờ bắt đầu sớm nhất của từng booking bị ảnh hưởng**: nếu có một booking còn dưới 24 giờ thì từ chối cả thay đổi, còn đúng 24 giờ vẫn được phép. Sau đó cảnh báo, hủy toàn bộ booking bị ảnh hưởng và tạo thông báo trong ứng dụng. | FR-18, FR-20, FR-28, FR-29, FR-30, BR-09, BR-11, BR-12 | Kiểm tra mốc 3 giờ cho thao tác hủy của người chơi. Với thay đổi lịch của chủ sân, dùng luồng hai bước: xem trước tác động, sau đó xác nhận. Khi áp dụng phải kiểm tra lại (hold, mốc 24 giờ và danh sách booking bị ảnh hưởng), rồi hủy booking, ghi thay đổi lịch và tạo thông báo **trong cùng một transaction**. Luật 24 giờ và luật chờ hold nằm ở logic lịch. |
| **`ASR-G7`** | Tìm kiếm cơ sở và hiển thị slot phải phản hồi trong 2 giây (phân vị 95) với 50 người dùng đồng thời; người chơi mới hoàn tất tìm kiếm và đặt sân trong 3 phút. | NFR-06, NFR-07, FR-04..08 | Đánh chỉ mục cơ sở dữ liệu cho tìm kiếm cơ sở (môn thể thao, khu vực, tiện ích) và truy vấn slot theo sân và ngày; tối giản số bước đặt sân. |
| **`ASR-G8`** | Hệ thống chạy trên Chrome và Safari hiện hành, dùng được trên điện thoại lẫn máy tính. | NFR-01 | Frontend web responsive; backend cung cấp REST API riêng. |
| **`ASR-G9`** | Mật khẩu chỉ lưu dạng băm (hash). Thông báo chỉ hiển thị trong ứng dụng, không gửi email hay SMS. | NFR-05, NFR-09, BR-16 | Băm mật khẩu trong dịch vụ xác thực; lưu thông báo vào cơ sở dữ liệu để hiển thị in-app, kiến trúc không có thành phần gửi email hay SMS. |

Đồng hồ dùng cho mọi mốc thời gian (5 phút, 2 slot, 3 giờ, 24 giờ) là **đồng hồ của máy chủ**.

---

## 2. Ràng buộc thiết kế (`OVW-CON`)

| Mã ràng buộc | Loại | Ràng buộc | Nguồn |
| :--- | :--- | :--- | :--- |
| **`CON-01`** | Công nghệ | Frontend dùng React; backend dùng Node.js với Express; cơ sở dữ liệu PostgreSQL; kiểm thử bằng Jest; CI bằng GitHub Actions. | PA2, Mục 3 |
| **`CON-02`** | Môi trường | Ứng dụng web responsive. Ứng dụng và PostgreSQL chạy trên máy chủ Linux trên cloud để nhóm kiểm thử và demo. | PA2, Mục 3 |
| **`CON-03`** | Tiến độ | Quy trình waterfall. PA5 nộp vào cuối tuần 10 và phải tích hợp đủ năm tính năng Must (F01–F05). | PA2, Mục 3 |
| **`CON-04`** | Nhân lực | Bốn thành viên, khoảng 14 giờ mỗi người mỗi tuần. Ngày bắt đầu, hạn và giờ công của PA3 chưa chốt. | PA2, Mục 3; README PA3 |
| **`CON-05`** | Ngoài phạm vi | Không thanh toán hay đặt cọc trực tuyến, không ứng dụng di động native, không email hoặc SMS, không tích hợp hệ thống ngoài, không đánh giá hay chat. | PA2, Mục 2.1, BR-15 |

Ràng buộc kỹ thuật riêng của Vĩ (frontend, UI) và Khôi (API, CSDL, hạ tầng) chưa nhận; sẽ bổ sung `CON-06` trở đi khi có (xem `IN-08`).

---

## 3. Đầu vào thiết kế (`OVW-IN`)

### 3.1 Đã có

| Mã | Đầu vào | Dùng cho |
| :--- | :--- | :--- |
| **`IN-01`** | SRS PA2 đã nộp: FR-01..FR-32, NFR-01..NFR-09, BR-01..BR-16, AC-01..AC-39 | Toàn bộ PA3 |
| **`IN-02`** | SRS PA2: UC-01..UC-13 và đặc tả, màn hình SC-01..SC-12, bảng thuật ngữ | Sequence, state, UI |
| **`IN-03`** | `docs/design/README.md` và `docs/management/WORKING_AGREEMENT.md` | Phạm vi, quy trình, mức sản phẩm tối thiểu |
| **`IN-04`** | Màn hình Figma mở rộng (có thanh toán) | Chỉ tham khảo, không phải yêu cầu (BR-15) |

### 3.2 Chưa có và cách xử lý tạm

| Mã | Đầu vào còn thiếu | Từ | Cách xử lý tạm trong bản này |
| :--- | :--- | :--- | :--- |
| **`IN-05`** | Kiến trúc, thành phần, triển khai (3.1.1) | Vĩ | Sequence dùng các thành phần tạm: Page, Controller, Service, Database |
| **`IN-06`** | Class diagram và thao tác (3.3.2) | Vĩ | Tên Service/operation ở `SEQ-OPS` là tạm; Vĩ đối chiếu khi review |
| **`IN-07`** | ERD, ràng buộc và cơ chế chống trùng slot (3.1.2) | Khôi | Domain model và state machine chỉ nêu **yêu cầu** với dữ liệu; Khôi quyết cơ chế |
| **`IN-08`** | Danh sách API, mã lỗi (3.1.4); ràng buộc kỹ thuật riêng của Vĩ/Khôi | Khôi, Vĩ | Sequence chỉ nêu kết quả nghiệp vụ (ví dụ `SelectionInvalid`, `ConfirmRejected`), không cố định mã HTTP |
| **`IN-09`** | Kết quả thử React–API–PostgreSQL, kiểm chứng concurrency và hết hạn (2.3.1) | Khôi | Mốc "nhả trong 5 giây" ở `ASR-G2` ghi là yêu cầu cần kiểm chứng |
| **`IN-10`** | Xác nhận các giả định `ASM-01`..`ASM-09` | Khoa, Khôi, Vĩ | Xem mục 4 |

---

## 4. Giả định và điểm baseline chưa rõ (`OVW-ASM`)

Các mục dưới đây là chỗ PA2 chưa nói rõ. Thiết kế chọn phương án tạm để không dừng việc; đây là **làm rõ, không thay đổi baseline**. Phần nào về sau được nhóm chấp nhận và làm khác PA2 thì ghi vào `requirements-changes.md`.

| Mã | Điểm chưa rõ | Phương án tạm | Cần xác nhận |
| :--- | :--- | :--- | :--- |
| **`ASM-01`** | Một tài khoản có một hay nhiều vai trò; chọn vai trò khi đăng ký ra sao | Mỗi tài khoản một vai trò (`Player` hoặc `FacilityOwner`), lưu bằng thuộc tính `role` | Khoa, Khôi |
| **`ASM-02`** | Facility hỗ trợ một hay nhiều môn | Một môn, theo bảng thuật ngữ PA2 ("a sport") | Khoa |
| **`ASM-03`** | Không có use case gỡ khóa hay sửa `BlockedPeriod` | Không thiết kế gỡ khóa. Mở rộng giờ hoạt động (FR-18) chỉ làm khả dụng lại slot bị `Unavailable` do ngoài giờ; slot đang nằm trong `BlockedPeriod` vẫn giữ `Unavailable` | Khoa |
| **`ASM-04`** | PA2 không yêu cầu trạng thái "đã đọc" của thông báo, cũng không yêu cầu lưu lý do khóa | Không lưu cả hai. Lý do hủy của chủ sân vẫn có (FR-30) | Khoa, Trí |
| **`ASM-05`** | Cấu trúc giá: một mức mỗi sân hay theo khung giờ | Domain chỉ ghi `Price.amount`; cấu trúc chốt ở 3.1.2 và UI | Khôi, Vĩ |
| **`ASM-06`** | Giờ hoạt động thuộc facility hay court | Mức facility, theo thứ trong tuần | Vĩ, Khôi |
| **`ASM-07`** | PA2 không giới hạn số hold hoạt động của một người | Thiết kế không thêm giới hạn. Nếu nhóm muốn giới hạn thì đó là quy tắc mới, phải ghi `requirements-changes.md` | Khoa, Khôi |
| **`ASM-08`** | Xóa sân đã có lịch sử booking | Giữ được lịch sử booking đã hủy để hiển thị (FR-16); cách lưu do Khôi quyết | Khôi |
| **`ASM-09`** | Booking trực tiếp có lưu thông tin khách không | Không lưu; chỉ ghi nguồn `in-person` và chủ sân là người tạo | Khoa, Trí |

---

## 5. Thay đổi so với baseline PA2 (`OVW-CHG`)

Thiết kế **giữ nguyên toàn bộ baseline PA2 đã nộp**, kể cả phạm vi (thanh toán trực tuyến vẫn ngoài phạm vi theo BR-15; các màn hình Figma mở rộng có thanh toán chỉ giữ vai trò tham khảo). Chưa có thay đổi yêu cầu nào cần ghi vào `requirements-changes.md`.

- **Đề xuất thiết kế về cách biểu diễn booking đã qua (không đổi yêu cầu, chờ đối chiếu):** PA2 để mở tập trạng thái booking. Thiết kế **đề xuất** lưu 3 trạng thái của `Booking` (`Confirmed`, `CancelledByPlayer`, `CancelledByOwner`) và suy ra nhãn hiển thị "Đã hoàn thành" (Completed) khi truy vấn/hiển thị, theo điều kiện `status = Confirmed` và `now >= latestEndTime`. Trong đó `latestEndTime` là giờ kết thúc của slot muộn nhất trong toàn bộ các sân thuộc booking, nên đúng tại giờ kết thúc đó nhãn chuyển thành "Đã hoàn thành". Đề xuất này **chờ đối chiếu** với thiết kế dữ liệu (3.1.2, Khôi), vòng đời booking (`STM-03`, 3.3.4) và giao diện (3.2.1, Vĩ); chưa được coi là thay đổi yêu cầu.

---

## 6. Bảng bao phủ yêu cầu PA2 trong Mục 2.1 (`OVW-TRC`)

Bảng này chỉ liệt kê các mã PA2 **được đề cập trực tiếp** trong cột "Nguồn PA2" của các dòng `ASR-G1`..`ASR-G9` và trong `CON-05`. Truy vết toàn bộ FR, NFR, BR, AC tới các phần thiết kế được cập nhật ở Issue #15 và trong các sản phẩm 3.3.x, không lặp lại ở đây.

| Nhóm yêu cầu PA2 | Mã được đề cập trực tiếp | Mã thiết kế tương ứng tại 2.1 |
| :--- | :--- | :--- |
| **Functional Requirements (FR)** | FR-01..FR-11, FR-13, FR-14, FR-18, FR-20..FR-32 | `ASR-G1`..`ASR-G7` |
| **Non-Functional Requirements (NFR)** | NFR-01..NFR-09 | `ASR-G1`..`ASR-G9`; `CON-01`, `CON-02` |
| **Business Rules (BR)** | BR-01..BR-05, BR-07..BR-16 | `ASR-G1`..`ASR-G6`, `ASR-G9`; `CON-05` |
| **Acceptance Criteria (AC)** | AC-18 | `ASR-G1` |

Ánh xạ cụ thể cho các mã được giữ trong bảng nhưng không phải lúc nào cũng nằm ở cột nguồn của nhóm quen thuộc: FR-11 và BR-02 thuộc `ASR-G1` (kiểm tra lại khi xác nhận và chống trùng slot cùng một cơ chế nguyên tử); FR-18 thuộc `ASR-G6` (đổi giờ hoạt động đi qua quy trình thay đổi lịch của chủ sân, FR-29).

Các mã **không** được đề cập trực tiếp ở 2.1 (ví dụ FR-12, FR-15..FR-17, FR-19, BR-06 và hầu hết AC) được xử lý bằng thiết kế thông thường, truy vết ở 3.3.x và Issue #15 (ví dụ FR-12 và BR-06 ở `SEQ-02`, `STM-03`).

---

## 7. Thông tin gửi kèm Review (Theo Working Agreement Mục 5.3)

- **Danh sách sản phẩm:** `docs/design/design-overview.md` (Mã đối tượng: `OVW-01`, `ASR-G1`..`ASR-G9`, `CON-01`..`CON-05`, `IN-01`..`IN-10`, `ASM-01`..`ASM-09`).
- **Kết quả tự kiểm tra:**
  - [x] Mỗi ASR có nguồn PA2 và tác động thiết kế; các tác động chỉ nêu yêu cầu, không chọn cơ chế thay chủ task khác.
  - [x] Đã nêu đầu vào còn thiếu và cách xử lý tạm (mục 3.2).
  - [x] Đã liệt kê các chỗ PA2 chưa rõ thành giả định có người xác nhận (mục 4).
  - [x] Không đưa thanh toán vào phạm vi thiết kế (BR-15).
  - [ ] Đã đối chiếu lại từng giá trị (5 phút, 5 giây, 2 slot, 3 giờ, 24 giờ) với bản SRS PA2 đã nộp.
- **Các quyết định thiết kế chính:**
  1. Gom các yêu cầu PA2 thành 9 nhóm ASR gắn trực tiếp với yêu cầu thiết kế; bảng bao phủ chỉ liệt kê mã được đề cập trực tiếp, truy vết đầy đủ ở #15.
  2. **Đề xuất** không lưu `Completed` thành trạng thái vật lý của `Booking`, suy ra từ thời gian (`now >= latestEndTime`) để giảm rủi ro đồng bộ trạng thái; chờ đối chiếu với dữ liệu, vòng đời booking và giao diện.
  3. Dùng phương án tạm cho các điểm PA2 chưa rõ (`ASM-01`..`ASM-09`) thay vì dừng việc.
- **Điểm còn mở cần người kiểm tra xác nhận:**
  - `@buikhoa130406`: xác nhận cách gom ASR, bảng bao phủ đã thu hẹp, các giả định `ASM-01`..`ASM-04`, `ASM-07`, `ASM-09` và việc chưa phát sinh thay đổi yêu cầu.
  - `@Lysivi2005` & `@KhoiVuong2210`: xác nhận `ASM-05`, `ASM-06`, `ASM-08`, đề xuất suy ra nhãn "Đã hoàn thành" và cung cấp ràng buộc kỹ thuật riêng (`IN-08`); xác nhận các yêu cầu ở cột "Tác động thiết kế" khớp kiến trúc (3.1.1) và dữ liệu/API (3.1.2, 3.1.4).
