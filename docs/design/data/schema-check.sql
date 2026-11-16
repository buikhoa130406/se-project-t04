-- =====================================================================
-- Kiểm tra ràng buộc của schema.sql trên PostgreSQL 16 (Task 3.1.2)
-- Chạy: psql -v ON_ERROR_STOP=1 -d <db> -f schema.sql -f schema-check.sql
-- Mỗi kiểm tra in PASS/FAIL. Đây là kiểm tra ràng buộc dữ liệu,
-- KHÔNG thay cho thử nghiệm React–API–PostgreSQL (Issue #7) hay đo mốc 5 giây.
-- =====================================================================
\set ON_ERROR_STOP off
\pset tuples_only on

-- ---------- Dữ liệu mẫu ----------
INSERT INTO app_user (name, contact, password_hash, role) VALUES
  ('Chủ sân', 'owner@example.com', 'x', 'FACILITY_OWNER'),
  ('Người chơi 1', 'p1@example.com', 'x', 'PLAYER'),
  ('Người chơi 2', 'p2@example.com', 'x', 'PLAYER');
INSERT INTO sport (name) VALUES ('Cầu lông');
INSERT INTO facility (owner_id, sport_id, name, address, district)
  SELECT u.id, s.id, f.n, 'địa chỉ', 'Quận 1'
  FROM app_user u, sport s, (VALUES ('CS A'), ('CS B')) AS f(n) WHERE u.role = 'FACILITY_OWNER';
INSERT INTO court (facility_id, name)
  SELECT f.id, c.n FROM facility f JOIN (VALUES ('CS A','Sân 1'),('CS A','Sân 2'),('CS B','Sân 3')) c(fac,n) ON c.fac = f.name;

-- tiện ích: tạo hold + một dải trên một sân (trả về id hold)
CREATE FUNCTION t_hold(p_user text, p_court text, p_start timestamptz, p_end timestamptz)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_h bigint; v_c court;
BEGIN
  SELECT * INTO v_c FROM court WHERE name = p_court;
  INSERT INTO hold (user_id, facility_id) SELECT id, v_c.facility_id FROM app_user WHERE contact = p_user RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id)
    VALUES (v_c.id, v_c.facility_id, p_start, p_end, 'HOLD', v_h);
  RETURN v_h;
END $$;

CREATE FUNCTION t_expect(p_name text, p_sqlstate text, p_stmt text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_stmt;
    IF p_sqlstate = '00000' THEN RAISE NOTICE 'PASS  %', p_name;
    ELSE RAISE NOTICE 'FAIL  % (không bị chặn)', p_name; END IF;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = p_sqlstate THEN RAISE NOTICE 'PASS  % (%)', p_name, SQLSTATE;
    ELSE RAISE NOTICE 'FAIL  % (nhận % thay vì %: %)', p_name, SQLSTATE, p_sqlstate, SQLERRM; END IF;
  END;
END $$;

-- ---------- K1. Chống trùng slot ----------
SELECT t_hold('p1@example.com','Sân 1','2026-12-01 10:00+07','2026-12-01 11:00+07');
SELECT t_expect('K1a hai hold chồng lấn trên cùng sân bị chặn', '23P01',
  $q$SELECT t_hold('p2@example.com','Sân 1','2026-12-01 10:30+07','2026-12-01 11:30+07')$q$);
SELECT t_expect('K1b hai khung kề nhau (11:00-12:00) được phép', '00000',
  $q$SELECT t_hold('p2@example.com','Sân 1','2026-12-01 11:00+07','2026-12-01 12:00+07')$q$);

-- ---------- K2. Tất cả hoặc không có gì ----------
DO $$
DECLARE n_before int; n_after int;
BEGIN
  SELECT count(*) INTO n_before FROM hold;
  BEGIN
    -- giao dịch con: Sân 2 trống, Sân 1 đã bị chiếm -> cả hold phải bị hủy
    PERFORM t_hold('p2@example.com','Sân 2','2026-12-01 10:00+07','2026-12-01 11:00+07');
    INSERT INTO hold (user_id, facility_id) SELECT 3, facility_id FROM court WHERE name='Sân 1';
    INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id)
      SELECT c.id, c.facility_id, '2026-12-01 10:30+07', '2026-12-01 11:30+07', 'HOLD', (SELECT max(id) FROM hold)
      FROM court c WHERE c.name='Sân 1';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;
  SELECT count(*) INTO n_after FROM hold;
  IF n_before = n_after AND NOT EXISTS (SELECT 1 FROM schedule_entry e JOIN court c ON c.id=e.court_id
        WHERE c.name='Sân 2' AND e.start_time = '2026-12-01 10:00+07') THEN
    RAISE NOTICE 'PASS  K2 một dải xung đột thì toàn bộ hold bị hủy (không giữ slot nào)';
  ELSE RAISE NOTICE 'FAIL  K2 còn dữ liệu sót lại'; END IF;
END $$;

-- ---------- K3. Cấu trúc slot, loại dòng, cùng cơ sở ----------
SELECT t_expect('K3a mốc 10:15 không phải bội của 30 phút', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:15+07','2026-12-01 11:00+07')$q$);
SELECT t_expect('K3b kết thúc không sau bắt đầu', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 11:00+07','2026-12-01 11:00+07')$q$);
SELECT t_expect('K3c dòng HOLD không được có booking_id', '23514',
  $q$INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,booking_id)
     SELECT c.id,c.facility_id,'2026-12-02 10:00+07','2026-12-02 11:00+07','HOLD',1,1 FROM court c WHERE name='Sân 2'$q$);
SELECT t_expect('K3d sân thuộc cơ sở khác hold bị chặn (DM-INV-01)', '23503',
  $q$INSERT INTO hold (user_id,facility_id) SELECT 2, f.id FROM facility f WHERE f.name='CS A';
     INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id)
       SELECT c.id, (SELECT id FROM facility WHERE name='CS A'),'2026-12-02 10:00+07','2026-12-02 11:00+07','HOLD',(SELECT max(id) FROM hold)
       FROM court c WHERE c.name='Sân 3'$q$);
SELECT t_expect('K3e hai dải của cùng một sân trong một hold bị chặn (DM-INV-02)', '23505',
  $q$INSERT INTO hold (user_id,facility_id) SELECT 2, c.facility_id FROM court c WHERE c.name='Sân 2';
     INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id)
       SELECT c.id,c.facility_id,t.s,t.e,'HOLD',(SELECT max(id) FROM hold)
       FROM court c, (VALUES ('2026-12-03 10:00+07'::timestamptz,'2026-12-03 10:30+07'::timestamptz),
                             ('2026-12-03 12:00+07','2026-12-03 12:30+07')) t(s,e) WHERE c.name='Sân 2'$q$);

-- ---------- K4. Hạn hold ----------
SELECT t_expect('K4 expires_at khác created_at + 5 phút bị chặn (BR-01)', '23514',
  $q$INSERT INTO hold (user_id,facility_id,expires_at) SELECT 2, c.facility_id, now() + interval '10 minutes' FROM court c WHERE name='Sân 1'$q$);

-- ---------- K5. Xác nhận, hủy và giải phóng ----------
DO $$
DECLARE v_hold bigint; v_book bigint;
BEGIN
  v_hold := t_hold('p1@example.com','Sân 2','2026-12-04 18:00+07','2026-12-04 19:00+07');
  -- xác nhận: hold -> CONFIRMED, tạo booking, dòng HOLD -> BOOKING (vẫn chiếm chỗ)
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    SELECT h.id, h.user_id, h.facility_id, 'APP' FROM hold h WHERE h.id = v_hold RETURNING id INTO v_book;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_hold;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_book WHERE hold_id = v_hold;
  BEGIN
    PERFORM t_hold('p2@example.com','Sân 2','2026-12-04 18:30+07','2026-12-04 19:30+07');
    RAISE NOTICE 'FAIL  K5a booking đã xác nhận vẫn bị đặt đè';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K5a slot của booking đã xác nhận không đặt đè được';
  END;
  -- hủy bởi người chơi: slot được nhả, lịch sử vẫn còn
  UPDATE booking SET status='CANCELLED_BY_PLAYER', cancelled_at = now() WHERE id = v_book;
  UPDATE schedule_entry SET is_active = false WHERE booking_id = v_book;
  PERFORM t_hold('p2@example.com','Sân 2','2026-12-04 18:30+07','2026-12-04 19:30+07');
  IF EXISTS (SELECT 1 FROM schedule_entry WHERE booking_id = v_book AND NOT is_active) THEN
    RAISE NOTICE 'PASS  K5b hủy xong thì đặt lại được và lịch sử booking còn nguyên';
  ELSE RAISE NOTICE 'FAIL  K5b mất lịch sử'; END IF;
END $$;
SELECT t_expect('K5c hủy bởi chủ sân mà thiếu lý do bị chặn', '23514',
  $q$UPDATE booking SET status='CANCELLED_BY_OWNER', cancelled_at=now() WHERE id = (SELECT min(id) FROM booking)$q$);

-- ---------- K6. Chặn lịch (BlockedPeriod) cùng cơ chế ----------
DO $$
DECLARE v_hold bigint;
BEGIN
  v_hold := t_hold('p1@example.com','Sân 1','2026-12-05 08:00+07','2026-12-05 09:00+07');
  BEGIN
    INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, blocked_by)
      SELECT c.id, c.facility_id, '2026-12-05 08:30+07', '2026-12-05 09:30+07', 'BLOCK', 1 FROM court c WHERE c.name='Sân 1';
    RAISE NOTICE 'FAIL  K6a khóa lịch đè lên hold đang giữ';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K6a khóa lịch bị chặn khi còn hold đang giữ (phải chờ)';
  END;
  UPDATE hold SET status='RELEASED', released_at = now() WHERE id = v_hold;
  UPDATE schedule_entry SET is_active = false WHERE hold_id = v_hold;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, blocked_by)
    SELECT c.id, c.facility_id, '2026-12-05 08:30+07', '2026-12-05 09:30+07', 'BLOCK', 1 FROM court c WHERE c.name='Sân 1';
  RAISE NOTICE 'PASS  K6b hold đã nhả thì khóa lịch được tạo';
  BEGIN
    PERFORM t_hold('p2@example.com','Sân 1','2026-12-05 09:00+07','2026-12-05 10:00+07');
    RAISE NOTICE 'FAIL  K6c hold đè lên khoảng bị khóa';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K6c hold không đè được khoảng bị khóa (DM-INV-08)';
  END;
END $$;
SELECT t_expect('K6d không có thao tác gỡ khóa (DB-ASM-07)', '23514',
  $q$UPDATE schedule_entry SET is_active = false WHERE entry_type = 'BLOCK'$q$);

-- ---------- K7. Truy vấn khả dụng theo ngày (Q3) ----------
\echo --- Q3: trạng thái các slot của Sân 1, 09:00-12:00 ngày 2026-12-01 (10:00-11:00 là hold của K1, 11:00-12:00 là hold của K1b) ---
SELECT to_char(s.slot AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') AS slot_bat_dau,
       CASE WHEN e.id IS NULL THEN 'available'
            WHEN e.entry_type = 'BLOCK' THEN 'unavailable'
            WHEN e.entry_type = 'BOOKING' THEN 'booked' ELSE 'held' END AS trang_thai
FROM court c
CROSS JOIN LATERAL generate_series('2026-12-01 09:00+07'::timestamptz, '2026-12-01 11:30+07', interval '30 minutes') AS s(slot)
LEFT JOIN schedule_entry e
       ON e.court_id = c.id AND e.is_active
      AND tstzrange(e.start_time, e.end_time, '[)') && tstzrange(s.slot, s.slot + interval '30 minutes', '[)')
WHERE c.name = 'Sân 1'
ORDER BY s.slot;
