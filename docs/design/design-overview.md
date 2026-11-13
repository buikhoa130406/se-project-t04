# 2.1 Mục tiêu và ràng buộc thiết kế (3.0.1)

- **Mã đối tượng truy vết:** `OVW-01` (gồm các mục tiêu `ASR-G1`..`ASR-G9` và ràng buộc `CON-01`..`CON-05`)
- **Issue liên quan:** `#8` — 3.0.1 Xác định mục tiêu, ràng buộc và đầu vào thiết kế
- **Người chịu trách nhiệm chính:** Nguyễn Minh Trí (`@nmt1206`)
- **Người kiểm tra:** Khoa (`@buikhoa130406` — kiểm tra baseline và phạm vi); Vĩ (`@Lysivi2005`) & Khôi (`@KhoiVuong2210` — cung cấp/xác nhận ràng buộc kỹ thuật).

---

## 1. Các yêu cầu có ảnh hưởng lớn đến kiến trúc (`OVW-ASR`)

Thiết kế được định hình bởi các yêu cầu dưới đây. Đây là các yêu cầu có ảnh hưởng lớn đến kiến trúc (ASR) lấy từ PA2: những yêu cầu quyết định cách tổ chức việc đặt sân, giữ chỗ (hold) và lịch chung. Các yêu cầu còn lại được xử lý bằng thiết kế thông thường nên không liệt kê ở đây.

| Mã truy vết | Yêu cầu | Nguồn PA2 | Tác động thiết kế |
| :--- | :--- | :--- | :--- |
| **`ASR-G1`** | Không có hai booking đã xác nhận cùng chiếm một sân và một slot. Khi hai yêu cầu cùng tranh một slot, chỉ một yêu cầu giữ được chỗ. | NFR-02, FR-13, AC-18 | Tạo hold và kiểm tra xung đột chạy nguyên tử trong một transaction của cơ sở dữ liệu (ràng buộc unique hoặc khóa dòng trên slot). |
| **`ASR-G2`** | Hold kéo dài tối đa 5 phút, không gia hạn. Hết hạn thì từ chối xác nhận ngay và nhả slot trong 5 giây. Thời gian còn lại vẫn đúng khi tải lại trang; đóng tab hoặc mất kết nối sẽ cố gắng phát hiện sớm để nhả, nếu không sẽ nhả khi hết hạn. | NFR-03, FR-14, FR-25, FR-26, FR-31, BR-01, BR-07 | Server lưu `expiresAt` và tính đếm ngược theo giờ server. Một tác vụ nền (hoặc cơ chế kiểm tra hạn tức thời kết hợp tiến trình dọn dẹp) nhả các hold hết hạn trong vòng 5 giây. |
| **`ASR-G3`** | Chọn slot chưa tạo hold. Khi bấm `Proceed to booking`, toàn bộ lựa chọn (cùng một cơ sở, các slot 30 phút liên tiếp trên từng sân, người chơi phải đặt trước ít nhất 2 slot tức 60 phút, chủ sân đặt tại quầy được miễn) được kiểm tra lại. Nếu có phần nào không hợp lệ thì không giữ slot nào. | FR-09, FR-10, FR-13, FR-21, FR-27, FR-32, BR-03, BR-04, BR-05, BR-08 | Tạo hold theo kiểu tất cả hoặc không có gì (All-or-Nothing) trong một transaction; luật kiểm tra nằm ở logic lịch tại backend, không chỉ nằm ở giao diện. |
| **`ASR-G4`** | Khách (guest) được xem sân và chọn thử slot nhưng phải đăng nhập khi bấm `Proceed to booking` (không tạo hold, đăng nhập xong về trang chủ chọn lại). Người chơi quản lý booking của mình; chủ sân chỉ quản lý cơ sở do mình tạo (không ủy quyền). | NFR-04, FR-01, FR-02, FR-03, FR-23, FR-24, BR-10, BR-14 | Kiểm tra xác thực và vai trò ở mọi API cần bảo vệ, kèm kiểm tra quyền sở hữu cơ sở và booking tại backend. |
| **`ASR-G5`** | Booking đặt trên ứng dụng, booking chủ sân nhập tại quầy và khoảng thời gian bị khóa dùng chung một lịch. | FR-21, FR-22, BR-13, NFR-08 | Một mô hình tình trạng sân và một hàm kiểm tra xung đột dùng chung cho cả ba nguồn; thay đổi hiển thị ngay ở lần tải kế tiếp. |
| **`ASR-G6`** | Người chơi chỉ được hủy toàn bộ booking khi còn ít nhất 3 giờ trước giờ bắt đầu sớm nhất (đúng 3 giờ vẫn được). Thay đổi của chủ sân (khóa slot trước ít nhất 24 giờ, xóa sân, đổi giờ) phải chờ các hold bị ảnh hưởng kết thúc, từ chối toàn bộ nếu có booking bị ảnh hưởng bắt đầu trong dưới 24 giờ, cảnh báo rồi hủy toàn bộ booking bị ảnh hưởng và tạo thông báo trong ứng dụng. | FR-20, FR-28, FR-29, FR-30, BR-09, BR-11, BR-12 | Kiểm tra mốc 3 giờ cho thao tác hủy của người chơi. Với thay đổi lịch của chủ sân, dùng luồng hai bước: xem trước tác động, sau đó xác nhận và kiểm tra lại trước khi áp dụng; hủy toàn bộ booking và tạo thông báo trong cùng một transaction. |
| **`ASR-G7`** | Tìm kiếm cơ sở và hiển thị slot phải phản hồi trong 2 giây (phân vị 95) với 50 người dùng đồng thời; người chơi mới hoàn tất tìm kiếm và đặt sân trong 3 phút. | NFR-06, NFR-07, FR-04..08 | Đánh chỉ mục cơ sở dữ liệu cho tìm kiếm cơ sở (môn thể thao, khu vực, tiện ích) và truy vấn slot theo sân và ngày; tối giản số bước đặt sân. |
| **`ASR-G8`** | Hệ thống chạy trên Chrome và Safari hiện hành, dùng được trên điện thoại lẫn máy tính. | NFR-01 | Frontend web responsive; backend cung cấp REST API riêng. |
| **`ASR-G9`** | Mật khẩu chỉ lưu dạng băm (hash). Thông báo chỉ hiển thị trong ứng dụng, không gửi email hay SMS. | NFR-05, NFR-09, BR-16 | Băm mật khẩu trong dịch vụ xác thực; lưu thông báo vào cơ sở dữ liệu để hiển thị in-app, kiến trúc không có thành phần gửi email hay SMS. |

---

## 2. Ràng buộc thiết kế (`OVW-CON`)

| Mã ràng buộc | Loại | Ràng buộc | Nguồn |
| :--- | :--- | :--- | :--- |
| **`CON-01`** | Công nghệ | Frontend dùng React; backend dùng Node.js với Express; cơ sở dữ liệu PostgreSQL; kiểm thử bằng Jest; CI bằng GitHub Actions. | PA2, Mục 3 |
| **`CON-02`** | Môi trường | Ứng dụng web responsive. Ứng dụng và PostgreSQL chạy trên máy chủ Linux trên cloud để nhóm kiểm thử và demo. | PA2, Mục 3 |
| **`CON-03`** | Tiến độ | Quy trình waterfall. PA5 nộp vào cuối tuần 10 và phải tích hợp đủ năm tính năng Must (F01–F05). | PA2, Mục 3 |
| **`CON-04`** | Nhân lực | Bốn thành viên, khoảng 14 giờ mỗi người mỗi tuần. | PA2, Mục 3 |
| **`CON-05`** | Ngoài phạm vi | Không thanh toán hay đặt cọc trực tuyến, không ứng dụng di động native, không email hoặc SMS, không tích hợp hệ thống ngoài, không đánh giá hay chat. | PA2, Mục 2.1, BR-15 |

---

## 3. Thay đổi so với baseline PA2 (`OVW-CHG`)

Thiết kế **giữ nguyên toàn bộ baseline PA2 đã nộp**, kể cả phạm vi (thanh toán trực tuyến vẫn ngoài phạm vi theo BR-15; các màn hình Figma mở rộng có thanh toán chỉ giữ vai trò tham khảo).

- **Làm rõ cách biểu diễn booking đã qua (không thay đổi yêu cầu hay thêm trạng thái lưu trữ):** Trong PA2, tập trạng thái booking được để mở. Để phân biệt booking sắp tới và booking đã qua trên giao diện mà không cần tác vụ nền cập nhật dữ liệu, cơ sở dữ liệu chỉ lưu 3 trạng thái của `Booking`: `Confirmed`, `CancelledByPlayer` và `CancelledByOwner`. Trạng thái hiển thị "Đã hoàn thành" (Completed) được suy ra trực tiếp khi truy vấn/hiển thị nếu `status = Confirmed` và thời điểm hiện tại đã qua giờ kết thúc của slot muộn nhất trong toàn bộ các sân thuộc booking (`now >= latestEndTime`).

---

## 4. Bảng bao phủ yêu cầu PA2 trong Mục 2.1 (`OVW-TRC`)

| Nhóm yêu cầu PA2 | Mã yêu cầu được bao phủ | Mã thiết kế tương ứng tại 2.1 |
| :--- | :--- | :--- |
| **Functional Requirements (FR)** | FR-01, FR-02, FR-03, FR-04..08, FR-09, FR-10..16, FR-17..22, FR-23..32 | `ASR-G1` .. `ASR-G9` |
| **Non-Functional Requirements (NFR)** | NFR-01, NFR-02, NFR-03, NFR-04, NFR-05, NFR-06, NFR-07, NFR-08, NFR-09 | `ASR-G1` .. `ASR-G9`, `CON-01`, `CON-02` |
| **Business Rules (BR)** | BR-01 .. BR-16 | `ASR-G1` .. `ASR-G9`, `CON-05` |
| **Acceptance Criteria (AC)** | AC-01 .. AC-39 | Làm tiêu chí kiểm chứng trực tiếp cho các mục tiêu `ASR-G1` .. `ASR-G9` |

---

## 5. Thông tin gửi kèm Review (Theo Working Agreement Mục 5.3)

- **Danh sách sản phẩm:** `docs/design/design-overview.md` (Mã đối tượng: `OVW-01`, `ASR-G1`..`ASR-G9`, `CON-01`..`CON-05`).
- **Kết quả tự kiểm tra:**
  - [x] Đã bao phủ toàn bộ 8 quy tắc nghiệp vụ cốt lõi nêu trong `docs/design/README.md`.
  - [x] Đã bao phủ toàn bộ NFR-01..NFR-09 và ràng buộc công nghệ/phạm vi của PA2.
  - [x] Không tự ý đưa tính năng thanh toán vào phạm vi thiết kế (tuân thủ BR-15).
- **Các quyết định thiết kế chính:**
  1. Gom các yêu cầu PA2 thành 9 nhóm ASR (`ASR-G1`..`ASR-G9`) gắn trực tiếp với giải pháp kiến trúc/dữ liệu.
  2. Không lưu `Completed` thành trạng thái vật lý trong bảng `Booking` mà suy ra từ thời gian kết thúc của slot muộn nhất (`now >= latestEndTime`), giúp giảm rủi ro đồng bộ trạng thái.
- **Điểm còn mở cần người kiểm tra xác nhận:**
  - `@buikhoa130406`: Xác nhận cách gom nhóm ASR và việc không phát sinh thay đổi yêu cầu trong `requirements-changes.md`.
  - `@Lysivi2005` & `@KhoiVuong2210`: Xác nhận các tác động thiết kế tại cột cuối bảng `ASR-G1`..`ASR-G9` khớp với kiến trúc (3.1.1) và cơ chế khóa dữ liệu/API (3.1.2, 3.1.4).