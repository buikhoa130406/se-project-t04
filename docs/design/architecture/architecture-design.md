# Thiết kế Kiến trúc và Triển khai Hệ thống (Task 3.1.1 — Issue #9)

- **Người thực hiện:** Lý Sĩ Vĩ (`@Lysivi2005`)
- **Người kiểm tra:** Khôi (`@KhoiVuong2210` — khả năng hiện thực), Khoa (`@buikhoa130406` — độ bao phủ yêu cầu)
- **Tài liệu đầu vào:** Baseline PA2 (`T04-PA2-SoftwareRequirementsSpecification.docx`), `docs/design/README.md`

---

## 1. Kiến trúc tổng thể (Architecture Style) & Lý do lựa chọn

Hệ thống **T04 CourtConnect** áp dụng mô hình **Client–Server (SPA + REST API)** kết hợp **Modular Monolith (Layered Architecture)** ở phía Backend:

- **Frontend:** **React SPA** (Responsive Web cho Desktop & Mobile trên Chrome/Safari — đáp ứng `NFR-01`).
- **Backend:** **Node.js + Express** tổ chức theo kiến trúc **3 lớp (Controller $\rightarrow$ Service $\rightarrow$ Repository)** chia thành các module nghiệp vụ độc lập (*Auth, Facility & Search, Booking & Hold, Owner Schedule, Notification*).
- **Database:** **PostgreSQL** đóng vai trò nguồn dữ liệu chân lý duy nhất (*Single Source of Truth*) cho **Lịch chung (Shared Schedule)**.

### Lý do lựa chọn:
1. **Phù hợp ràng buộc nhân lực & thời gian:** Nhóm gồm 4 thành viên (~14 giờ/tuần/người) với hạn tuần 10 (PA5). *Modular Monolith* giúp phát triển, debug, kiểm thử (Jest) và triển khai đơn giản hơn nhiều so với Microservices, nhưng vẫn tách biệt rõ ràng ranh giới module.
2. **Đảm bảo tính nhất quán đặt sân (`NFR-02`):** Cơ chế giữ chỗ tạm thời 5 phút (*All-or-Nothing*), kiểm tra lại khi xác nhận và chống đặt trùng đồng thời đòi hỏi **ACID Transaction** và khóa mức dòng/ràng buộc duy nhất (*Row-level Lock / Exclusion Constraint*) trên cùng một cơ sở dữ liệu PostgreSQL.
3. **Đáp ứng hiệu năng (`NFR-06`):** Với 50 người dùng đồng thời và mục tiêu P95 $\le 2$ giây khi tìm kiếm/xem lịch, kiến trúc Stateless REST API + Connection Pooling trên PostgreSQL xử lý nhẹ nhàng mà không cần tầng message broker phức tạp.
4. **Tuân thủ phạm vi Out-of-Scope:** Không tích hợp cổng thanh toán trực tuyến hay dịch vụ gửi Email/SMS bên ngoài; mọi thông báo trạng thái và hủy lịch lưu trực tiếp trong PostgreSQL và trả về qua API trong ứng dụng (`NFR-09`).

---

## 2. Sơ đồ C4 Level 1 — System Context Diagram

Mô tả hệ thống **CourtConnect** trong mối quan hệ với 3 tác nhân chính và giới hạn phạm vi (không kết nối hệ thống bên ngoài).

```mermaid
flowchart TB
    Guest["👤 Khách (Guest)<br/>Chưa đăng nhập<br/>Tìm kiếm, lọc sân, xem lịch trống"]
    Player["🏃 Người chơi (Player)<br/>Đã đăng nhập<br/>Đặt sân, giữ chỗ 5p, xem & hủy đơn (>= 3h)"]
    Owner["🏟️ Chủ sân (Facility Owner)<br/>Đã đăng nhập<br/>Quản lý cơ sở/sân/giá, khóa lịch (>= 24h), đặt trực tiếp"]

    System["⚽ Hệ thống Đặt sân Thể thao<br/>T04 CourtConnect<br/>(Web Application)<br/>Quản lý lịch chung, giữ chỗ 5p, xác nhận đơn & thông báo In-app"]

    Guest -- "Tìm kiếm, lọc, xem chi tiết & đăng ký/đăng nhập (HTTPS)" --> System
    Player -- "Chọn khung giờ, giữ chỗ 5p, xác nhận & hủy đơn (HTTPS)" --> System
    Owner -- "Quản lý cơ sở, giá, khóa khung giờ & đặt trực tiếp (HTTPS)" --> System
```

---

## 3. Sơ đồ C4 Level 2 — Container Diagram

Mô tả các thành phần chạy độc lập (*Containers*) cấu thành hệ thống và cách chúng giao tiếp.

```mermaid
flowchart TB
    User["👤 Khách / Người chơi / Chủ sân<br/>(Google Chrome / Apple Safari trên Desktop & Mobile)"]

    subgraph Cloud["☁️ Cloud Linux Environment"]
        SPA["🌐 Web Application<br/>(React SPA)<br/>Giao diện responsive, đếm ngược giữ chỗ từ server timestamp"]
        API["⚙️ Backend API Server<br/>(Node.js + Express)<br/>Xử lý nghiệp vụ, phân quyền RBAC, Transaction đặt sân"]
        Worker["⏱️ Hold Expiry Worker<br/>(Node.js Scheduled Job / Interval)<br/>Quét & giải phóng lượt giữ chỗ hết hạn 5 phút (<= 5s)"]
        DB[("🗄️ PostgreSQL Database<br/>Lưu tài khoản (hashed password), cơ sở, sân con,<br/>lịch chung, lượt giữ chỗ, đơn đặt & thông báo In-app")]
    end

    User -- "Sử dụng giao diện Web (HTTPS)" --> SPA
    SPA -- "Gọi REST API (JSON / HTTPS + JWT)" --> API
    API -- "Đọc / Ghi & ACID Transaction (TCP/SQL)" --> DB
    Worker -- "Giải phóng Hold quá hạn mỗi 1–2s (TCP/SQL)" --> DB
```

---

## 4. Sơ đồ C4 Level 3 — Component Diagram (Backend API Server)

Mô tả cấu trúc các module bên trong **Node.js + Express API Server** theo kiến trúc phân tầng (*Controller $\rightarrow$ Service $\rightarrow$ Repository*).

```mermaid
flowchart LR
    SPA["🌐 React SPA"]

    subgraph Backend["⚙️ Node.js + Express API Server"]
        MW["🛡️ Auth & RBAC Middleware<br/>Xác thực JWT, kiểm tra vai trò & quyền sở hữu cơ sở (NFR-04)"]

        subgraph Modules["Các Module Nghiệp vụ (Controller → Service)"]
            AuthMod["🔐 Auth Module<br/>Đăng ký, Đăng nhập, Hash mật khẩu (NFR-05)"]
            FacMod["🔍 Facility & Search Module<br/>Tìm kiếm theo môn/vị trí, lọc tiện ích, xem giá & lịch trống"]
            BookMod["📅 Booking & Hold Engine<br/>Kiểm tra 2 khung, giữ chỗ 5p All-or-Nothing,<br/>recheck & tự động xác nhận, hủy đơn >= 3h"]
            OwnerMod["🏟️ Owner Schedule Module<br/>Quản lý cơ sở/sân/giá, đặt trực tiếp,<br/>chặn lịch/đổi giờ >= 24h & kiểm tra Hold ảnh hưởng"]
            NotiMod["🔔 In-App Notification Module<br/>Lưu & truy xuất thông báo hủy đơn trong ứng dụng"]
        end

        Repo["📦 Data Access Layer (Repositories)<br/>Quản lý Transaction, Row Lock & Query tối ưu"]
    end

    DB[("🗄️ PostgreSQL")]

    SPA -- "HTTPS / JSON" --> MW
    MW --> AuthMod & FacMod & BookMod & OwnerMod & NotiMod
    AuthMod & FacMod & BookMod & OwnerMod & NotiMod --> Repo
    OwnerMod -. "Tạo thông báo hủy đơn" .-> NotiMod
    Repo -- "SQL / Pool" --> DB
```

---

## 5. Sơ đồ C4 Level 4 / Deployment Diagram

Mô tả môi trường triển khai thực tế phục vụ kiểm thử nhóm, CI/CD và demo môn học.

```mermaid
flowchart LR
    subgraph ClientDevices["📱 Thiết bị Người dùng"]
        Desktop["💻 Laptop / Desktop<br/>(Chrome, Safari)"]
        Mobile["📱 Điện thoại / Tablet<br/>(Chrome, Safari)"]
    end

    subgraph GitHub["🐙 GitHub & CI"]
        Repo["📦 GitHub Repository<br/>(se-project-t04)"]
        Actions["🤖 GitHub Actions CI<br/>Chạy Jest Unit & Integration Tests"]
    end

    subgraph CloudServer["☁️ Cloud Linux Server"]
        Proxy["🔀 Reverse Proxy (Nginx)<br/>Phục vụ Static React Build & Proxy /api"]
        NodeApp["⚙️ Node.js + Express Process<br/>API Server + Hold Expiry Worker"]
        PG[("🗄️ PostgreSQL Server<br/>Dữ liệu & Lịch chung")]
    end

    Desktop & Mobile -- "HTTPS (443)" --> Proxy
    Proxy -- "Static Files" --> Desktop & Mobile
    Proxy -- "HTTP /api (Localhost)" --> NodeApp
    NodeApp -- "SQL (Localhost / SSL)" --> PG
    Repo -- "Push / PR" --> Actions
```

---

## 6. Ánh xạ Kiến trúc với Các Yêu cầu Phi chức năng & Quy tắc Nghiệp vụ

| Yêu cầu / Quy tắc | Cách kiến trúc đáp ứng |
|---|---|
| **Nhất quán & Chống trùng slot (`NFR-02`, `FR-13`)** | Xử lý trong PostgreSQL Transaction kết hợp khóa bi quan (*Pessimistic Lock*) hoặc ràng buộc duy nhất theo `(court_id, slot_time)` trên lịch chung; đảm bảo *All-or-Nothing* và chỉ 1 yêu cầu giữ chỗ thành công khi tranh chấp đồng thời. |
| **Giữ chỗ 5 phút & Nhả $\le 5s$ (`NFR-03`, `FR-14`, `FR-25`)** | Thời điểm hết hạn `expires_at` lưu ở Backend/DB. Khi F5, Frontend lấy lại `expires_at` từ API nên không bị reset 5 phút. Kết hợp **kiểm tra điều kiện hết hạn ngay khi truy vấn/xác nhận** (*lazy check*) và **Hold Expiry Worker** quét mỗi 1–2 giây để đảm bảo hoàn tất nhả chỗ trong tối đa 5 giây. |
| **Phân quyền & Bảo mật (`NFR-04`, `NFR-05`)** | Middleware kiểm tra JWT và quyền sở hữu (`facility.owner_id === user.id`) tại Backend trước mọi thao tác của Chủ sân. Mật khẩu được băm (bcrypt/argon2) trước khi lưu DB. |
| **Hiệu năng 50 người dùng (`NFR-06`)** | React SPA giảm tải render server; Backend stateless dùng Connection Pool tới PostgreSQL kết hợp đánh Index cho tìm kiếm sân và truy vấn lịch theo ngày. |
| **Thông báo In-app (`NFR-09`, `FR-30`)** | Khi Chủ sân hủy đơn do chặn lịch/đổi giờ ($\ge 24$ giờ), `Owner Schedule Module` gọi `Notification Module` ghi trực tiếp bản ghi thông báo vào DB trong cùng Transaction, không gọi dịch vụ Email/SMS bên ngoài. |
