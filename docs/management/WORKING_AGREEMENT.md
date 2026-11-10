# Quy tắc nhận task, thực hiện và review

**Thống nhất ngày 10/11/2026 — áp dụng từ PA3.** Dùng tiếp cho giai đoạn sau cho đến khi nhóm thống nhất thay đổi. Đây là quy tắc làm việc; phân công từng đầu việc nằm trong Issue và [Hướng dẫn PA3](../design/README.md).

## 1. Người chịu trách nhiệm chính

Mỗi task có một người chính, được gán Assignee trong Issue. Người này phải:
1. Tự đọc đầu vào, hiểu phạm vi và tiêu chí hoàn thành; không chờ người khác diễn giải toàn bộ.
2. Tự nghiên cứu, xây phương án, lựa chọn cách thực hiện và giải thích lý do.
3. Tự quyết chi tiết trong phạm vi task, phù hợp baseline và giao tiếp đã thống nhất.
4. Tạo bản hoàn chỉnh đầu tiên: nội dung, sơ đồ, đặc tả và giải thích cần thiết.
5. Tự kiểm tra sản phẩm với tiêu chí trước khi gửi review.
6. Tự sửa, phản hồi từng nhận xét và bàn giao bản cuối có link bằng chứng.
7. Tự trình bày và giải thích được sản phẩm, kể cả khi dùng AI hoặc tài liệu tham khảo.

Gửi nháp, hỏi ý kiến hoặc nhận góp ý chưa được tính là hoàn thành. Assignee không chỉ đứng tên hoặc chuyển việc phân tích, lựa chọn và tạo sản phẩm sang người khác.

## 2. Người kiểm tra sản phẩm

Người kiểm tra được ghi trong mô tả Issue, với phạm vi cụ thể. Người kiểm tra:
- Đọc bản bàn giao; đối chiếu yêu cầu, tiêu chí hoàn thành và thiết kế liên quan.
- Chỉ ra vị trí, lỗi, điểm thiếu, mâu thuẫn hoặc quyết định chưa có căn cứ; nêu điều kiện để chấp nhận.
- Kiểm tra lại nội dung đã sửa và ghi kết luận trong phạm vi mình.

Người kiểm tra không mặc định phải hướng dẫn từng bước suốt quá trình, nhắc từng việc nhỏ, chọn thay toàn bộ phương án, vẽ lại sơ đồ, viết lại đặc tả hoặc sửa toàn bộ sản phẩm. Nhận xét review không chuyển quyền sở hữu task.

Nếu người khác trực tiếp tạo hoặc viết lại phần đáng kể, đó là tham gia thực hiện. Ghi rõ phần việc, tác giả và thay đổi phân công/đóng góp trong Issue; không gọi chung là hỗ trợ review. Khoa điều phối việc phân công lại, không tự gán toàn bộ công sức về người đứng tên ban đầu.

## 3. Quyền tự quyết và giới hạn

| Tình huống | Trách nhiệm |
|---|---|
| Thiếu đầu vào từ task khác | Nêu đúng dữ liệu/thao tác/phiên bản cần nhận. Chủ đầu vào chịu trách nhiệm cung cấp sản phẩm thuộc task mình. |
| Lựa chọn thuộc task mình | Tự nghiên cứu, đề xuất và chọn phương án có lý do; đưa vào sản phẩm để kiểm tra. |
| Thay đổi yêu cầu, stack, giao tiếp hoặc quyết định ảnh hưởng nhiều task | Nêu phương án và tác động; thống nhất với chủ các phần liên quan, Khoa ghi nhận và Trí kiểm tra nếu ảnh hưởng nghiệp vụ trước khi áp dụng. |
| Người kiểm tra phát hiện sai | Chủ task tự phân tích và sửa. Nếu bất đồng, nêu căn cứ và phương án trong Issue; điều phối để thống nhất, không tự bỏ qua nhận xét. |

Ví dụ: chủ task dữ liệu phải tự đề xuất cơ chế chống trùng slot và tính nguyên tử. Reviewer phản biện mức đáp ứng; không chọn và thiết kế toàn bộ thay. Không được thay quy tắc giữ toàn bộ hoặc không giữ slot nào chỉ để làm schema dễ hơn.

Giữ baseline PA2 đã nộp. Thay đổi mới ghi ở PA3 cùng lý do và ảnh hưởng. Màn hình tham khảo có thanh toán không làm thanh toán trở thành yêu cầu được chốt.

## 4. Yêu cầu làm rõ và báo vướng mắc

Trao đổi theo cấu trúc:
> Phần đang làm → đã đọc/thử gì → các phương án → phương án đề xuất và lý do → đúng điểm cần xác nhận.

Hỏi sớm khi thiếu đầu vào hoặc có mâu thuẫn; không chờ tới hạn mới báo. Không giới hạn việc làm rõ cần thiết, nhưng câu hỏi không thay thế trách nhiệm tự nghiên cứu và tạo phương án. Bất đồng/điểm chặn phải được lưu trong Issue; kết luận trao đổi ngoài GitHub cần được người phụ trách ghi lại.

## 5. Bàn giao và review

1. Chủ task tự làm phương án ban đầu. Với task có phụ thuộc, gửi bản phác có lựa chọn cụ thể để thống nhất giao tiếp; đây chưa phải review hoàn thành.
2. Chủ task tạo bản đầy đủ và tự kiểm tra.
3. Gửi yêu cầu review với: link phiên bản/PR, danh sách sản phẩm, kết quả tự kiểm tra, các quyết định và điểm còn mở.
4. Người kiểm tra ghi nhận xét tập trung, chỉ rõ vị trí, vấn đề và điều kiện chấp nhận.
5. Chủ task tự sửa và trả lời từng nhận xét: đã sửa ở đâu, bằng chứng nào, hoặc căn cứ nếu chưa đồng ý.
6. Người kiểm tra kiểm tra lại và xác nhận mức đạt. Có mâu thuẫn lớn thì tiếp tục xử lý, không áp số vòng cứng.

Các phần Khoa tạo phải có Trí hoặc Vĩ kiểm tra; Khoa không tự nghiệm thu toàn bộ. Người tổng hợp trả phần thiếu về chủ task, không âm thầm làm thay.

## 6. Dùng Issue, Project và Pull Request

- **Issue:** hồ sơ chính của đầu việc: phạm vi, quyền quyết định, người chính, người kiểm tra, đầu vào, đầu ra, tiêu chí, tiến độ, trao đổi và bằng chứng.
- **Project:** theo dõi trạng thái và trường quản lý của chính Issue đó. Không tạo thêm draft trùng để quản lý một việc ở hai nơi.
- **Pull Request:** bàn giao thay đổi tài liệu/code vào repo và review trực tiếp trên sản phẩm. Ghi link Issue liên quan; chỉ dùng tự đóng Issue khi PR thực sự hoàn tất toàn bộ tiêu chí.
- Mỗi người làm trên nhánh riêng bằng tài khoản cá nhân; commit rõ nội dung; đưa thay đổi qua PR và ít nhất một người khác review theo quy ước nhóm. Không push trực tiếp main.
- Review trên PR và review thiết kế bổ sung cho nhau. PR được merge không mặc nhiên chứng minh toàn bộ task đạt nếu còn sản phẩm/tiêu chí khác.
- Nhật ký AI cá nhân theo [hướng dẫn AI usage](../ai-usage/README.md); chỉ ghi việc thực tế, không ghi thay người khác khi chưa có thông tin xác nhận.

| Trạng thái Project | Ý nghĩa |
|---|---|
| Backlog | Chưa bắt đầu, hoặc chưa đủ đầu vào để nhận làm. |
| Ready | Đủ đầu vào để nhận làm; chủ task xác nhận có thể bắt đầu. |
| In progress | Đang thực hiện, có cập nhật và sản phẩm dần hình thành. |
| In review | Có bản đầy đủ đã tự kiểm tra và gửi đúng người kiểm tra. |
| Done | Có sản phẩm/bằng chứng, các nhận xét cần thiết đã xử lý và người kiểm tra xác nhận. |

Nếu đang sửa lớn sau review, cập nhật trở lại In progress. Nếu Issue đóng hoặc tự động chuyển Done trước khi đủ tiêu chí, điều chỉnh lại trạng thái và ghi lý do.

## 7. Thời gian, hỗ trợ thực hiện và đóng góp

- Ngày bắt đầu, hạn và giờ công mới PA3 chưa chốt; không suy ra từ ước lượng WBS PA1.
- Các mốc kiểm tra là mốc sản phẩm, chưa phải ngày hạn.
- Nếu không đạt mốc, chủ task báo phần đã làm, link bằng chứng, nguyên nhân và hướng khắc phục. Nhóm quyết định hỗ trợ phần cụ thể hoặc phân công lại, có ghi nhận.
- Theo dõi công sức tự thực hiện và công sức review; số task không quy đổi trực tiếp thành tỷ lệ đóng góp.
- Contribution cuối PA3 dựa trên sản phẩm, lịch sử và công việc thực tế, không mặc định giữ tỷ lệ PA2.

## 8. Cập nhật quy tắc

Đề xuất thay đổi qua PR, ghi lý do và nội dung ảnh hưởng. Sau khi nhóm thống nhất, cập nhật ngày và lịch sử dưới đây; phản ánh thay đổi vào Issue liên quan.

| Ngày | Thay đổi |
|---|---|
| 10/11/2026 | Thống nhất trách nhiệm người chính/người kiểm tra, quyền tự quyết, quy trình bàn giao và sử dụng Issue từ PA3. |
