-- =====================================================================
-- PA3 / Task 3.1.2 — Thiết kế dữ liệu và ràng buộc lịch đặt sân
-- Nguồn DDL của ERD (mã DB-xx xem README.md). PostgreSQL 16.
-- Yêu cầu extension: btree_gist (đi kèm postgresql-contrib).
-- Quy ước: thời điểm lưu bằng timestamptz (UTC); "ngày" và "giờ mở cửa"
-- tính theo múi giờ Asia/Ho_Chi_Minh ở tầng ứng dụng.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------- Kiểu liệt kê ----------
CREATE TYPE user_role           AS ENUM ('PLAYER', 'FACILITY_OWNER');
CREATE TYPE court_status        AS ENUM ('ACTIVE', 'DELETED');
CREATE TYPE hold_status         AS ENUM ('ACTIVE', 'CONFIRMED', 'RELEASED', 'EXPIRED');
CREATE TYPE booking_status      AS ENUM ('CONFIRMED', 'CANCELLED_BY_PLAYER', 'CANCELLED_BY_OWNER');
CREATE TYPE booking_source      AS ENUM ('APP', 'IN_PERSON');
CREATE TYPE entry_type          AS ENUM ('HOLD', 'BOOKING', 'BLOCK');
CREATE TYPE owner_change_reason AS ENUM ('BLOCKED_PERIOD', 'HOURS_CHANGED', 'COURT_DELETED');

-- ---------- Người dùng ----------
-- Đồng bộ với API-AUTH (#34): tách email (định danh đăng nhập) và phone bắt buộc riêng.
CREATE TABLE app_user (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text        NOT NULL CHECK (length(btrim(name)) > 0),
    email         text        NOT NULL UNIQUE CHECK (position('@' in btrim(email)) > 1),
    phone         text        NOT NULL UNIQUE CHECK (length(btrim(phone)) >= 8),
    password_hash text        NOT NULL,
    role          user_role   NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------- Cơ sở, sân, giá ----------
CREATE TABLE sport (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE amenity (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE facility (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id    bigint      NOT NULL REFERENCES app_user (id) ON DELETE RESTRICT,
    sport_id    bigint      NOT NULL REFERENCES sport (id)    ON DELETE RESTRICT,
    name        text        NOT NULL CHECK (length(btrim(name)) > 0),
    address     text        NOT NULL,
    district    text        NOT NULL,
    description text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE facility_amenity (
    facility_id bigint NOT NULL REFERENCES facility (id) ON DELETE CASCADE,
    amenity_id  bigint NOT NULL REFERENCES amenity (id)  ON DELETE RESTRICT,
    PRIMARY KEY (facility_id, amenity_id)
);

CREATE TABLE operating_hours (
    facility_id bigint   NOT NULL REFERENCES facility (id) ON DELETE CASCADE,
    day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- 1 = thứ Hai (ISO)
    open_time   time     NOT NULL,
    close_time  time     NOT NULL,
    CHECK (close_time > open_time),
    PRIMARY KEY (facility_id, day_of_week)
);

CREATE TABLE court (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_id bigint       NOT NULL REFERENCES facility (id) ON DELETE RESTRICT,
    name        text         NOT NULL CHECK (length(btrim(name)) > 0),
    status      court_status NOT NULL DEFAULT 'ACTIVE',
    deleted_at  timestamptz,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    CHECK ((status = 'DELETED') = (deleted_at IS NOT NULL)),
    UNIQUE (id, facility_id)                          -- đích của khóa ngoại ghép
);
CREATE UNIQUE INDEX court_active_name_uq ON court (facility_id, name) WHERE status = 'ACTIVE';

CREATE TABLE court_price (
    court_id        bigint        NOT NULL REFERENCES court (id) ON DELETE RESTRICT,
    effective_from  timestamptz   NOT NULL,
    amount_per_slot numeric(12,0) NOT NULL CHECK (amount_per_slot >= 0),
    PRIMARY KEY (court_id, effective_from)
);

-- ---------- Giữ chỗ và đặt chỗ ----------
-- Lưu source ('APP' | 'IN_PERSON') ngay trên hold để giữ ngữ cảnh đặt tại quầy (UC-13) qua 2 bước.
CREATE TABLE hold (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id           bigint         NOT NULL REFERENCES app_user (id) ON DELETE RESTRICT,
    facility_id       bigint         NOT NULL REFERENCES facility (id) ON DELETE RESTRICT,
    source            booking_source NOT NULL DEFAULT 'APP',
    status            hold_status    NOT NULL DEFAULT 'ACTIVE',
    created_at        timestamptz    NOT NULL DEFAULT now(),
    expires_at        timestamptz    NOT NULL DEFAULT now() + interval '5 minutes',
    released_at       timestamptz,
    release_failed_at timestamptz,
    CHECK (expires_at = created_at + interval '5 minutes'),            -- BR-01, không gia hạn
    CHECK ((status = 'RELEASED') = (released_at IS NOT NULL)),
    CHECK (release_failed_at IS NULL OR status = 'EXPIRED'),
    UNIQUE (id, facility_id),
    UNIQUE (id, facility_id, source)                                   -- đích khóa ngoại ghép sang booking
);

CREATE TABLE booking (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hold_id       bigint              NOT NULL UNIQUE,                 -- mỗi booking sinh từ đúng một hold
    user_id       bigint              NOT NULL REFERENCES app_user (id) ON DELETE RESTRICT,
    facility_id   bigint              NOT NULL REFERENCES facility (id) ON DELETE RESTRICT,
    source        booking_source      NOT NULL,
    status        booking_status      NOT NULL DEFAULT 'CONFIRMED',
    created_at    timestamptz         NOT NULL DEFAULT now(),
    cancelled_at  timestamptz,
    cancel_reason owner_change_reason,
    cancel_note   text,                                                -- lý do tùy chọn khi người chơi hủy (reason?)
    FOREIGN KEY (hold_id, facility_id, source) REFERENCES hold (id, facility_id, source),
    CHECK (
        (status = 'CONFIRMED'           AND cancelled_at IS NULL     AND cancel_reason IS NULL     AND cancel_note IS NULL) OR
        (status = 'CANCELLED_BY_PLAYER' AND cancelled_at IS NOT NULL AND cancel_reason IS NULL) OR
        (status = 'CANCELLED_BY_OWNER'  AND cancelled_at IS NOT NULL AND cancel_reason IS NOT NULL)
    ),
    UNIQUE (id, facility_id)
);

-- ---------- Lịch chung: mọi thứ chiếm thời gian của một sân ----------
-- Một dòng = một sân + một dải slot 30 phút liên tiếp, thuộc về HOLD, BOOKING hoặc BLOCK.
-- Cột unit_price chụp đơn giá 1 slot 30 phút lúc tạo hold để tính totalPrice nhất quán (#34).
CREATE TABLE schedule_entry (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    court_id    bigint        NOT NULL,
    facility_id bigint        NOT NULL,
    start_time  timestamptz   NOT NULL,
    end_time    timestamptz   NOT NULL,
    entry_type  entry_type    NOT NULL,
    hold_id     bigint,
    booking_id  bigint,
    blocked_by  bigint        REFERENCES app_user (id) ON DELETE RESTRICT,
    unit_price  numeric(12,0) CHECK (unit_price IS NULL OR unit_price >= 0),
    is_active   boolean       NOT NULL DEFAULT true,
    created_at  timestamptz   NOT NULL DEFAULT now(),

    FOREIGN KEY (court_id, facility_id)   REFERENCES court (id, facility_id),
    FOREIGN KEY (hold_id, facility_id)    REFERENCES hold (id, facility_id),
    FOREIGN KEY (booking_id, facility_id) REFERENCES booking (id, facility_id),

    CHECK (end_time > start_time),
    CHECK (EXTRACT(EPOCH FROM start_time)::bigint % 1800 = 0),        -- bội của 30 phút
    CHECK (EXTRACT(EPOCH FROM end_time)::bigint   % 1800 = 0),
    CHECK (
        (entry_type = 'HOLD'    AND hold_id IS NOT NULL AND booking_id IS NULL     AND blocked_by IS NULL     AND unit_price IS NOT NULL) OR
        (entry_type = 'BOOKING' AND hold_id IS NOT NULL AND booking_id IS NOT NULL AND blocked_by IS NULL     AND unit_price IS NOT NULL) OR
        (entry_type = 'BLOCK'   AND hold_id IS NULL     AND booking_id IS NULL     AND blocked_by IS NOT NULL AND unit_price IS NULL)
    ),
    CHECK (is_active OR entry_type <> 'BLOCK'),                       -- không có thao tác gỡ khóa (DB-ASM-07)

    UNIQUE (hold_id, court_id),                                        -- mỗi sân tối đa một dải trong một hold

    -- Chống trùng: hai dòng đang hoạt động của cùng một sân không được chồng lấn thời gian.
    CONSTRAINT schedule_entry_no_overlap
        EXCLUDE USING gist (
            court_id WITH =,
            tstzrange(start_time, end_time, '[)') WITH &&
        ) WHERE (is_active)
);

-- ---------- Thông báo trong ứng dụng ----------
-- Đồng bộ với API-NTF (#34): có cột is_read phục vụ lọc unreadOnly và PATCH /notifications/:id/read.
CREATE TABLE notification (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    bigint              NOT NULL REFERENCES app_user (id) ON DELETE RESTRICT,
    booking_id bigint              REFERENCES booking (id) ON DELETE RESTRICT,
    reason     owner_change_reason NOT NULL,
    message    text                NOT NULL,
    is_read    boolean             NOT NULL DEFAULT false,
    created_at timestamptz         NOT NULL DEFAULT now()
);

-- ---------- Chỉ mục (gắn với truy vấn Q1..Q10 trong README) ----------
CREATE INDEX facility_owner_idx          ON facility (owner_id);                                   -- Q10
CREATE INDEX facility_sport_area_idx     ON facility (sport_id, district);                         -- Q1
CREATE INDEX facility_amenity_rev_idx    ON facility_amenity (amenity_id, facility_id);            -- Q2
CREATE INDEX court_facility_active_idx   ON court (facility_id) WHERE status = 'ACTIVE';           -- Q3
CREATE INDEX booking_user_idx            ON booking (user_id, created_at DESC);                    -- Q4
CREATE INDEX booking_facility_idx        ON booking (facility_id, status);                         -- Q4
CREATE INDEX schedule_entry_booking_idx  ON schedule_entry (booking_id) WHERE booking_id IS NOT NULL;  -- Q5
CREATE INDEX hold_expiry_idx             ON hold (expires_at) WHERE status = 'ACTIVE';             -- Q7
CREATE INDEX hold_release_retry_idx      ON hold (expires_at) WHERE status = 'EXPIRED';            -- Q7
CREATE UNIQUE INDEX hold_user_active_idx ON hold (user_id)    WHERE status = 'ACTIVE';             -- Q8 (mỗi user tối đa 1 hold ACTIVE)
CREATE INDEX notification_user_idx       ON notification (user_id, is_read, created_at DESC);      -- Q9 (hỗ trợ lọc unreadOnly và sắp xếp)
-- Q3 và Q6 dùng chỉ mục GiST do ràng buộc schedule_entry_no_overlap tạo ra (một phần: is_active).