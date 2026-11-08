# AI Usage Logs

This directory stores each member's record of significant AI use by project assignment (PA). It supports, but does not replace, the AI Usage Log table in the submitted PA document.

## Cấu trúc và tên file

Chọn thư mục phù hợp từ `PA0/` đến `PA5/`. Mỗi thành viên giữ một file Markdown trong thư mục của PA đó, theo mẫu `<mã-số>-<tên-không-dấu>.md`:

- `23127074-khoi.md` — Vương Gia Khôi
- `24127421-khoa.md` — Bùi Nguyễn Đăng Khoa
- `24127569-tri.md` — Nguyễn Minh Trí
- `24127587-vi.md` — Lý Sĩ Vĩ

Tên thư mục PA phản ánh giai đoạn của công việc, không nhất thiết là ngày sử dụng công cụ. Không tạo các file cho người khác khi chưa có thông tin của họ.

## Cách ghi và cập nhật

1. Ghi lại khi có một lần sử dụng AI đáng kể, hoặc tổng hợp định kỳ trong tuần khi còn nhớ rõ. Không cần ghi từng câu hỏi nhỏ.
2. Mỗi mục nêu **công cụ**, **công việc/mục đích**, và **cách thành viên kiểm tra, thay đổi hoặc loại bỏ kết quả**. Ghi ngày hoặc khoảng thời gian nếu biết.
3. Khi PA hoàn tất, thành viên đọc lại và xác nhận bản ghi của mình. Người tổng hợp dùng thông tin đã xác nhận để điền bảng AI Usage Log trong tài liệu PA; nếu một người không dùng AI trong PA, ghi rõ `No AI tools were used` theo template.
4. Mỗi thành viên commit bản ghi của mình bằng tài khoản GitHub cá nhân. Thực hiện qua nhánh làm việc và pull request theo quy ước của nhóm; commit chưa được merge chưa có trong `main`.
5. Gắn link task, tài liệu hoặc PR khi có và phù hợp. Commit log là bằng chứng người ghi nhật ký, còn bằng chứng đóng góp cần liên kết tới công việc và sản phẩm thực tế.

Thư mục rỗng được giữ bằng `.gitkeep`. Khi có nội dung thật, tạo file của thành viên trong đúng thư mục PA.

## Mẫu ghi một mục

```markdown
## [Ngày hoặc khoảng thời gian, nếu biết] — [Công việc]

- **Công cụ:** [Tên công cụ]
- **Mục đích:** [AI được dùng cho công việc gì]
- **Kiểm tra và chỉnh sửa:** [Thành viên đã đối chiếu, thử, sửa hoặc loại bỏ kết quả như thế nào]
- **Tham chiếu:** [Link task/tài liệu/PR nếu có]
```

Nếu không dùng AI trong toàn bộ PA, ghi một dòng: `No AI tools were used in this PA.` Chỉ ghi điều đã xác nhận; không điền khẳng định này cho người khác khi chưa hỏi.

## Hướng dẫn khi nhờ AI hỗ trợ viết nhật ký

- Đọc yêu cầu của thành viên, file này và nội dung nhật ký hiện có trước khi chỉnh. Chọn đúng PA, đúng người và giữ lại những mục đã ghi; không xóa hoặc viết lại lịch sử nếu chưa được yêu cầu.
- Dựa trên thông tin mà thành viên cung cấp hoặc công việc AI thực sự tham gia và có thể kiểm chứng trong phiên. Không bịa công cụ, ngày, prompt, kết quả, đóng góp hay việc người dùng đã kiểm tra. Nếu thiếu thông tin ảnh hưởng đến tính trung thực, đánh dấu cần thành viên bổ sung hoặc hỏi họ.
- Đề xuất bản ghi ngắn theo mẫu trên. Thành viên có trách nhiệm kiểm tra và xác nhận nội dung trước khi dùng làm khai báo hoặc đưa vào PA.
- Không lưu mật khẩu, token, khóa, dữ liệu cá nhân nhạy cảm, nội dung bí mật hoặc toàn bộ transcript vào repo. Chỉ dẫn link mà nhóm được phép chia sẻ; lưu ý repository có thể được người ngoài xem.
- Không tự tạo commit, push, mở PR hay sửa file của thành viên khác nếu chưa được giao. Những thao tác đó phải theo chỉ dẫn của người dùng và quy trình của nhóm.

## Đối chiếu yêu cầu môn học

Hướng dẫn và template hiện có yêu cầu AI Usage Log trong mỗi PA được chấm; ghi các lần sử dụng AI đáng kể, mục đích và cách kiểm tra hoặc thay đổi đầu ra. Nếu có khác biệt, ưu tiên hướng dẫn môn và template PA mới nhất cùng yêu cầu trực tiếp của giảng viên.
