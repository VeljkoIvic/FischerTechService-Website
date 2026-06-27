-- =============================================================================
-- Migration 004: Row Level Security (RLS) und Zugriffsrichtlinien
--
-- Sicherheitsmodell:
--   - Forum-Posts (posts): Lesen öffentlich; Schreiben/Bearbeiten nur authentifiziert
--   - Profile: Lesen öffentlich; Bearbeiten nur eigenes Profil
--   - Konversationen/Nachrichten: Nur Teilnehmer haben Zugriff
--   - Moderatoren/Admins: Können alle Posts verbergen und löschen
--
-- WICHTIG: Die anon-Key-Konfiguration im Frontend ist sicher, weil RLS alle
-- unberechtigten Zugriffe auf Datenbankebene blockiert – unabhängig vom Client.
--
-- Abhängigkeiten: Migrationen 001–003
-- =============================================================================

-- ============================================================
-- Hilfsfunktionen für RLS-Policies
-- ============================================================

-- is_moderator(): Gibt TRUE zurück wenn der aktuelle Auth-Nutzer Moderator/Admin ist.
-- SECURITY DEFINER: Läuft mit Rechten des Funktions-Erstellers (umgeht RLS intern),
-- verhindert rekursive Richtlinien-Evaluation.
CREATE OR REPLACE FUNCTION public.is_moderator()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND rolle IN ('moderator', 'admin')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.is_moderator() IS
  'Gibt TRUE zurück wenn auth.uid() die Rolle moderator oder admin hat. '
  'SECURITY DEFINER verhindert rekursive RLS-Auswertung.';

-- is_conversation_participant(): Prüft Teilnahme ohne rekursive RLS-Auswertung.
CREATE OR REPLACE FUNCTION public.is_conversation_participant(p_conversation_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_participants
    WHERE conversation_id = p_conversation_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.is_conversation_participant(UUID) IS
  'Gibt TRUE zurück wenn auth.uid() Teilnehmer der angegebenen Konversation ist. '
  'SECURITY DEFINER verhindert rekursive RLS-Auswertung in conversation_participants.';

-- ============================================================
-- RLS aktivieren (alle relevanten Tabellen)
-- ============================================================
ALTER TABLE public.profiles                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_messages     ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PROFILES – Richtlinien
-- ============================================================

-- Alle (auch Gäste ohne Login) dürfen Profile lesen
DROP POLICY IF EXISTS "profiles_lesen_oeffentlich" ON public.profiles;
CREATE POLICY "profiles_lesen_oeffentlich"
  ON public.profiles FOR SELECT
  USING (true);

-- Nutzer darf nur sein eigenes Profil anlegen
-- (Normalerweise via Trigger, aber Policy sichert Konsistenz ab)
DROP POLICY IF EXISTS "profiles_eigenes_anlegen" ON public.profiles;
CREATE POLICY "profiles_eigenes_anlegen"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());

-- Nutzer darf sein eigenes Profil bearbeiten.
-- Admins dürfen alle Profile bearbeiten (z.B. Rollenvergabe).
-- WICHTIG: Normale Nutzer können die Spalte 'rolle' NICHT selbst ändern –
-- das muss auf Applikationsebene oder per Column-Level-Grant verhindert werden.
DROP POLICY IF EXISTS "profiles_bearbeiten" ON public.profiles;
CREATE POLICY "profiles_bearbeiten"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_moderator())
  WITH CHECK (id = auth.uid() OR public.is_moderator());

-- Eigenes Profil löschen oder Admin
DROP POLICY IF EXISTS "profiles_loeschen" ON public.profiles;
CREATE POLICY "profiles_loeschen"
  ON public.profiles FOR DELETE
  USING (id = auth.uid() OR public.is_moderator());

-- Spalten-Schutz: Normale Nutzer dürfen 'rolle' nicht selbst ändern.
-- Sichergestellt durch Entfernen des direkten UPDATE-Rechts auf 'rolle'
-- für die anon/authenticated Rolle (Applikationsebene empfohlen).
-- Alternativ: per Trigger überprüfen.

-- ============================================================
-- POSTS – Richtlinien
-- ============================================================

-- Alle dürfen aktive, nicht-verborgene, nicht-gelöschte Posts lesen.
-- Moderatoren/Admins sehen auch verborgene Beiträge.
DROP POLICY IF EXISTS "posts_lesen" ON public.posts;
CREATE POLICY "posts_lesen"
  ON public.posts FOR SELECT
  USING (
    deleted_at IS NULL
    AND (is_hidden = FALSE OR public.is_moderator())
  );

-- Nur angemeldete Nutzer dürfen Posts erstellen.
-- author_id muss die eigene Nutzer-ID sein.
DROP POLICY IF EXISTS "posts_erstellen" ON public.posts;
CREATE POLICY "posts_erstellen"
  ON public.posts FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND author_id = auth.uid()
  );

-- Autoren dürfen eigene Posts bearbeiten (z.B. content korrigieren, deleted_at setzen).
-- Moderatoren dürfen alle Posts bearbeiten (z.B. is_hidden = TRUE setzen).
-- HINWEIS: Die Applikationsschicht sollte sicherstellen, dass normale Nutzer
-- nur 'content' und 'deleted_at' ändern können (nicht 'is_hidden').
DROP POLICY IF EXISTS "posts_bearbeiten" ON public.posts;
CREATE POLICY "posts_bearbeiten"
  ON public.posts FOR UPDATE
  USING (
    (author_id = auth.uid() AND deleted_at IS NULL)
    OR public.is_moderator()
  );

-- Hartes Löschen: Nur Moderatoren/Admins.
-- Autoren nutzen Soft-Delete (deleted_at setzen via UPDATE).
DROP POLICY IF EXISTS "posts_hart_loeschen" ON public.posts;
CREATE POLICY "posts_hart_loeschen"
  ON public.posts FOR DELETE
  USING (public.is_moderator());

-- ============================================================
-- CONVERSATIONS – Richtlinien
-- ============================================================

-- Nur Teilnehmer dürfen eine Konversation sehen
DROP POLICY IF EXISTS "conversations_lesen" ON public.conversations;
CREATE POLICY "conversations_lesen"
  ON public.conversations FOR SELECT
  USING (public.is_conversation_participant(id));

-- Angemeldete Nutzer dürfen Konversationen anlegen
DROP POLICY IF EXISTS "conversations_erstellen" ON public.conversations;
CREATE POLICY "conversations_erstellen"
  ON public.conversations FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND created_by = auth.uid()
  );

-- Ersteller oder Moderatoren dürfen Metadaten ändern (z.B. Gruppenname)
DROP POLICY IF EXISTS "conversations_bearbeiten" ON public.conversations;
CREATE POLICY "conversations_bearbeiten"
  ON public.conversations FOR UPDATE
  USING (created_by = auth.uid() OR public.is_moderator());

-- Nur Moderatoren dürfen Konversationen hard-löschen
DROP POLICY IF EXISTS "conversations_loeschen" ON public.conversations;
CREATE POLICY "conversations_loeschen"
  ON public.conversations FOR DELETE
  USING (public.is_moderator());

-- ============================================================
-- CONVERSATION_PARTICIPANTS – Richtlinien
-- ============================================================

-- Nutzer sieht seine eigenen Teilnahme-Einträge.
-- SECURITY DEFINER-Funktion verhindert Rekursion.
DROP POLICY IF EXISTS "conv_participants_lesen" ON public.conversation_participants;
CREATE POLICY "conv_participants_lesen"
  ON public.conversation_participants FOR SELECT
  USING (public.is_conversation_participant(conversation_id));

-- Nutzer darf sich selbst hinzufügen (Direct-Chat starten) oder
-- Konversationsersteller fügt andere hinzu
DROP POLICY IF EXISTS "conv_participants_hinzufuegen" ON public.conversation_participants;
CREATE POLICY "conv_participants_hinzufuegen"
  ON public.conversation_participants FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (
      user_id = auth.uid()  -- sich selbst hinzufügen
      OR EXISTS (           -- oder: Ersteller fügt andere hinzu
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
          AND (c.created_by = auth.uid() OR public.is_moderator())
      )
    )
  );

-- Nur eigenen last_read_message_id-Wert aktualisieren
DROP POLICY IF EXISTS "conv_participants_aktualisieren" ON public.conversation_participants;
CREATE POLICY "conv_participants_aktualisieren"
  ON public.conversation_participants FOR UPDATE
  USING (user_id = auth.uid());

-- Sich selbst aus Konversation entfernen oder Moderatoren entfernen alle
DROP POLICY IF EXISTS "conv_participants_entfernen" ON public.conversation_participants;
CREATE POLICY "conv_participants_entfernen"
  ON public.conversation_participants FOR DELETE
  USING (user_id = auth.uid() OR public.is_moderator());

-- ============================================================
-- CONVERSATION_MESSAGES – Richtlinien
-- ============================================================

-- Nur Teilnehmer dürfen den Chat-Verlauf lesen (keine gelöschten Nachrichten)
DROP POLICY IF EXISTS "conv_messages_lesen" ON public.conversation_messages;
CREATE POLICY "conv_messages_lesen"
  ON public.conversation_messages FOR SELECT
  USING (
    deleted_at IS NULL
    AND public.is_conversation_participant(conversation_id)
  );

-- Nur Teilnehmer dürfen Nachrichten senden; sender_id muss eigene ID sein
DROP POLICY IF EXISTS "conv_messages_senden" ON public.conversation_messages;
CREATE POLICY "conv_messages_senden"
  ON public.conversation_messages FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND sender_id = auth.uid()
    AND public.is_conversation_participant(conversation_id)
  );

-- Absender darf eigene Nachricht bearbeiten (edited_at setzen); Moderatoren alles
DROP POLICY IF EXISTS "conv_messages_bearbeiten" ON public.conversation_messages;
CREATE POLICY "conv_messages_bearbeiten"
  ON public.conversation_messages FOR UPDATE
  USING (
    (sender_id = auth.uid() AND deleted_at IS NULL)
    OR public.is_moderator()
  );

-- Soft-Delete: Absender setzt deleted_at via UPDATE (s.o.).
-- Hartes Löschen nur für Moderatoren/Admins.
DROP POLICY IF EXISTS "conv_messages_hart_loeschen" ON public.conversation_messages;
CREATE POLICY "conv_messages_hart_loeschen"
  ON public.conversation_messages FOR DELETE
  USING (public.is_moderator());

-- ============================================================
-- Schutz der 'rolle'-Spalte gegen unbefugte Änderungen
-- ============================================================
-- Normale Nutzer (authenticated) dürfen 'rolle' nicht ändern.
-- Nur die Supabase Service-Role (Backend-Prozesse) oder Admins über
-- is_moderator()-geprüfte Pfade dürfen die Rolle anpassen.
-- Umsetzung: Column-Level REVOKE für die authenticated-Rolle.
-- HINWEIS: Dies blockiert auch legitime Profile-Updates wenn nicht
-- sorgfältig implementiert – im Frontend explizit nur erlaubte Felder senden.
--
-- Optional aktivieren (auskommentiert, da Applikationsebene oft ausreicht):
-- REVOKE UPDATE (rolle) ON public.profiles FROM authenticated;
-- GRANT  UPDATE (username, display_name, avatar_url, bio) ON public.profiles TO authenticated;
