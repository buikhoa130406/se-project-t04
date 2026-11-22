-- =====================================================================
-- Kiểm tra ràng buộc của schema.sql trên PostgreSQL 16 (Task 3.1.2)
-- Chạy: psql -v ON_ERROR_STOP=1 -d <db> -f schema.sql -f schema-check.sql
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
  SELECT id, '2026-01-01 00:00+07', 100000 FROM court;

CREATE FUNCTION t_hold(p_email text, p_court text, p_start timestamptz, p_end timestamptz)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_h bigint; v_c court;
BEGIN
  SELECT * INTO v_c FROM court WHERE name = p_court;
  INSERT INTO hold (user_id, facility_id, source)
    SELECT id, v_c.facility_id, 'APP' FROM app_user WHERE email = p_email RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
    VALUES (v_c.id, v_c.facility_id, p_start, p_end, 'HOLD', v_h, 100000);
  RETURN v_h;
END $$;

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
    INSERT INTO hold (user_id, facility_id, source)
      VALUES (v_u2, v_fac_id, 'APP') RETURNING id INTO v_h;
    INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
      VALUES
        (v_c2, v_fac_id, '2026-12-01 10:00+07', '2026-12-01 11:00+07', 'HOLD', v_h, 100000),
        (v_c1, v_fac_id, '2026-12-01 10:30+07', '2026-12-01 11:30+07', 'HOLD', v_h, 100000);
    RAISE EXCEPTION 'FAIL  K2 không bắt được xung đột trên Sân 1';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;

  SELECT count(*) INTO n_after FROM hold;
  IF n_before = n_after AND NOT EXISTS (SELECT 1 FROM schedule_entry WHERE court_id = v_c2 AND start_time = '2026-12-01 10:00+07') THEN
    RAISE NOTICE 'PASS  K2 một hold nhiều sân: một dải xung đột thì cả dòng hold và dải hợp lệ cùng hold_id đều bị hủy';
  ELSE RAISE EXCEPTION 'FAIL  K2 còn dữ liệu sót lại'; END IF;
END $$;

-- ---------- K3. Cấu trúc slot, mốc 30 phút (kể cả lệch 250 ms), loại dòng, cùng cơ sở ----------
SELECT t_expect('K3a mốc 10:15 không phải bội của 30 phút', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:15+07','2026-12-01 11:00+07')$q$);
SELECT t_expect('K3a_ms start_time lệch 250 ms (10:00:00.250) bị chặn', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:00:00.250+07','2026-12-01 11:00:00+07')$q$);
SELECT t_expect('K3a_ms2 end_time lệch 250 ms (11:00:00.250) bị chặn', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 10:00:00+07','2026-12-01 11:00:00.250+07')$q$);
SELECT t_expect('K3b kết thúc không sau bắt đầu', '23514',
  $q$SELECT t_hold('p2@example.com','Sân 2','2026-12-01 11:00+07','2026-12-01 11:00+07')$q$);
SELECT t_expect('K3c dòng HOLD không được có booking_id', '23514',
  $q$INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,booking_id,unit_price)
     SELECT c.id,c.facility_id,'2026-12-02 10:00+07','2026-12-02 11:00+07','HOLD',1,1,100000 FROM court c WHERE name='Sân 2'$q$);
SELECT t_expect('K3d sân thuộc cơ sở khác hold bị chặn (DM-INV-01)', '23503',
  $q$INSERT INTO hold (user_id,facility_id,source) SELECT (SELECT id FROM app_user WHERE email='p2@example.com'), f.id, 'APP' FROM facility f WHERE f.name='CS A';
     INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,unit_price)
       SELECT c.id, (SELECT id FROM facility WHERE name='CS A'),'2026-12-02 10:00+07','2026-12-02 11:00+07','HOLD',(SELECT max(id) FROM hold),100000
       FROM court c WHERE c.name='Sân 3'$q$);
SELECT t_expect('K3e hai dải đang hoạt động trùng start_time của cùng một sân bị chặn trước bởi EXCLUDE (23P01)', '23P01',
  $q$INSERT INTO hold (user_id,facility_id,source) SELECT (SELECT id FROM app_user WHERE email='p2@example.com'), c.facility_id, 'APP' FROM court c WHERE c.name='Sân 2';
     INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,unit_price)
       SELECT c.id,c.facility_id,t.s,t.e,'HOLD',(SELECT max(id) FROM hold),100000
       FROM court c, (VALUES ('2026-12-03 10:00+07'::timestamptz,'2026-12-03 10:30+07'::timestamptz),
                             ('2026-12-03 10:00+07'::timestamptz,'2026-12-03 10:30+07'::timestamptz)) t(s,e) WHERE c.name='Sân 2'$q$);
SELECT t_expect('K3e2 dòng cũ đã nhả, dòng mới trùng (hold_id, court_id, start_time) bị chặn bởi UNIQUE (23505)', '23505',
  $q$DO $$
     DECLARE v_h bigint; v_c bigint; v_f bigint;
     BEGIN
       SELECT id, facility_id INTO v_c, v_f FROM court WHERE name='Sân 2';
       INSERT INTO hold (user_id,facility_id,source) SELECT id, v_f, 'APP' FROM app_user WHERE email='p2@example.com' RETURNING id INTO v_h;
       INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,unit_price,is_active)
         VALUES (v_c, v_f, '2026-12-03 11:00+07', '2026-12-03 11:30+07', 'HOLD', v_h, 100000, false);
       INSERT INTO schedule_entry (court_id,facility_id,start_time,end_time,entry_type,hold_id,unit_price,is_active)
         VALUES (v_c, v_f, '2026-12-03 11:00+07', '2026-12-03 12:00+07', 'HOLD', v_h, 100000, true);
     END $$ $q$);

-- ---------- K4. Hạn hold ----------
SELECT t_expect('K4 expires_at khác created_at + 5 phút bị chặn (BR-01)', '23514',
  $q$INSERT INTO hold (user_id,facility_id,source,expires_at) SELECT (SELECT id FROM app_user WHERE email='p2@example.com'), c.facility_id, 'APP', now() + interval '10 minutes' FROM court c WHERE name='Sân 1'$q$);

-- ---------- K5. Xác nhận, hủy và giải phóng ----------
DO $$
DECLARE v_hold bigint; v_book bigint;
BEGIN
  UPDATE schedule_entry SET is_active = false WHERE hold_id = 1;
  UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = 1;

  v_hold := t_hold('p1@example.com','Sân 2','2026-12-04 18:00+07','2026-12-04 19:00+07');
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    SELECT h.id, h.user_id, h.facility_id, h.source FROM hold h WHERE h.id = v_hold RETURNING id INTO v_book;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_hold;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_book WHERE hold_id = v_hold;
  BEGIN
    PERFORM t_hold('p2@example.com','Sân 2','2026-12-04 18:30+07','2026-12-04 19:30+07');
    RAISE EXCEPTION 'FAIL  K5a booking đã xác nhận vẫn bị đặt đè';
  EXCEPTION WHEN exclusion_violation THEN RAISE NOTICE 'PASS  K5a slot của booking đã xác nhận không đặt đè được';
  END;
  UPDATE booking SET status='CANCELLED_BY_PLAYER', cancelled_at = now(), cancel_note = 'Bận việc đột xuất' WHERE id = v_book;
  UPDATE schedule_entry SET is_active = false WHERE booking_id = v_book;
  PERFORM t_hold('p2@example.com','Sân 2','2026-12-04 18:30+07','2026-12-04 19:30+07');
  UPDATE schedule_entry SET is_active = false WHERE hold_id = (SELECT max(id) FROM hold);
  UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = (SELECT max(id) FROM hold);
  IF EXISTS (SELECT 1 FROM schedule_entry WHERE booking_id = v_book AND NOT is_active AND unit_price = 100000) THEN
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

-- ---------- K8 & K8b. Giá theo từng slot qua mốc đổi giá ----------
DO $$
DECLARE
  v_c1 bigint; v_fac bigint; v_u1 bigint; v_h bigint; v_b bigint; v_total numeric; v_rows int;
BEGIN
  SELECT id, facility_id INTO v_c1, v_fac FROM court WHERE name = 'Sân 1';
  SELECT id INTO v_u1 FROM app_user WHERE email = 'p1@example.com';

  UPDATE court_price SET amount_per_slot = 100000 WHERE court_id = v_c1;
  INSERT INTO court_price (court_id, effective_from, amount_per_slot)
    VALUES (v_c1, '2026-12-10 18:30+07', 120000);

  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
  SELECT v_c1, v_fac, sel.s, sel.e, 'HOLD', v_h,
         (SELECT cp.amount_per_slot FROM court_price cp
           WHERE cp.court_id = v_c1 AND cp.effective_from <= sel.s
           ORDER BY cp.effective_from DESC LIMIT 1)
    FROM (VALUES ('2026-12-10 18:00+07'::timestamptz, '2026-12-10 18:30+07'::timestamptz),
                 ('2026-12-10 18:30+07'::timestamptz, '2026-12-10 19:00+07'::timestamptz)) AS sel(s, e);

  INSERT INTO booking (hold_id, user_id, facility_id, source)
    SELECT id, user_id, facility_id, source FROM hold WHERE id = v_h RETURNING id INTO v_b;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_h;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_b WHERE hold_id = v_h;

  SELECT count(*), SUM(unit_price * (EXTRACT(EPOCH FROM (end_time - start_time))::bigint / 1800))
    INTO v_rows, v_total FROM schedule_entry WHERE booking_id = v_b;

  IF v_rows = 2 AND v_total = 220000 THEN
    RAISE NOTICE 'PASS  K8 hai slot liền nhau qua mốc đổi giá (100k + 120k = 220k) tách thành 2 dải nhất quán';
  ELSE
    RAISE EXCEPTION 'FAIL  K8 kết quả không khớp: rows=%, total=%', v_rows, v_total;
  END IF;

  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
    VALUES (v_c1, v_fac, '2026-12-10 19:00+07', '2026-12-10 20:00+07', 'HOLD', v_h, 120000);
  SELECT count(*), SUM(unit_price * (EXTRACT(EPOCH FROM (end_time - start_time))::bigint / 1800))
    INTO v_rows, v_total FROM schedule_entry WHERE hold_id = v_h;
  UPDATE schedule_entry SET is_active = false WHERE hold_id = v_h;
  UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = v_h;

  IF v_rows = 1 AND v_total = 240000 THEN
    RAISE NOTICE 'PASS  K8b hai slot sau mốc đổi giá giữ nguyên 1 dải (240k)';
  ELSE
    RAISE EXCEPTION 'FAIL  K8b kết quả không khớp: rows=%, total=%', v_rows, v_total;
  END IF;
END $$;

-- ---------- K10..K10d. Kiểm tra slot liền nhau trên từng sân (BR-03) ----------
DO $$
DECLARE
  v_c1 bigint; v_c2 bigint; v_fac bigint; v_u1 bigint; v_h bigint; v_has_err boolean;
BEGIN
  SELECT id, facility_id INTO v_c1, v_fac FROM court WHERE name = 'Sân 1';
  SELECT id INTO v_c2 FROM court WHERE name = 'Sân 2';
  SELECT id INTO v_u1 FROM app_user WHERE email = 'p1@example.com';

  -- K10: Chọn 18:00 và 19:00 trên Sân 1 (bỏ 18:30) -> phát hiện khoảng hở
  SELECT EXISTS (
    SELECT 1 FROM (
      SELECT s, lag(e) OVER (PARTITION BY c ORDER BY s) AS prev_e
        FROM (VALUES (v_c1, '2026-12-11 18:00+07'::timestamptz, '2026-12-11 18:30+07'::timestamptz),
                     (v_c1, '2026-12-11 19:00+07'::timestamptz, '2026-12-11 19:30+07'::timestamptz)) sel(c, s, e)
    ) q WHERE prev_e IS NOT NULL AND prev_e <> s
  ) INTO v_has_err;
  IF v_has_err THEN RAISE NOTICE 'PASS  K10 chọn 18:00 và 19:00 trên cùng sân (bỏ 18:30) bị phát hiện';
  ELSE RAISE EXCEPTION 'FAIL  K10 không phát hiện khoảng hở'; END IF;

  -- K10b: Hai item chồng nhau -> phát hiện
  SELECT EXISTS (
    SELECT 1 FROM (
      SELECT s, lag(e) OVER (PARTITION BY c ORDER BY s) AS prev_e
        FROM (VALUES (v_c1, '2026-12-11 18:00+07'::timestamptz, '2026-12-11 19:00+07'::timestamptz),
                     (v_c1, '2026-12-11 18:30+07'::timestamptz, '2026-12-11 19:30+07'::timestamptz)) sel(c, s, e)
    ) q WHERE prev_e IS NOT NULL AND prev_e <> s
  ) INTO v_has_err;
  IF v_has_err THEN RAISE NOTICE 'PASS  K10b hai item chồng nhau trên cùng sân bị phát hiện';
  ELSE RAISE EXCEPTION 'FAIL  K10b không phát hiện chồng nhau'; END IF;

  -- K10c: 18:00 và 18:30 liền nhau trên Sân 1 -> hợp lệ
  SELECT EXISTS (
    SELECT 1 FROM (
      SELECT s, lag(e) OVER (PARTITION BY c ORDER BY s) AS prev_e
        FROM (VALUES (v_c1, '2026-12-11 18:00+07'::timestamptz, '2026-12-11 18:30+07'::timestamptz),
                     (v_c1, '2026-12-11 18:30+07'::timestamptz, '2026-12-11 19:00+07'::timestamptz)) sel(c, s, e)
    ) q WHERE prev_e IS NOT NULL AND prev_e <> s
  ) INTO v_has_err;
  IF NOT v_has_err THEN RAISE NOTICE 'PASS  K10c chọn 18:00 và 18:30 liền nhau trên cùng sân hợp lệ';
  ELSE RAISE EXCEPTION 'FAIL  K10c báo sai khoảng hở'; END IF;

  -- K10c2: Sân 1 (18:00-18:30) và Sân 2 (19:00-19:30) khác sân -> hợp lệ
  SELECT EXISTS (
    SELECT 1 FROM (
      SELECT s, lag(e) OVER (PARTITION BY c ORDER BY s) AS prev_e
        FROM (VALUES (v_c1, '2026-12-11 18:00+07'::timestamptz, '2026-12-11 18:30+07'::timestamptz),
                     (v_c2, '2026-12-11 19:00+07'::timestamptz, '2026-12-11 19:30+07'::timestamptz)) sel(c, s, e)
    ) q WHERE prev_e IS NOT NULL AND prev_e <> s
  ) INTO v_has_err;
  IF NOT v_has_err THEN RAISE NOTICE 'PASS  K10c2 khác sân có khung giờ khác nhau vẫn hợp lệ';
  ELSE RAISE EXCEPTION 'FAIL  K10c2 báo sai khoảng hở giữa hai sân'; END IF;

  -- K10d: DB tự nó vẫn chấp nhận 2 dải cách nhau nếu dịch vụ không chặn trước
  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
    VALUES (v_c1, v_fac, '2026-12-12 18:00+07', '2026-12-12 18:30+07', 'HOLD', v_h, 100000),
           (v_c1, v_fac, '2026-12-12 19:00+07', '2026-12-12 19:30+07', 'HOLD', v_h, 100000);
  UPDATE schedule_entry SET is_active = false WHERE hold_id = v_h;
  UPDATE hold SET status = 'RELEASED', released_at = now() WHERE id = v_h;
  RAISE NOTICE 'PASS  K10d DB tự nó cho phép hai dải cách nhau nên bước kiểm tra lựa chọn ở dịch vụ là bắt buộc';
END $$;

-- ---------- K9, K9b, K9c. Thông báo hủy (affected_items) ----------
DO $$
DECLARE
  v_c1 bigint; v_c2 bigint; v_fac bigint; v_u1 bigint; v_owner bigint;
  v_h bigint; v_b bigint; v_items jsonb;
BEGIN
  SELECT id, facility_id INTO v_c1, v_fac FROM court WHERE name = 'Sân 1';
  SELECT id INTO v_c2 FROM court WHERE name = 'Sân 2';
  SELECT id INTO v_u1 FROM app_user WHERE email = 'p1@example.com';
  SELECT id INTO v_owner FROM app_user WHERE email = 'owner@example.com';

  -- K9: Khóa 18:00-18:30 Sân 1 hủy đơn 2 sân -> affected_items chỉ gồm Sân 1 (18:00-18:30)
  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
    VALUES (v_c1, v_fac, '2026-12-15 18:00+07', '2026-12-15 19:00+07', 'HOLD', v_h, 100000),
           (v_c2, v_fac, '2026-12-15 18:00+07', '2026-12-15 19:00+07', 'HOLD', v_h, 100000);
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    VALUES (v_h, v_u1, v_fac, 'APP') RETURNING id INTO v_b;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_h;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_b WHERE hold_id = v_h;

  SELECT jsonb_agg(jsonb_build_object(
           'courtId', e.court_id::text,
           'courtName', c.name,
           'startTime', GREATEST(e.start_time, '2026-12-15 18:00+07'::timestamptz),
           'endTime',   LEAST(e.end_time,   '2026-12-15 18:30+07'::timestamptz)
         ))
    INTO v_items
    FROM schedule_entry e JOIN court c ON c.id = e.court_id
   WHERE e.booking_id = v_b AND e.is_active AND e.court_id = v_c1
     AND tstzrange(e.start_time, e.end_time, '[)') && tstzrange('2026-12-15 18:00+07'::timestamptz, '2026-12-15 18:30+07'::timestamptz, '[)');

  UPDATE booking SET status = 'CANCELLED_BY_OWNER', cancelled_at = now(), cancel_reason = 'BLOCKED_PERIOD' WHERE id = v_b;
  UPDATE schedule_entry SET is_active = false WHERE booking_id = v_b;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, blocked_by)
    VALUES (v_c1, v_fac, '2026-12-15 18:00+07', '2026-12-15 18:30+07', 'BLOCK', v_owner);
  INSERT INTO notification (user_id, booking_id, reason, message, affected_items)
    VALUES (v_u1, v_b, 'BLOCKED_PERIOD', 'Chủ sân khóa Sân 1 khung 18:00-18:30', v_items);

  IF jsonb_array_length(v_items) = 1 AND (v_items->0->>'courtId') = v_c1::text THEN
    RAISE NOTICE 'PASS  K9 hủy đơn 2 sân do khóa 18:00-18:30 Sân 1: thông báo chỉ chứa đúng khung giờ đó của Sân 1';
  ELSE
    RAISE EXCEPTION 'FAIL  K9 dữ liệu thông báo hủy không khớp: %', v_items;
  END IF;

  -- K9b: Xóa Sân 2 liệt kê đúng dải trên Sân 2
  INSERT INTO hold (user_id, facility_id, source) VALUES (v_u1, v_fac, 'APP') RETURNING id INTO v_h;
  INSERT INTO schedule_entry (court_id, facility_id, start_time, end_time, entry_type, hold_id, unit_price)
    VALUES (v_c1, v_fac, '2026-12-16 18:00+07', '2026-12-16 19:00+07', 'HOLD', v_h, 100000),
           (v_c2, v_fac, '2026-12-16 18:00+07', '2026-12-16 19:00+07', 'HOLD', v_h, 100000);
  INSERT INTO booking (hold_id, user_id, facility_id, source)
    VALUES (v_h, v_u1, v_fac, 'APP') RETURNING id INTO v_b;
  UPDATE hold SET status = 'CONFIRMED' WHERE id = v_h;
  UPDATE schedule_entry SET entry_type = 'BOOKING', booking_id = v_b WHERE hold_id = v_h;

  SELECT jsonb_agg(jsonb_build_object('courtId', e.court_id::text, 'courtName', c.name, 'startTime', e.start_time, 'endTime', e.end_time))
    INTO v_items
    FROM schedule_entry e JOIN court c ON c.id = e.court_id
   WHERE e.booking_id = v_b AND e.is_active AND e.court_id = v_c2;

  UPDATE booking SET status = 'CANCELLED_BY_OWNER', cancelled_at = now(), cancel_reason = 'COURT_DELETED' WHERE id = v_b;
  UPDATE schedule_entry SET is_active = false WHERE booking_id = v_b;
  INSERT INTO notification (user_id, booking_id, reason, message, affected_items)
    VALUES (v_u1, v_b, 'COURT_DELETED', 'Chủ sân xóa Sân 2', v_items);

  IF jsonb_array_length(v_items) = 1 AND (v_items->0->>'courtId') = v_c2::text THEN
    RAISE NOTICE 'PASS  K9b xóa Sân 2 liệt kê đúng dải bị ảnh hưởng trên Sân 2';
  ELSE
    RAISE EXCEPTION 'FAIL  K9b dữ liệu thông báo xóa sân không khớp: %', v_items;
  END IF;
END $$;

-- K9c: affected_items bắt buộc là mảng JSON
SELECT t_expect('K9c affected_items không phải mảng JSON bị chặn', '23514',
  $q$INSERT INTO notification (user_id, booking_id, reason, message, affected_items)
     VALUES ((SELECT min(id) FROM app_user), (SELECT min(id) FROM booking), 'BLOCKED_PERIOD', 'test', '{}'::jsonb)$q$);

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
