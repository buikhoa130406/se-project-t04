-- =====================================================================
-- DDL Thiết kế dữ liệu hệ thống đặt sân thể thao (Task 3.1.2 — PA3)
-- Hệ quản trị: PostgreSQL 16 (yêu cầu extension btree_gist)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------- Kiểu liệt kê ----------
CREATE TYPE user_role AS ENUM ('PLAYER', 'FACILITY_OWNER');
CREATE TYPE court_status AS ENUM ('ACTIVE', 'DELETED');
CREATE TYPE hold_status AS ENUM ('ACTIVE', 'CONFIRMED', 'RELEASED', 'EXPIRED');
CREATE TYPE booking_status AS ENUM ('CONFIRMED', 'CANCELLED_BY_PLAYER', 'CANCELLED_BY_OWNER');
CREATE TYPE booking_source AS ENUM ('APP', 'IN_PERSON');
CREATE TYPE entry_type AS ENUM ('HOLD', 'BOOKING', 'BLOCK');
CREATE TYPE owner_change_reason AS ENUM ('BLOCKED_PERIOD', 'HOURS_CHANGED', 'COURT_DELETED');

-- ---------- 1. Người dùng ----------
CREATE TABLE app_user (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          text NOT NULL CHECK (btrim(name) <> ''),
  email         text NOT NULL UNIQUE CHECK (btrim(email) <> ''),
  phone         text NOT NULL UNIQUE CHECK (btrim(phone) <> ''),
  password_hash text NOT NULL CHECK (btrim(password_hash) <> ''),
  role          user_role NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------- 2. Môn thể thao ----------
CREATE TABLE sport (
  id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL UNIQUE CHECK (btrim(name) <> '')
);

-- ---------- 3. Tiện ích ----------
CREATE TABLE amenity (
  id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL UNIQUE CHECK (btrim(name) <> '')
);

-- ---------- 4. Cơ sở thể thao ----------
CREATE TABLE facility (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner_id    bigint NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  sport_id    bigint NOT NULL REFERENCES sport(id) ON DELETE RESTRICT,
  name        text NOT NULL CHECK (btrim(name) <> ''),
  address     text NOT NULL CHECK (btrim(address) <> ''),
  district    text NOT NULL CHECK (btrim(district) <> ''),
  description text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX facility_owner_idx ON facility (owner_id);
CREATE INDEX facility_sport_area_idx ON facility (sport_id, district);

-- ---------- 5. Tiện ích của cơ sở ----------
CREATE TABLE facility_amenity (
  facility_id bigint NOT NULL REFERENCES facility(id) ON DELETE CASCADE,
  amenity_id  bigint NOT NULL REFERENCES amenity(id) ON DELETE RESTRICT,
  PRIMARY KEY (facility_id, amenity_id)
);

CREATE INDEX facility_amenity_rev_idx ON facility_amenity (amenity_id, facility_id);

-- ---------- 6. Giờ mở cửa theo ngày trong tuần ----------
CREATE TABLE operating_hours (
  facility_id bigint NOT NULL REFERENCES facility(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  open_time   time NOT NULL,
  close_time  time NOT NULL,
  PRIMARY KEY (facility_id, day_of_week),
  CHECK (close_time > open_time)
);

-- ---------- 7. Sân con ----------
CREATE TABLE court (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  facility_id bigint NOT NULL REFERENCES facility(id) ON DELETE RESTRICT,
  name        text NOT NULL CHECK (btrim(name) <> ''),
  status      court_status NOT NULL DEFAULT 'ACTIVE',
  deleted_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, facility_id),
  UNIQUE (facility_id, name),
  CHECK ((status = 'ACTIVE' AND deleted_at IS NULL) OR (status = 'DELETED' AND deleted_at IS NOT NULL))
);

CREATE INDEX court_facility_active_idx ON court (facility_id) WHERE status = 'ACTIVE';

-- ---------- 8. Lịch sử đơn giá theo slot 30 phút ----------
CREATE TABLE court_price (
  court_id        bigint NOT NULL REFERENCES court(id) ON DELETE RESTRICT,
  effective_from  timestamptz NOT NULL,
  amount_per_slot numeric(12, 2) NOT NULL CHECK (amount_per_slot >= 0),
  PRIMARY KEY (court_id, effective_from)
);

-- ---------- 9. Lượt giữ chỗ 5 phút ----------
CREATE TABLE hold (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id           bigint NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  facility_id       bigint NOT NULL REFERENCES facility(id) ON DELETE RESTRICT,
  source            booking_source NOT NULL DEFAULT 'APP',
  status            hold_status NOT NULL DEFAULT 'ACTIVE',
  created_at        timestamptz NOT NULL DEFAULT now(),
  expires_at        timestamptz NOT NULL DEFAULT (now() + interval '5 minutes'),
  released_at       timestamptz,
  release_failed_at timestamptz,
  UNIQUE (id, facility_id),
  UNIQUE (id, facility_id, source),
  CHECK (expires_at = created_at + interval '5 minutes'),
  CHECK ((status = 'RELEASED' AND released_at IS NOT NULL) OR (status <> 'RELEASED' AND released_at IS NULL)),
  CHECK (release_failed_at IS NULL OR status = 'EXPIRED')
);

CREATE UNIQUE INDEX hold_user_active_idx ON hold (user_id) WHERE status = 'ACTIVE';
CREATE INDEX hold_expiry_idx ON hold (expires_at) WHERE status = 'ACTIVE';
CREATE INDEX hold_release_retry_idx ON hold (expires_at) WHERE status = 'EXPIRED';

-- ---------- 10. Đơn đặt sân đã xác nhận ----------
CREATE TABLE booking (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hold_id       bigint NOT NULL UNIQUE,
  user_id       bigint NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  facility_id   bigint NOT NULL REFERENCES facility(id) ON DELETE RESTRICT,
  source        booking_source NOT NULL,
  status        booking_status NOT NULL DEFAULT 'CONFIRMED',
  created_at    timestamptz NOT NULL DEFAULT now(),
  cancelled_at  timestamptz,
  cancel_reason owner_change_reason,
  cancel_note   text,
  UNIQUE (id, facility_id),
  FOREIGN KEY (hold_id, facility_id, source) REFERENCES hold(id, facility_id, source) ON DELETE RESTRICT,
  CHECK (
    (status = 'CONFIRMED' AND cancelled_at IS NULL AND cancel_reason IS NULL AND cancel_note IS NULL)
    OR (status = 'CANCELLED_BY_PLAYER' AND cancelled_at IS NOT NULL AND cancel_reason IS NULL)
    OR (status = 'CANCELLED_BY_OWNER' AND cancelled_at IS NOT NULL AND cancel_reason IS NOT NULL AND cancel_note IS NULL)
  )
);

CREATE INDEX booking_user_idx ON booking (user_id, created_at DESC);
CREATE INDEX booking_facility_idx ON booking (facility_id, status);

-- ---------- 11. Bảng lịch chung (HOLD / BOOKING / BLOCK) ----------
CREATE TABLE schedule_entry (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  court_id    bigint NOT NULL,
  facility_id bigint NOT NULL,
  start_time  timestamptz NOT NULL,
  end_time    timestamptz NOT NULL,
  entry_type  entry_type NOT NULL,
  hold_id     bigint,
  booking_id  bigint,
  blocked_by  bigint REFERENCES app_user(id) ON DELETE RESTRICT,
  unit_price  numeric(12, 2),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (court_id, facility_id) REFERENCES court(id, facility_id) ON DELETE RESTRICT,
  FOREIGN KEY (hold_id, facility_id) REFERENCES hold(id, facility_id) ON DELETE RESTRICT,
  FOREIGN KEY (booking_id, facility_id) REFERENCES booking(id, facility_id) ON DELETE RESTRICT,
  CHECK (end_time > start_time),
  CHECK (start_time = date_trunc('minute', start_time) AND EXTRACT(MINUTE FROM start_time)::int % 30 = 0),
  CHECK (end_time = date_trunc('minute', end_time) AND EXTRACT(MINUTE FROM end_time)::int % 30 = 0),
  CHECK (
    (entry_type = 'HOLD' AND hold_id IS NOT NULL AND booking_id IS NULL AND blocked_by IS NULL AND unit_price IS NOT NULL AND unit_price >= 0)
    OR (entry_type = 'BOOKING' AND hold_id IS NOT NULL AND booking_id IS NOT NULL AND blocked_by IS NULL AND unit_price IS NOT NULL AND unit_price >= 0)
    OR (entry_type = 'BLOCK' AND hold_id IS NULL AND booking_id IS NULL AND blocked_by IS NOT NULL AND unit_price IS NULL)
  ),
  CHECK (is_active OR entry_type <> 'BLOCK'),
  CONSTRAINT schedule_entry_no_overlap EXCLUDE USING gist (
    court_id WITH =,
    tstzrange(start_time, end_time, '[)') WITH &&
  ) WHERE (is_active)
);

CREATE UNIQUE INDEX schedule_entry_hold_court_start_uk ON schedule_entry (hold_id, court_id, start_time) WHERE hold_id IS NOT NULL;
CREATE INDEX schedule_entry_booking_idx ON schedule_entry (booking_id) WHERE booking_id IS NOT NULL;
CREATE INDEX schedule_entry_hold_idx ON schedule_entry (hold_id) WHERE hold_id IS NOT NULL;

-- ---------- 12. Thông báo hủy đơn ----------
CREATE TABLE notification (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id        bigint NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  booking_id     bigint NOT NULL REFERENCES booking(id) ON DELETE RESTRICT,
  reason         owner_change_reason NOT NULL,
  message        text NOT NULL CHECK (btrim(message) <> ''),
  is_read        boolean NOT NULL DEFAULT false,
  affected_items jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(affected_items) = 'array'),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notification_user_idx ON notification (user_id, is_read, created_at DESC);
