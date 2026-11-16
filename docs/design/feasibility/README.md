# Thử kết nối React, Express và PostgreSQL

Thử nghiệm cho [Issue #7](https://github.com/buikhoa130406/se-project-t04/issues/7) kiểm tra một luồng đọc và ghi giá của một sân mẫu. React gọi Express qua HTTP. Express đọc và cập nhật bản ghi trong PostgreSQL. Khi tải lại trang, React đọc lại giá qua API.

## Chuẩn bị trong VS Code

1. Dùng Node.js 22.12 trở lên và một máy chủ PostgreSQL đang chạy. Trong pgAdmin hoặc công cụ quản trị PostgreSQL bạn đang dùng, tạo database thử nghiệm `courtconnect_spike`. Nếu đã có database cùng tên dành riêng cho thử nghiệm này, dùng lại database đó. Tài khoản cấu hình bên dưới cần có quyền tạo bảng, đọc và cập nhật trong database thử nghiệm.
2. Mở [thư mục mã thử nghiệm](../../../src/spikes/react-api-postgres/) trong VS Code, rồi chạy các lệnh sau trong terminal PowerShell.

   ```powershell
   npm.cmd ci
   Copy-Item .env.example .env
   ```

3. Mở `.env` và điền `PGUSER`, `PGPASSWORD` theo tài khoản PostgreSQL của bạn. Chỉnh `PGHOST` và `PGPORT` nếu máy chủ dùng địa chỉ hoặc cổng khác. `.env.example` dùng PostgreSQL local ở cổng 5432. File `.env` được Git bỏ qua.
4. Tạo bảng và sân mẫu. Giá ban đầu là **80.000 đồng** trên database mới. Chạy lại lệnh này sẽ giữ giá đã lưu.

   ```powershell
   npm.cmd run db:init
   ```

## Chạy và kiểm tra

Giữ hai terminal mở trong cùng thư mục mã thử nghiệm.

| Terminal | Lệnh |
|---|---|
| Express, cổng 3001 | `npm.cmd run dev:api` |
| React qua Vite, cổng 5173 | `npm.cmd run dev:web` |

1. Mở [màn hình thử nghiệm](http://127.0.0.1:5173). Ghi giá hiển thị trong ô **Giá hiện tại**.
2. Nhập **95.000** dưới dạng `95000` (hoặc một giá khác giá đang hiển thị) và bấm **Lưu giá**. Giao diện phải hiện giá mới và thông báo đã lưu.
3. Tải lại trang. Giá mới phải còn và giao diện hiện **Đã đọc giá từ PostgreSQL**. Có thể mở tab **Network** trong DevTools để thấy yêu cầu cập nhật `PUT` và yêu cầu đọc lại `GET` tại `/api/courts/1/price`.
4. Nếu muốn kiểm tra độc lập trong công cụ quản trị, chạy truy vấn này trên đúng database thử nghiệm.

   ```sql
   SELECT id, name, price_vnd FROM courtconnect_spike_court WHERE id = 1;
   ```

Nếu `db:init` báo lỗi, kiểm tra PostgreSQL đang chạy, tên database, thông tin đăng nhập và quyền tạo bảng. Nếu giao diện báo mất kết nối sau khi đã tạo dữ liệu mẫu, đọc terminal Express và tải lại trang sau khi xử lý lỗi.

## Kết quả và phạm vi

Đã chạy ngày **17/11/2026** trên Windows với Node.js **24.15.0** và PostgreSQL **16.15** trong cơ sở dữ liệu thử nghiệm tạm.

| Kiểm tra | Kết quả quan sát |
|---|---|
| Khởi tạo dữ liệu và đọc qua API | Sân mẫu trả giá **80.000 đồng**. |
| Cập nhật qua API và đối chiếu SQL | Ghi **92.000 đồng**, PostgreSQL trả cùng giá. |
| Nhập giá âm qua API | HTTP **400**, giá lưu vẫn là **92.000 đồng**. |
| Chạy lại lệnh tạo dữ liệu mẫu | Đọc lại vẫn là **92.000 đồng**. |
| Lưu từ React và tải lại trang | Lưu **95.000 đồng**. Sau khi tải lại, React đọc **95.000 đồng** và truy vấn SQL xác nhận cùng kết quả. |
| Kiểm tra build frontend | `npm.cmd run build` thành công. |

Khoa và Vĩ có thể chạy lại theo các bước trên và ghi thời điểm, giá ban đầu, giá sau khi lưu và giá sau khi tải lại.

Thử nghiệm dùng bảng và dữ liệu mẫu riêng. Phạm vi gồm kết nối HTTP, đọc, ghi và giữ giá sau khi tải lại. Kiểm tra phân quyền, tranh chấp đặt sân, thời gian nhả chỗ và tích hợp với schema PA3 được thực hiện riêng.
