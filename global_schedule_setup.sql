-- ================================================================
-- global_schedule: source of truth untuk slot Book Call VIP 1:1
-- Slot available → frontend sesi/index.html tampilkan
-- Slot booked → diupdate oleh edge function calendly-book
-- AI query langsung: SELECT * FROM global_schedule WHERE is_available = true
-- ================================================================

CREATE TABLE IF NOT EXISTS global_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_date date NOT NULL,
  slot_time time NOT NULL,
  is_available boolean NOT NULL DEFAULT true,
  booked_by_name text,
  booked_by_email text,
  booked_by_phone text,
  calendly_event_uri text,
  booking_url text,
  booked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (slot_date, slot_time)
);

CREATE INDEX IF NOT EXISTS idx_global_schedule_date_avail
  ON global_schedule (slot_date, is_available);

-- RLS: public read (frontend butuh), write hanya via service_role (edge function)
ALTER TABLE global_schedule ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read schedule" ON global_schedule;
CREATE POLICY "Public read schedule" ON global_schedule
  FOR SELECT USING (true);

-- ================================================================
-- SEED: 14 hari ke depan, Senin-Jumat, jam 10/13/15 WIB
-- Aman re-run (pakai ON CONFLICT DO NOTHING)
-- ================================================================

INSERT INTO global_schedule (slot_date, slot_time, is_available)
SELECT
  d::date AS slot_date,
  t::time AS slot_time,
  true AS is_available
FROM generate_series(
  (CURRENT_DATE + INTERVAL '1 day'),
  (CURRENT_DATE + INTERVAL '21 days'),
  '1 day'
) AS d
CROSS JOIN (VALUES ('10:00'), ('13:00'), ('15:00')) AS slots(t)
WHERE EXTRACT(DOW FROM d) NOT IN (0, 6)  -- skip Minggu (0) & Sabtu (6)
ON CONFLICT (slot_date, slot_time) DO NOTHING;

-- Cek hasil seed:
-- SELECT slot_date, slot_time, is_available FROM global_schedule ORDER BY slot_date, slot_time;
