-- =============================================================================
-- Migration 003: Private Konversationen und Direktnachrichten
--
-- Ermöglicht 1:1-Chats und Gruppen-Chats zwischen angemeldeten Nutzern.
-- Tabellen-Struktur:
--   conversations              → Eine Konversation (Metadaten, Typ)
--   conversation_participants  → Wer nimmt teil? (n:m, PK = conversation+user)
--   conversation_messages      → Die eigentlichen Nachrichten
--
-- Besonderheit: last_read_message_id in conversation_participants referenziert
-- conversation_messages. Da dies eine Vorwärts-Referenz wäre, wird der FK
-- nachträglich per ALTER TABLE gesetzt (nach Anlage von conversation_messages).
--
-- Abhängigkeiten: Migration 001 (public.profiles, update_updated_at_column)
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: conversations
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Typ: 'direct' = 1:1-Chat zwischen zwei Nutzern,
  --      'group'  = Gruppenchat mit optionalem Namen
  type        TEXT        NOT NULL DEFAULT 'direct'
                            CHECK (type IN ('direct', 'group')),

  -- Name nur sinnvoll bei Gruppen-Chats
  name        TEXT        CHECK (
                            (type = 'group' AND name IS NOT NULL AND char_length(name) <= 100)
                            OR (type = 'direct')
                          ),

  -- Ersteller der Konversation (SET NULL wenn gelöscht, Konversation bleibt bestehen)
  created_by  UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.conversations           IS 'Private Konversationen zwischen Nutzern (1:1 oder Gruppe).';
COMMENT ON COLUMN public.conversations.type      IS 'direct = Zwei-Personen-Chat, group = Gruppenchat.';
COMMENT ON COLUMN public.conversations.name      IS 'Nur bei type = group relevant. Max. 100 Zeichen.';
COMMENT ON COLUMN public.conversations.created_by IS 'Ersteller der Konversation. NULL wenn Nutzer gelöscht.';

DROP TRIGGER IF EXISTS conversations_updated_at ON public.conversations;
CREATE TRIGGER conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ----------------------------------------------------------------------------
-- Tabelle: conversation_participants
-- Verknüpft Nutzer mit Konversationen (n:m).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversation_participants (
  conversation_id      UUID        NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id              UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Letzte gelesene Nachricht (für "Ungelesen"-Badge im Frontend).
  -- FK zu conversation_messages wird nach deren Anlage gesetzt (s.u.).
  last_read_message_id UUID,

  joined_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (conversation_id, user_id)
);

COMMENT ON TABLE  public.conversation_participants                       IS 'Teilnehmer einer Konversation. PK = (conversation_id, user_id).';
COMMENT ON COLUMN public.conversation_participants.last_read_message_id  IS 'Letzte vom Nutzer gelesene Nachricht. Ermöglicht "X ungelesene Nachrichten"-Badge.';

-- Index: Alle Konversationen eines Nutzers finden
CREATE INDEX IF NOT EXISTS conv_participants_user_id_idx
  ON public.conversation_participants (user_id);

-- ----------------------------------------------------------------------------
-- Tabelle: conversation_messages
-- Die eigentlichen Chat-Nachrichten.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversation_messages (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID        NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,

  -- Absender: SET NULL bei Profil-Löschung → DSGVO-Anonymisierung
  sender_id       UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,

  -- Inhalt: 1–2000 Zeichen
  content         TEXT        NOT NULL
                                CHECK (
                                  char_length(trim(content)) >= 1
                                  AND char_length(content) <= 2000
                                ),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Bearbeitet: NULL = nie bearbeitet; gesetzt = Zeitpunkt der letzten Änderung
  edited_at       TIMESTAMPTZ,

  -- Soft-Delete: Frontend zeigt "(Nachricht gelöscht)" wenn gesetzt
  deleted_at      TIMESTAMPTZ
);

COMMENT ON TABLE  public.conversation_messages             IS 'Nachrichten innerhalb einer Konversation (Chat-Verlauf).';
COMMENT ON COLUMN public.conversation_messages.sender_id  IS 'NULL wenn Nutzer gelöscht wurde (DSGVO-Anonymisierung). Nachricht bleibt als "(Nachricht von gelöschtem Nutzer)" erhalten.';
COMMENT ON COLUMN public.conversation_messages.edited_at  IS 'NULL = nie bearbeitet. Gesetzt = Zeitpunkt der letzten Bearbeitung (Frontend kann "bearbeitet" anzeigen).';
COMMENT ON COLUMN public.conversation_messages.deleted_at IS 'Soft-Delete. Frontend ersetzt Inhalt durch "(Nachricht gelöscht)".';

-- Indizes – optimiert für Chat-History-Abfragen
-- Cursor/Keyset-Pagination: WHERE created_at < :cursor ORDER BY created_at DESC LIMIT 50
CREATE INDEX IF NOT EXISTS conv_messages_conversation_created_at_idx
  ON public.conversation_messages (conversation_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS conv_messages_sender_id_idx
  ON public.conversation_messages (sender_id)
  WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- Nachträglicher FK: last_read_message_id → conversation_messages
-- Konnte nicht beim Anlegen von conversation_participants gesetzt werden,
-- da conversation_messages damals noch nicht existierte.
-- ----------------------------------------------------------------------------
ALTER TABLE public.conversation_participants
  DROP CONSTRAINT IF EXISTS fk_last_read_message;

ALTER TABLE public.conversation_participants
  ADD CONSTRAINT fk_last_read_message
  FOREIGN KEY (last_read_message_id)
  REFERENCES public.conversation_messages(id)
  ON DELETE SET NULL;

-- Unique-Constraint für Direct-Chats: Zwei Nutzer können nur EINE gemeinsame
-- 1:1-Konversation haben. Erzwungen über eine partielle Unique-Bedingung auf
-- Applikationsebene (oder per Trigger). Hinweis im Kommentar:
-- Beim Anlegen eines Direct-Chats im Frontend zuerst prüfen, ob bereits eine
-- Konversation vom type='direct' mit denselben zwei Teilnehmern existiert.
COMMENT ON TABLE public.conversations IS
  'Private Konversationen zwischen Nutzern (1:1 oder Gruppe). '
  'HINWEIS: Für type=direct vor dem Anlegen prüfen, ob bereits eine Konversation '
  'mit denselben zwei Teilnehmern existiert (kein DB-Unique-Constraint wegen n:m-Teilnehmertabelle).';
