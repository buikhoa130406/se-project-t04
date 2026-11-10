# Hướng dẫn thực hiện PA3 — Software Design

**Kế hoạch và phân công thống nhất ngày 10/11/2026.** Trang này là điểm bắt đầu để nhận việc PA3; nội dung chi tiết và tình trạng thực hiện nằm trong từng Issue.

## Bắt đầu nhận task

1. Đọc [Quy tắc nhận task, thực hiện và review](../management/WORKING_AGREEMENT.md).
2. Mở Issue được giao trong bảng bên dưới; đọc phạm vi, quyền quyết định, đầu vào, sản phẩm và tiêu chí hoàn thành.
3. Xác định đầu vào còn thiếu và tự lập phương án. Ghi rõ đề xuất nếu cần thống nhất giao tiếp.
4. Tự tạo bản đầy đủ, tự kiểm tra, gửi review và tự sửa; bàn giao bằng PR/bằng chứng.

- [GitHub Project](https://github.com/users/buikhoa130406/projects/1)
- [Các Issue mở](https://github.com/buikhoa130406/se-project-t04/issues)
- [Baseline PA2 đã nộp](../../pa/PA2/T04-PA2-SoftwareRequirementsSpecification.docx)
- [Kế hoạch PA1 gốc](../../pa/PA1/T04-PA1-ProjectProposal-Plan.docx)
- [Quy định AI log](../ai-usage/README.md)

## Mục tiêu và phạm vi

PA2 chốt hệ thống phải làm gì; PA3 thiết kế cấu trúc, dữ liệu, hành vi, giao tiếp và UI để đáp ứng. Kết quả phải đủ rõ cho triển khai và làm đầu vào liên quan cho kế hoạch kiểm thử PA4; không cần hoàn thành sản phẩm production ở PA3.

Giữ baseline PA2. Yêu cầu đổi sau nộp được ghi trong requirements-changes.md cùng lý do, ảnh hưởng và trạng thái thống nhất. Thanh toán chưa thuộc baseline; màn Figma mở rộng là tham khảo.

## Danh sách task và phân công

Mỗi Issue có một Assignee chính. Người kiểm tra chỉ kiểm tra phạm vi nêu rõ, không mặc định làm thay. Tên người kiểm tra trong bảng là phân công kiểm tra sản phẩm, không phải đồng sở hữu mọi công việc.

| Task / Issue | Người chịu trách nhiệm chính | Phạm vi kiểm tra |
|---|---|---|
| [3.0.1 — Xác định mục tiêu, ràng buộc và đầu vào thiết kế](https://github.com/buikhoa130406/se-project-t04/issues/8) | Trí (`@nmt1206`) | Khoa kiểm tra baseline và phạm vi; Vĩ/Khôi cung cấp ràng buộc kỹ thuật của phần mình. |
| [3.1.1 — Thiết kế kiến trúc và triển khai hệ thống](https://github.com/buikhoa130406/se-project-t04/issues/9) | Vĩ (`@Lysivi2005`) | Khôi kiểm tra khả năng hiện thực; Khoa kiểm tra bao phủ yêu cầu. Không thiết kế kiến trúc thay Vĩ. |
| [3.1.2 — Thiết kế dữ liệu và ràng buộc lịch đặt sân](https://github.com/buikhoa130406/se-project-t04/issues/10) | Khôi (`@KhoiVuong2210`) | Trí kiểm tra quy tắc nghiệp vụ; Vĩ kiểm tra khớp kiến trúc/lớp. Không dựng ERD hoặc chọn toàn bộ cơ chế thay Khôi. |
| [3.1.3 — Ghi nhận các quyết định kiến trúc — ADR](https://github.com/buikhoa130406/se-project-t04/issues/11) | Khoa (`@buikhoa130406`) | Vĩ xác minh kiến trúc; Khôi xác minh dữ liệu/giao tiếp và bằng chứng thử nghiệm. Người kiểm tra không viết ADR thay Khoa. |
| [3.1.4 — Đặc tả giao tiếp frontend–backend và giữa các module](https://github.com/buikhoa130406/se-project-t04/issues/12) | Khôi (`@KhoiVuong2210`) | Vĩ kiểm tra nhu cầu UI/module; Trí kiểm tra validation, quyền và lỗi nghiệp vụ. Không viết đặc tả API thay Khôi. |
| [3.2.1 — Hoàn thiện thiết kế UI/UX và trạng thái giao diện](https://github.com/buikhoa130406/se-project-t04/issues/13) | Vĩ (`@Lysivi2005`) | Trí kiểm tra luồng/ngoại lệ; Khôi kiểm tra dữ liệu và phản hồi API. Không hoàn thiện màn hình thay Vĩ. |
| [3.2.2 — Review thiết kế và chốt baseline PA3](https://github.com/buikhoa130406/se-project-t04/issues/14) | Khoa (`@buikhoa130406`) | Cả nhóm review theo chuyên môn; Trí hoặc Vĩ kiểm tra các phần Khoa soạn. Mỗi người tự sửa sản phẩm mình. |
| [3.2.3 — Cập nhật truy vết và quản lý thay đổi yêu cầu](https://github.com/buikhoa130406/se-project-t04/issues/15) | Khoa (`@buikhoa130406`) | Trí kiểm tra độ bao phủ và thay đổi; chủ các sản phẩm xác nhận ánh xạ của mình. |
| [3.2.4 — Tổng hợp và đóng gói hồ sơ PA3](https://github.com/buikhoa130406/se-project-t04/issues/16) | Khoa (`@buikhoa130406`) | Mỗi người xác nhận nội dung của mình; Trí/Vĩ kiểm tra bản tổng hợp và bố cục. |
| [3.3.1 — Xây dựng domain model](https://github.com/buikhoa130406/se-project-t04/issues/17) | Trí (`@nmt1206`) | Khôi đối chiếu dữ liệu; Vĩ kiểm tra ánh xạ sang lớp. Không dựng domain model thay Trí. |
| [3.3.2 — Thiết kế lớp và đặc tả các lớp quan trọng](https://github.com/buikhoa130406/se-project-t04/issues/18) | Vĩ (`@Lysivi2005`) | Khôi kiểm tra hiện thực/kiểu dữ liệu/thao tác; Trí kiểm tra trách nhiệm nghiệp vụ. Không xây cấu trúc lớp thay Vĩ. |
| [3.3.3 — Thiết kế sequence cho các use case trọng yếu](https://github.com/buikhoa130406/se-project-t04/issues/19) | Trí (`@nmt1206`) | Vĩ kiểm tra thao tác lớp; Khôi kiểm tra API/giao dịch/xung đột. Không dựng sequence thay Trí. |
| [3.3.4 — Thiết kế vòng đời và chuyển trạng thái](https://github.com/buikhoa130406/se-project-t04/issues/20) | Trí (`@nmt1206`) | Khôi kiểm tra tác động dữ liệu; Vĩ kiểm tra lớp/UI. Không quyết định vòng đời thay Trí. |
| [3.3.5 — Giải thích nguyên tắc và mẫu thiết kế áp dụng](https://github.com/buikhoa130406/se-project-t04/issues/21) | Vĩ (`@Lysivi2005`) | Khôi kiểm tra khả năng hiện thực; Khoa kiểm tra lập luận/bằng chứng. Không chọn pattern thay Vĩ. |
| [2.3.1 — React–API–PostgreSQL, chuyển tiếp từ PA2](https://github.com/buikhoa130406/se-project-t04/issues/7) | Khôi (`@KhoiVuong2210`) | Vĩ kiểm tra cấu trúc/kết quả cho thiết kế; Khoa kiểm tra hướng dẫn và bằng chứng. |

**Tổng: 14 task PA3 và 1 task chuyển tiếp.** Vĩ 4 task thiết kế; Trí 4 task; Khoa 4 task; Khôi 2 task thiết kế và 1 task chuyển tiếp. Đây là số đầu việc, không phải tỷ lệ khối lượng/đóng góp.

## Thay đổi so với WBS PA1

- Giữ các mã 3.1.1, 3.1.2, 3.1.3, 3.2.1, 3.2.2, làm rõ phạm vi và phân công lại theo bảng.
- Bổ sung 3.0.1, 3.1.4, 3.2.3, 3.2.4, 3.3.1–3.3.5 để bao phủ mục tiêu, hướng đối tượng, giao tiếp, truy vết và đóng gói.
- 3.1.4 là phần làm rõ hợp đồng giao tiếp phục vụ triển khai; template không có heading API riêng.
- Tách việc soạn truy vết khỏi task review; giữ các sản phẩm đó liên kết với nhau.
- Không sửa lại PA1/PA2 đã nộp. Ước lượng 36 giờ PA3 trong PA1 không được mặc định áp cho phạm vi mới.

## Trình tự và phụ thuộc

1. **Đầu vào:** Trí làm 3.0.1, Khoa đối chiếu baseline; Khôi bắt đầu 2.3.1 song song.
2. **Khung chung:** Vĩ phác 3.1.1; Trí làm 3.3.1; Khôi phác 3.1.2/3.1.4 khi có đầu vào.
3. **Thiết kế chi tiết:** Vĩ hoàn thiện lớp/UI; Khôi dữ liệu/API; Trí sequence/state. Thống nhất các giao tiếp qua bản nháp trước; không chờ mọi Issue đóng mới phối hợp.
4. **Đối chiếu:** đồng bộ kiến trúc–domain–class–ERD–API–sequence–state–UI. Khoa cập nhật ADR và truy vết trong suốt quá trình; Vĩ hoàn thiện nguyên tắc/pattern.
5. **Chốt:** 3.2.2 review, chủ task sửa và kiểm tra lại; 3.2.4 đóng gói phiên bản đã chốt.

Domain model mô tả khái niệm nghiệp vụ; class diagram mô tả phần mềm; ERD mô tả lưu trữ. Sequence mô tả tương tác; state machine mô tả vòng đời. ADR ghi lý do lựa chọn. Các mô hình phải khớp ý nghĩa, không bắt buộc trùng từng đối tượng.

## Các mốc bàn giao của Khôi

| Mốc | Sản phẩm do Khôi tự tạo |
|---|---|
| A | ERD nháp, danh sách API nháp, kế hoạch lát cắt thử. |
| B | React gọi API, API đọc/ghi PostgreSQL; source, hướng dẫn và kết quả chạy thực tế. |
| C | Đặc tả dữ liệu/ràng buộc/index và giao tiếp/validation/lỗi cho 3.1.2 và 3.1.4. |
| D | Bản sửa sau review và phản hồi từng nhận xét. |

Task 2.3.1 giữ mã và lịch sử cũ, không tính là PA2 hoàn thành. Kiểm chứng concurrency/expiry nếu cần được ghi riêng trong phần thiết kế; không âm thầm mở rộng task thử kết nối thành toàn bộ booking production. Bằng chứng trở ngại phải được ghi nhận nhưng chưa đủ điều kiện Done nếu chưa đạt mục tiêu thử nghiệm.

## Nghiệp vụ phải kiểm tra xuyên suốt thiết kế

- Chọn slot không tạo hold; Proceed to booking chỉ tạo hold sau đăng nhập và kiểm tra toàn bộ lựa chọn.
- Một booking nhiều sân/slot trong một cơ sở; từng sân có các slot liên tiếp 30 phút. Nếu có một slot không hợp lệ thì không giữ slot nào; tranh cùng slot chỉ một yêu cầu lấy hold.
- Hold tối đa 5 phút, không gia hạn khi reload; từ chối xác nhận ngay khi hết hạn và hoàn tất giải phóng trong 5 giây; giao diện có xử lý thất bại.
- Kiểm tra lại hold/quyền/sẵn có khi confirm; booking hợp lệ tự xác nhận, không chờ chủ sân duyệt.
- Người chơi được hủy toàn bộ booking khi còn ít nhất 3 giờ tới giờ bắt đầu sớm nhất; đúng 3 giờ được phép.
- Chủ sân thay lịch: chờ hold bị ảnh hưởng kết thúc, thử lại và kiểm tra lại; mốc 24 giờ, cảnh báo booking bị ảnh hưởng, hủy toàn bộ booking và thông báo trong app.
- Booking trực tiếp dùng chung lịch và cơ chế hold/confirm; miễn giới hạn đặt trước của người chơi, không đè hold/booking.
- Quyền sở hữu kiểm tra ở backend; mật khẩu không lưu plaintext; thiết kế đáp ứng NFR hiệu năng, tương thích và cập nhật dữ liệu của PA2.

## Mức sản phẩm tối thiểu theo template

- Architecture: style có lý do, C4 Context/Container, Component, Deployment; ít nhất 3 ADR.
- OOD: domain/class, đặc tả 6–8 lớp; sequence 3–5 use case có alt; state machine và nguyên tắc/pattern có bằng chứng.
- Sequence: đề xuất làm đủ UC-05, UC-06, UC-08, UC-11, UC-13; nêu phần dùng chung và khác biệt UC-12.
- Data: ERD, đặc tả bảng/cột/ràng buộc; tối thiểu 3NF hoặc giải thích ngoại lệ; index gắn truy vấn.
- UI: screen list/flow, 5–6 màn quan trọng có ảnh/control/event/validation; màn khác có ảnh; accessibility.
- Truy vết yêu cầu–thiết kế, thay đổi từ PA2, review, contribution và AI log.

## Nơi bàn giao

| Sản phẩm | Vị trí dự kiến |
|---|---|
| Overview | `docs/design/design-overview.md` |
| Kiến trúc | `docs/design/architecture/` |
| Domain / class / sequence / state | `docs/design/domain/`, `classes/`, `sequences/`, `states/` |
| Dữ liệu / giao tiếp | `docs/design/data/`, `interfaces/` |
| ADR / UI / review | `docs/design/adr/`, `ui/`, `review/` |
| Nguyên tắc/pattern | `docs/design/principles-patterns.md` |
| Truy vết / thay đổi | `docs/design/traceability.md`, `requirements-changes.md` |
| Thử nghiệm | `src/spikes/react-api-postgres/`; hướng dẫn ở `docs/design/feasibility/` |
| AI log cá nhân | `docs/ai-usage/PA3/` theo hướng dẫn chung |
| Bản nộp | `pa/PA3/` — PDF, source và tham chiếu nguồn sơ đồ |

Các thư mục trên là vị trí bàn giao dự kiến, không có nghĩa sản phẩm đã tồn tại hoặc task đã bắt đầu. Giữ nguồn chỉnh sửa được cùng ảnh xuất của sơ đồ; mỗi file có mã đối tượng để truy vết. Nếu đổi đường dẫn, cập nhật Issue và liên kết liên quan.

## Lịch và trạng thái

Ngày bắt đầu, deadline và giờ công mới chưa chốt. Các Issue mới để Backlog; chỉ cập nhật theo công việc thực tế. Không tự tính điểm đóng góp từ số task hoặc tỷ lệ PA2. Dùng thông tin Project cho trạng thái hiện thời, không coi trang kế hoạch này là báo cáo hoàn thành.
