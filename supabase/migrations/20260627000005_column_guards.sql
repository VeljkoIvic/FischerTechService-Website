-- =============================================================================
-- Migration 005: Spalten-Schutz gegen Privilege Escalation
--
-- HINTERGRUND (kritische Sicherheitslücke vor dieser Migration):
--   Die UPDATE-Policies in Migration 004 erlauben Nutzern, ihre eigene Zeile
--   zu ändern (profiles: id = auth.uid(), posts: author_id = auth.uid()).
--   Policies können jedoch nicht einzelne SPALTEN einschränken. Dadurch konnte
--   jeder angemeldete Nutzer:
--     - sein eigenes profiles.rolle auf 'admin' setzen  → volle Moderationsrechte
--     - posts.is_hidden seiner eigenen Beiträge umschalten
--   Die in Migration 004 vorgeschlagene REVOKE-Variante war nur auskommentiert.
--
-- LÖSUNG:
--   BEFORE-UPDATE-Trigger, die eine Änderung der privilegierten Spalten nur
--   zulassen, wenn der aktuelle Nutzer Moderator/Admin ist (is_moderator()).
--   Trigger sind robuster als Column-Grants: sie greifen unabhängig von der
--   Rollen-/Grant-Konfiguration und überleben spätere Schema-Änderungen.
--
-- Abhängigkeiten: Migration 001 (profiles), 002 (posts), 004 (is_moderator())
-- =============================================================================

-- ----------------------------------------------------------------------------
-- profiles.rolle: nur Moderatoren/Admins dürfen die Rolle ändern
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.profiles_guard_rolle()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rolle IS DISTINCT FROM OLD.rolle AND NOT public.is_moderator() THEN
    RAISE EXCEPTION 'Keine Berechtigung, die Spalte "rolle" zu ändern.'
      USING ERRCODE = '42501'; -- insufficient_privilege
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.profiles_guard_rolle() IS
  'BEFORE-UPDATE-Guard: blockiert Änderungen an profiles.rolle für Nicht-Moderatoren. '
  'Verhindert Privilege Escalation über die eigene Profilzeile.';

DROP TRIGGER IF EXISTS profiles_protect_rolle ON public.profiles;
CREATE TRIGGER profiles_protect_rolle
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_guard_rolle();

-- ----------------------------------------------------------------------------
-- posts.is_hidden: nur Moderatoren/Admins dürfen Beiträge verbergen/einblenden
-- (Autoren nutzen weiterhin Soft-Delete via deleted_at.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.posts_guard_is_hidden()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_hidden IS DISTINCT FROM OLD.is_hidden AND NOT public.is_moderator() THEN
    RAISE EXCEPTION 'Keine Berechtigung, die Spalte "is_hidden" zu ändern.'
      USING ERRCODE = '42501'; -- insufficient_privilege
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.posts_guard_is_hidden() IS
  'BEFORE-UPDATE-Guard: blockiert Änderungen an posts.is_hidden für Nicht-Moderatoren.';

DROP TRIGGER IF EXISTS posts_protect_is_hidden ON public.posts;
CREATE TRIGGER posts_protect_is_hidden
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.posts_guard_is_hidden();
