-- Operational replay-result store for API-01; separate from the 12 business tables.
-- Apply after schema.sql. No application handler is implemented by this file.
CREATE TABLE api_request_result (
  user_id       bigint NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  method        text NOT NULL CHECK (btrim(method) <> ''),
  path          text NOT NULL CHECK (btrim(path) <> ''),
  request_key   uuid NOT NULL,
  request_hash  text NOT NULL CHECK (btrim(request_hash) <> ''),
  status        text NOT NULL DEFAULT 'IN_PROGRESS'
                CHECK (status IN ('IN_PROGRESS', 'COMPLETED')),
  http_status   smallint,
  response_body jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  retain_until  timestamptz NOT NULL DEFAULT now() + interval '24 hours',
  PRIMARY KEY (user_id, method, path, request_key),
  CHECK (retain_until >= created_at + interval '24 hours'),
  CHECK (
    (status = 'IN_PROGRESS' AND http_status IS NULL AND response_body IS NULL)
    OR
    (status = 'COMPLETED' AND http_status BETWEEN 200 AND 599
     AND http_status IS NOT NULL AND response_body IS NOT NULL)
  )
);
CREATE INDEX api_request_result_retention_idx ON api_request_result (retain_until);

-- Request processing acquires pg_try_advisory_xact_lock using a stable hash
-- of the complete (user_id, method, path, request_key) scope before replay lookup.
-- The primary key remains the exact, collision-free identity of the record.
-- An advisory-lock hash collision can only cause a transient in-flight response.
-- A new IN_PROGRESS record, the business mutation and the COMPLETED result
-- are committed together. A failed transaction rolls them all back.
-- At completion retain_until is set to clock_timestamp() + interval '24 hours'.
-- Cleanup removes only completed rows whose retain_until is in the past.
