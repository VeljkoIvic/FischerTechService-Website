-- =============================================================================
-- Migration 002: Diskussions-Posts und Antworten (Threaded-Modell)
--
-- Modell: Adjacency-List (Eltern-Kind-Beziehung in derselben Tabelle).
--   parent_post_id = NULL  → Haupt-Beitrag (Thread-Eröffnung)
--   parent_post_id = <id>  → Antwort auf diesen Post
--
-- Diese Struktur entspricht dem aktuellen Mockup auf austausch.astro:
-- Haupt-Beiträge (z.B. "Meine Spinnrute fühlt sich nicht mehr sauber an")
-- mit direkten Antworten darunter (z.B. die Antwort des Betreibers).
--
-- Erweiterung auf tieferes Nesting ist möglich, ohne das Schema zu ändern.
-- Für sehr tiefe Bäume (>3 Ebenen) wäre ein Closure-Table effizienter –
-- für diese Community-Grösse ist Adjacency-List ausreichend.
--
-- Abhängigkeiten: Migration 001 (public.profiles, update_updated_at_column)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.posts (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Autor: SET NULL bei Profil-Löschung → DSGVO-konformes Anonymisieren.
  -- Der Beitrag bleibt sichtbar, author_id wird zu NULL ("Gelöschter Nutzer").
  author_id      UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,

  -- Eltern-Post: NULL = Haupt-Beitrag; gesetzt = Antwort.
  -- CASCADE: Wenn ein Haupt-Thread gelöscht wird, werden alle Antworten mitgelöscht.
  parent_post_id UUID        REFERENCES public.posts(id) ON DELETE CASCADE,

  -- Inhalt: 1–5000 Zeichen. Leerzeilen am Rand werden getrimmt.
  content        TEXT        NOT NULL
                               CHECK (
                                 char_length(trim(content)) >= 1
                                 AND char_length(content) <= 5000
                               ),

  -- Moderations-Flag: TRUE = Beitrag nur für Moderatoren/Admins sichtbar
  is_hidden      BOOLEAN     NOT NULL DEFAULT FALSE,

  -- Zeitstempel
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Soft-Delete: Autor setzt deleted_at statt den Datensatz hart zu löschen.
  -- Vorteil: Antwortkette bleibt intakt; Audit-Trail erhalten.
  -- Im Frontend: Beiträge mit deleted_at IS NOT NULL als "(Beitrag gelöscht)" anzeigen.
  deleted_at     TIMESTAMPTZ
);

COMMENT ON TABLE  public.posts                   IS 'Forum-Beiträge und Antworten für die Austausch-Seite. parent_post_id = NULL = Thread-Eröffnung.';
COMMENT ON COLUMN public.posts.author_id         IS 'NULL wenn Nutzer sein Konto gelöscht hat (DSGVO). Beiträge bleiben anonymisiert erhalten.';
COMMENT ON COLUMN public.posts.parent_post_id    IS 'NULL = Haupt-Beitrag (Thread). Gesetzt = Antwort auf den referenzierten Post (CASCADE-Löschen).';
COMMENT ON COLUMN public.posts.is_hidden         IS 'TRUE = versteckter Beitrag, nur für Moderatoren/Admins sichtbar (z.B. gemeldeter Inhalt).';
COMMENT ON COLUMN public.posts.deleted_at        IS 'Soft-Delete durch Autor. NULL = aktiv. Frontend zeigt "(Beitrag gelöscht)" wenn gesetzt.';

-- ----------------------------------------------------------------------------
-- Indizes – optimiert für die häufigsten Abfragemuster
-- ----------------------------------------------------------------------------

-- Alle Haupt-Beiträge, neueste zuerst (Startseite Austausch)
CREATE INDEX IF NOT EXISTS posts_toplevel_created_at_idx
  ON public.posts (created_at DESC)
  WHERE parent_post_id IS NULL AND deleted_at IS NULL AND is_hidden = FALSE;

-- Antworten zu einem bestimmten Post, chronologisch (Reply-Thread)
CREATE INDEX IF NOT EXISTS posts_replies_idx
  ON public.posts (parent_post_id, created_at ASC)
  WHERE deleted_at IS NULL;

-- Alle Beiträge eines Autors (Profil-Seite)
CREATE INDEX IF NOT EXISTS posts_author_id_idx
  ON public.posts (author_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- Trigger: updated_at automatisch aktualisieren
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS posts_updated_at ON public.posts;
CREATE TRIGGER posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
