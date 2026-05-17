-- =====================================================
-- Görünürlük Ayarları Kolonları
-- =====================================================
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_profile_public   BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_active_status  BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_email          BOOLEAN NOT NULL DEFAULT false;

-- =====================================================
-- Bildirim Ayarları Kolonları
-- =====================================================
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notif_push_enabled  BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_email_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_messages      BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_connections   BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_team_updates  BOOLEAN NOT NULL DEFAULT true;
