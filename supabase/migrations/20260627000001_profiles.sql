-- =============================================================================
-- Migration 001: Benutzerprofile
-- Erstellt die öffentliche profiles-Tabelle, die 1:1 an Supabase auth.users
-- gekoppelt ist. Ein Trigger legt beim Registrieren automatisch ein Profil an.
--
-- Abhängigkeiten: Supabase-interne auth.users-Tabelle (immer vorhanden)
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Hilfsfunktion: updated_at automatisch setzen
-- Wird von allen Tabellen-Triggern in dieser und späteren Migrationen genutzt.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_updated_at_column() IS
  'Setzt updated_at automatisch auf NOW() bei jedem UPDATE. Wird von mehreren Tabellen-Triggern genutzt.';

-- ----------------------------------------------------------------------------
-- Hilfsfunktion: Profil bei Nutzer-Registrierung automatisch anlegen
-- Supabase ruft diesen Trigger nach jedem INSERT in auth.users auf.
-- Der username wird aus den user_metadata oder der E-Mail-Adresse abgeleitet.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  basis_username TEXT;
BEGIN
  -- Username aus Metadaten lesen oder aus E-Mail ableiten
  basis_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    split_part(NEW.email, '@', 1)
  );

  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    basis_username,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      basis_username
    )
  )
  ON CONFLICT (id) DO NOTHING; -- Idempotenz: kein Fehler bei Doppelaufruf

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Wird per Trigger nach auth.users INSERT ausgeführt. Legt automatisch ein Profil an.';

-- ----------------------------------------------------------------------------
-- Tabelle: profiles
-- Enthält die öffentlich sichtbaren Nutzerdaten. Verweise auf diesen
-- Datensatz aus posts, messages etc. via profiles.id (= auth.users.id).
-- DSGVO: Beim Löschen des auth.users-Eintrags wird das Profil per CASCADE
-- mitgelöscht. Posts/Nachrichten behalten author_id = NULL (SET NULL).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username     TEXT        UNIQUE NOT NULL
                             CHECK (
                               char_length(username) BETWEEN 3 AND 30
                               AND username ~ '^[a-zA-Z0-9_\-\.]+$'
                             ),
  display_name TEXT        NOT NULL
                             CHECK (char_length(display_name) BETWEEN 1 AND 80),
  avatar_url   TEXT,
  bio          TEXT        CHECK (char_length(bio) <= 500),
  -- Rolle: member = normaler Nutzer, moderator = kann Beiträge verbergen/löschen,
  --        admin = voller Zugriff inkl. Rollenvergabe
  rolle        TEXT        NOT NULL DEFAULT 'member'
                             CHECK (rolle IN ('member', 'moderator', 'admin')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.profiles              IS 'Öffentliche Benutzerprofile, 1:1 verknüpft mit Supabase auth.users.';
COMMENT ON COLUMN public.profiles.id           IS 'Gleiche UUID wie auth.users.id. Beim Löschen des Auth-Nutzers wird das Profil per CASCADE entfernt.';
COMMENT ON COLUMN public.profiles.username     IS 'Einzigartiger Kurzname (Handle). Nur Buchstaben, Zahlen, Unterstrich, Bindestrich, Punkt. 3–30 Zeichen.';
COMMENT ON COLUMN public.profiles.display_name IS 'Angezeigter Name im Forum (z.B. "V. Ivic · FisherTechService"). Max. 80 Zeichen.';
COMMENT ON COLUMN public.profiles.avatar_url   IS 'Öffentliche URL zum Profilbild (z.B. Supabase Storage oder externer CDN).';
COMMENT ON COLUMN public.profiles.bio          IS 'Kurze Selbstbeschreibung, max. 500 Zeichen.';
COMMENT ON COLUMN public.profiles.rolle        IS 'member = normaler Nutzer, moderator = Moderationsrechte, admin = Vollzugriff.';

-- Index: username-Suche (für @Erwähnungen, Profil-Lookup)
CREATE INDEX IF NOT EXISTS profiles_username_idx ON public.profiles (username);

-- Trigger: updated_at automatisch aktualisieren
DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger: Bei Supabase-Registrierung automatisch Profil anlegen
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
