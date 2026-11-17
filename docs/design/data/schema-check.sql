-- =====================================================================
-- Kiểm tra ràng buộc của schema.sql trên PostgreSQL 16 (Task 3.1.2)
-- Chạy: psql -v ON_ERROR_STOP=1 -d <db> -f schema.sql -f schema-check.sql
-- Mỗi kiểm tra in PASS; nếu bất kỳ kiểm tra nào thất bại, hàm sẽ
-- RAISE EXCEPTION kèm ON_ERROR_STOP=on để psql dừng ngay với exit code != 0.
-- Đây là kiểm tra ràng buộc dữ liệu, KHÔNG thay cho thử nghiệm
-- React–API–PostgreSQL (Issue #7) hay đo mốc 5 giây.
-- =====================================================================
\set ON_ERROR_STOP on
\pset tuples_only on

-- ---------- Dữ liệu mẫu ----------
INSERT INTO app_user (name, email, phone, password_hash, role) VALUES
  ('Chủ sân', 'owner@example.com', '0900000001', 'x', 'FACILITY_OWNER'),
  ('Người chơi 1', 'p1@example.com', '0900000002', 'x', 'PLAYER'),
  ('Người chơi 2', 'p2@example.com', '0900000003', 'x', 'PLAYER');
INSERT INTO sport (name) VALUES ('Cầu lông');
INSERT INTO facility (owner_id, sport_id, name, address, district)
  SELECT u.id, s.id, f.n, 'địa chỉ', 'Quận 1'
  FROM app_user u, sport s, (VALUES ('CS A'), ('CS B')) AS f(n) WHERE u.role = 'FACILITY_OWNER';
INSERT INTO court (facility_id, name)
  SELECT f.id, c.n FROM facility f JOIN (VALUES ('CS A','Sân 1'),('CS A','Sân 2'),('CS B','Sân 3')) c(fac,n) ON c.fac = f.name;
INSERT INTO court_price (court_id, effective_from, amount_per_slot)
  SELECT id, '2026-01-01 00:00+07', 80000 FROM court;

-- tiện ích: tạo hold + một dải trên một sân (chụp giá theo effective_from <= p_start)
CREATE FUNCTION t_hold(p_email text, p_court text, p_start timestamptz, p_end timestamptz)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_h bigint; v_c court; v_price numeric(12,0);
BEGIN
  SELECT * INTO v_c FROM court WHERE name = p_court;
  SELECT cp.amount_per_slot INTO v_price
    FROM court_price cp
   WHERE cp.court_id = v_c.id AND cp.effective_from <= p_start
   ORDER BY cp.effective_from DESC LIMIT 1;
  INSERT INTO hold (user_id, facility_id, source)
    SELECT id, v_c.facility_id, 'APP' FROM app_user WHERE email = p_email RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
    VALUES (v_c.id, v_c.facility_id, p_start, p_end, 'HOLD', v_h, v_price);
  RETURN v_h;
END $$;

-- Mọi trường hợp thất bại đều RAISE EXCEPTION để psql dừng ngay và trả mã thoát lỗi (!= 0)
CREATE FUNCTION t_expect(p_name text, p_sqlstate text, p_stmt text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_stmt;
    IF p_sqlstate = '00000' THEN RAISE NOTICE 'PASS  %', p_name;
    ELSE RAISE EXCEPTION 'FAIL  % (không bị chặn, kỳ vọng %)', p_name, p_sqlstate; END IF;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = p_sqlstate THEN RAISE NOTICE 'PASS  % (%)', p_name, SQLSTATE;
    ELSE RAISE EXCEPTION 'FAIL  % (nhận % thay vì %: %)', p_name, SQLSTATE, p_sqlstate, SQLERRM; END IF;
  END;
END $$;

-- ---------- K1. Chống trùng slot & tối đa 1 hold ACTIVE mỗi người dùng ----------
SELECT t_hold('p1@example.com','Sân 1','2026-12-01 10:00+07','2026-12-01 11:00+07');
SELECT t_expect('K1a hai hold chồng lấn trên cùng sân bị chặn', '23P01',
  $q$SELECT t_hold('p2@example.com','Sân 1','2026-12-01 10:30+07','2026-12-01 11:30+07')$q$);
SELECT t_expect('K1b hai khung kề nhau (11:00-12:00) được phép', '00000',
  $q$SELECT t_hold('p2@example.com','Sân 1','2026-12-01 11:00+07','2026-12-01 12:00+07')$q$);
-- nhả hold của p2 sau K1b để p2 dùng cho các kiểm tra tiếp theo
UPDATE schedule_entry SET is_active = false WHERE hold_id = (SELECT max(id) FROM hold);
UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = (SELECT max(id) FROM hold);

-- ---------- K2. Tất cả hoặc không có gì (Đúng một hold_id chứa cả 2 sân) ----------
DO $$
DECLARE
  n_before int; n_after int;
  v_fac_id bigint; v_c1 bigint; v_c2 bigint; v_u2 bigint; v_h bigint;
BEGIN
  SELECT count(*) INTO n_before FROM hold;
  SELECT id INTO v_fac_id FROM facility WHERE name = 'CS A';
  SELECT id INTO v_c1 FROM court WHERE name = 'Sân 1';
  SELECT id INTO v_c2 FROM court WHERE name = 'Sân 2';
  SELECT id INTO v_u2 FROM app_user WHERE email = 'p2@example.com';

  BEGIN
    -- giao dịch con: tạo ĐÚNG 1 hold_id (v_h), chèn dải hợp lệ trên Sân 2 và dải xung đột trên Sân 1 dưới cùng v_h
    INSERT INTO hold (user_id, facility_id, source)
      VALUES (v_u2, v_fac_id, 'APP') RETURNING id INTO v_h;
    INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
      VALUES
        (v_c2, v_fac_id, '2026-12-01 10:00+07', '2026-12-01 11:00+07', 'HOLD', v_h, 80000),
        (v_c1, v_fac_id, '2026-12-01 10:30+07', '2026-12-01 11:30+07', 'HOLD', v_h, 80000);
    RAISE EXCEPTION 'FAIL  K2 không bắt được xung đột trên Sân 1';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;

  SELECT count(*) INTO n_after FROM hold;
  IF n_before = n_after AND NOT EXISTS (SELECT 1 FROM schedule_entry WHERE court_id = v_c2 AND start_time = '2026-12-01 10:00+07') THEN
    RAISE NOTICE 'PASS  K2 một hold nhiều sân: một dải xung đột thì cả dòng hold và dải hợp lệ cùng hold_id đều bị hủy';
  ELSE RAISE EXCEPTION 'FAIL  K2 còn dữ liệu sót lại'; END IF;
END $$;

-- ---------- K3. Cấu trúc slot (gồm cả lệch 250 ms ở start_time và end_time), loại dòng, cùng cơ sở ----------
SELECT t_expect('K3a mốc 10:15 không phải bội của 30 phút', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:15+07','2026-12-01 11:00+07')$q$);
SELECT t_expect('K3a2 start_time lệch 250 ms (10:00:00.250) bị chặn', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:00:00.250+07','2026-12-01 11:00:00+07')$q$);
SELECT t_expect('K3a3 end_time lệch 250 ms (11:00:00.250) bị chặn', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:00:00+07','2026-12-01 11:00:00.250+07')$q$);
SELECT t_expect('K3b kết thúc không sau bắt đầu', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 11:00+07','2026-12-01 11:00+07')$q$);
SELECT t_expect('K3c dòng HOLD không được có booking_id', '23514',
  $q$INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,booking_id,unit_price)
     SELECT c.id,c.facility_id,'2026-12-02 10:00+07','2026-12-02 11:00+07','HOLD',1,1,80000 FROM court c WHERE name='Sân 2'$q$);
SELECT t_expect('K3d sân thuộc cơ sở khác hold bị chặn (DM-INV-01)', '23503',
  $q$INSERT INTO hold (user_id,facility_id,source) SELECT (SELECT id FROM app_user WHERE email='p2@example.com'), f.id, 'APP' FROM facility f WHERE f.name='CS A';
     INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,unit_price)
       SELECT c.id, (SELECT id FROM facility WHERE name='CS A'),'2026-12-02 10:00+07','2026-12-02 11:00+07','HOLD',(SELECT max(id) FROM hold),80000
       FROM court c WHERE c.name='Sân 3'$q$);
SELECT t_expect('K3e hai dải trùng start_time của cùng một sân trong một hold bị chặn (UNIQUE + EXCLUDE)', '23505',
  $q$INSERT INTO hold (user_id,facility_id,source) SELECT (SELECT id FROM app_user WHERE email='p2@example.com'), c.facility_id, 'APP' FROM court c WHERE c.name='Sân 2';
     INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,unit_price)
       SELECT c.id,c.facility_id,t.s,t.e,'HOLD',(SELECT max(id) FROM hold),80000
       FROM court c, (VALUES ('2026-12-03 10:00+07'::timestamptz,'2026-12-03 10:30+07'::timestamptz),
                             ('2026-12-03 10:00+07','2026-12-03 10:30+07')) t(s,e) WHERE c.name='Sân 2'$q$);

-- ---------- K4. Hạn hold ----------
SELECT t_expect('K4 expires_at khác created_at + 5 phút bị chặn (BR-01)', '23514',
  $q$INSERT INTO hold (user_id,facility_id,source,expires_at) SELECT (SELECT id FROM app_user WHERE email='p2@example.com'), c.facility_id, 'APP', now() + interval '10 minutes' FROM court c WHERE name='Sân 1'$q$);

-- ---------- K5. Xác nhận (giữ nguyên source & unit_price), hủy và giải phóng ----------
DO $$
DECLARE v_hold bigint; v_book bigint;
BEGIN
  -- nhả hold của p1 ở K1 trước khi tạo hold mới cho p1
  UPDATE schedule_entry SET is_active = false WHERE hold_id = 1;
  UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = 1;

  v_hold := t_hold('p1@example.com','Sân 2','2026-12-04 18:00+07','2026-12-04 19:00+07');
  -- xác nhận: hold -> CONFIRMED, tạo booking (kế thừa source từ hold), dòng HOLD -> BOOKING (vẫn chiếm chỗ & giữ unit_price)
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    SELECT h.id, h.user_id, h.facility_id, h.source FROM hold h WHERE h.id = v_hold RETURNING id INTO v_book;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_hold;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_book WHERE hold_id = v_hold;
  BEGIN
    PERFORM t_hold('p2@example.com','Sân 2','2026-12-04 18:30+07','2026-12-04 19:30+07');
    RAISE EXCEPTION 'FAIL  K5a booking đã xác nhận vẫn bị đặt đè';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K5a slot của booking đã xác nhận không đặt đè được';
  END;
  -- hủy bởi người chơi (kèm cancel_note tùy chọn): slot được nhả, lịch sử và unit_price vẫn còn
  UPDATE booking SET status='CANCELLED_BY_PLAYER', cancelled_at = now(), cancel_note = 'Bận việc đột xuất' WHERE id = v_book;
  UPDATE schedule_entry SET is_active = false WHERE booking_id = v_book;
  PERFORM t_hold('p2@example.com','Sân 2','2026-12-04 18:30+07','2026-12-04 19:30+07');
  UPDATE schedule_entry SET is_active = false WHERE hold_id = (SELECT max(id) FROM hold);
  UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = (SELECT max(id) FROM hold);
  IF EXISTS (SELECT 1 FROM schedule_entry WHERE booking_id = v_book AND NOT is_active AND unit_price = 80000) THEN
    RAISE NOTICE 'PASS  K5b hủy xong thì đặt lại được, lịch sử booking và unit_price còn nguyên';
  ELSE RAISE EXCEPTION 'FAIL  K5b mất lịch sử'; END IF;
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
    RAISE EXCEPTION 'FAIL  K6a khóa lịch đè lên hold đang giữ';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K6a khóa lịch bị chặn khi còn hold đang giữ (phải chờ)';
  END;
  UPDATE hold SET status='RELEASED', released_at = now() WHERE id = v_hold;
  UPDATE schedule_entry SET is_active = false WHERE hold_id = v_hold;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, blocked_by)
    SELECT c.id, c.facility_id, '2026-12-05 08:30+07', '2026-12-05 09:30+07', 'BLOCK', 1 FROM court c WHERE c.name='Sân 1';
  RAISE NOTICE 'PASS  K6b hold đã nhả thì khóa lịch được tạo';
  BEGIN
    PERFORM t_hold('p2@example.com','Sân 1','2026-12-05 09:00+07','2026-12-05 10:00+07');
    RAISE EXCEPTION 'FAIL  K6c hold đè lên khoảng bị khóa';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K6c hold không đè được khoảng bị khóa (DM-INV-08)';
  END;
END $$;
SELECT t_expect('K6d không có thao tác gỡ khóa (DB-ASM-07)', '23514',
  $q$UPDATE schedule_entry SET is_active = false WHERE entry_type = 'BLOCK'$q$);

-- ---------- K8. Hai slot liền nhau đi qua mốc đổi giá trên cùng sân (effective_from <= slot.startTime) ----------
DO $$
DECLARE
  v_c1 bigint; v_fac bigint; v_u1 bigint; v_hold bigint; v_book bigint;
  v_sched_sum numeric; v_hold_sum numeric; v_book_sum numeric;
BEGIN
  SELECT id, facility_id INTO v_c1, v_fac FROM court WHERE name = 'Sân 1';
  SELECT id INTO v_u1 FROM app_user WHERE email = 'p1@example.com';

  -- Chủ sân thêm mức giá mới 90.000đ có hiệu lực từ đúng 2026-12-06 18:30+07 (trước 18:30 vẫn là 80.000đ)
  INSERT INTO court_price (court_id, effective_from, amount_per_slot)
    VALUES (v_c1, '2026-12-06 18:30+07', 90000);

  -- 1. Tổng giá hiển thị trên lịch cho 2 slot 18:00-18:30 và 18:30-19:00
  SELECT SUM((SELECT cp.amount_per_slot FROM court_price cp WHERE cp.court_id = v_c1 AND cp.effective_from <= s.slot ORDER BY cp.effective_from DESC LIMIT 1))
    INTO v_sched_sum
    FROM generate_series('2026-12-06 18:00+07'::timestamptz, '2026-12-06 18:30+07'::timestamptz, interval '30 minutes') AS s(slot);

  -- 2. Tạo Hold gồm 2 slot liền nhau đi qua mốc đổi giá => lưu thành 2 dòng schedule_entry dưới cùng hold_id
  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_hold;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
  SELECT v_c1, v_fac, sel.s, sel.e, 'HOLD', v_hold,
         (SELECT cp.amount_per_slot FROM court_price cp WHERE cp.court_id = v_c1 AND cp.effective_from <= sel.s ORDER BY cp.effective_from DESC LIMIT 1)
    FROM (VALUES ('2026-12-06 18:00+07'::timestamptz, '2026-12-06 18:30+07'::timestamptz),
                 ('2026-12-06 18:30+07'::timestamptz, '2026-12-06 19:00+07'::timestamptz)) AS sel(s, e)
   ORDER BY sel.s;

  SELECT SUM(unit_price * (EXTRACT(EPOCH FROM (end_time - start_time))::bigint / 1800))
    INTO v_hold_sum FROM schedule_entry WHERE hold_id = v_hold;

  -- 3. Xác nhận thành Booking
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    SELECT id, user_id, facility_id, source FROM hold WHERE id = v_hold RETURNING id INTO v_book;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_hold;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_book WHERE hold_id = v_hold;

  SELECT SUM(unit_price * (EXTRACT(EPOCH FROM (end_time - start_time))::bigint / 1800))
    INTO v_book_sum FROM schedule_entry WHERE booking_id = v_book;

  IF v_sched_sum = 170000 AND v_hold_sum = 170000 AND v_book_sum = 170000 THEN
    RAISE NOTICE 'PASS  K8 hai slot liền nhau qua mốc đổi giá (80k + 90k = 170k) nhất quán giữa lịch, hold và booking';
  ELSE
    RAISE EXCEPTION 'FAIL  K8 lệch giá: sched=%, hold=%, book=%', v_sched_sum, v_hold_sum, v_book_sum;
  END IF;
END $$;

-- ---------- K9. Hủy đơn nhiều sân (Sân 1 & Sân 2) do khóa 1 khung giờ của Sân 1 -> thông báo chỉ gồm khung giờ đó ----------
DO $$
DECLARE
  v_c1 bigint; v_c2 bigint; v_fac bigint; v_u1 bigint; v_owner bigint;
  v_hold bigint; v_book bigint; v_notif bigint;
  v_items jsonb;
BEGIN
  SELECT id, facility_id INTO v_c1, v_fac FROM court WHERE name = 'Sân 1';
  SELECT id INTO v_c2 FROM court WHERE name = 'Sân 2';
  SELECT id INTO v_u1 FROM app_user WHERE email = 'p1@example.com';
  SELECT id INTO v_owner FROM app_user WHERE email = 'owner@example.com';

  -- Tạo và xác nhận đơn đặt 2 sân (Sân 1: 18:00-19:00, Sân 2: 18:00-19:00 ngày 2026-12-10)
  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_hold;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price) VALUES
    (v_c1, v_fac, '2026-12-10 18:00+07', '2026-12-10 19:00+07', 'HOLD', v_hold, 80000),
    (v_c2, v_fac, '2026-12-10 18:00+07', '2026-12-10 19:00+07', 'HOLD', v_hold, 80000);
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    VALUES (v_hold, v_u1, v_fac, 'APP') RETURNING id INTO v_book;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_hold;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_book WHERE hold_id = v_hold;

  -- Chủ sân khóa duy nhất khung 18:00-18:30 của Sân 1:
  -- 1) Chụp danh sách sân & khung giờ thực sự bị tác động trước/trong khi hủy toàn bộ đơn
  SELECT jsonb_agg(
           jsonb_build_object(
             'courtId', c.id::text,
             'courtName', c.name,
             'startTime', GREATEST(e.start_time, '2026-12-10 18:00+07'::timestamptz),
             'endTime',   LEAST(e.end_time,    '2026-12-10 18:30+07'::timestamptz)
           ) ORDER BY c.id, e.start_time
         )
    INTO v_items
    FROM schedule_entry e
    JOIN court c ON c.id = e.court_id
   WHERE e.booking_id = v_book AND e.is_active AND e.court_id = v_c1
     AND tstzrange(e.start_time, e.end_time, '[)') && tstzrange('2026-12-10 18:00+07'::timestamptz, '2026-12-10 18:30+07'::timestamptz, '[)');

  -- 2) Hủy cả đơn (cả Sân 1 và Sân 2 đều được giải phóng), chèn BLOCK và lưu notification kèm affected_items
  UPDATE booking SET status = 'CANCELLED_BY_OWNER', cancelled_at = now(), cancel_reason = 'BLOCKED_PERIOD' WHERE id = v_book;
  UPDATE schedule_entry SET is_active = false WHERE booking_id = v_book;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, blocked_by)
    VALUES (v_c1, v_fac, '2026-12-10 18:00+07', '2026-12-10 18:30+07', 'BLOCK', v_owner);
  INSERT INTO notification (user_id, booking_id, reason, message, affected_items)
    VALUES (v_u1, v_book, 'BLOCKED_PERIOD', 'Chủ sân bảo trì Sân 1.', v_items) RETURNING id INTO v_notif;

  IF jsonb_array_length(v_items) = 1
     AND (v_items->0->>'courtName') = 'Sân 1'
     AND (v_items->0->>'startTime')::timestamptz = '2026-12-10 18:00+07'::timestamptz
     AND (v_items->0->>'endTime')::timestamptz   = '2026-12-10 18:30+07'::timestamptz
     AND NOT EXISTS (SELECT 1 FROM schedule_entry WHERE booking_id = v_book AND is_active) THEN
    RAISE NOTICE 'PASS  K9 hủy cả đơn 2 sân do khóa 18:00-18:30 Sân 1: thông báo chỉ chứa đúng khung giờ đó của Sân 1';
  ELSE
    RAISE EXCEPTION 'FAIL  K9 sai danh sách bị ảnh hưởng: %', v_items;
  END IF;
END $$;

-- ---------- K7. Truy vấn khả dụng theo ngày (Q3) ----------
\echo --- Q3: trạng thái các slot của Sân 1, 08:00-10:00 ngày 2026-12-05 (08:30-09:30 là BLOCK của K6b) ---
SELECT to_char(s.slot AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') AS slot_bat_dau,
       CASE WHEN e.id IS NULL THEN 'available'
            WHEN e.entry_type = 'BLOCK' THEN 'unavailable'
            WHEN e.entry_type = 'BOOKING' THEN 'booked' ELSE 'held' END AS trang_thai
FROM court c
CROSS JOIN LATERAL generate_series('2026-12-05 08:00+07'::timestamptz, '2026-12-05 09:30+07', interval '30 minutes') AS s(slot)
LEFT JOIN schedule_entry e
       ON e.court_id = c.id AND e.is_active
      AND tstzrange(e.start_time, e.end_time, '[)') && tstzrange(s.slot, s.slot + interval '30 minutes', '[)')
WHERE c.name = 'Sân 1'
ORDER BY s.slot;