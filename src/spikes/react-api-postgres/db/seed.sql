CREATE TABLE IF NOT EXISTS courtconnect_spike_court (
    id smallint PRIMARY KEY,
    name text NOT NULL,
    price_vnd integer NOT NULL CHECK (price_vnd >= 0)
);

INSERT INTO courtconnect_spike_court (id, name, price_vnd)
VALUES (1, 'Sân mẫu CourtConnect', 80000)
ON CONFLICT (id) DO NOTHING;
