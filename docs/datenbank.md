# Datenbank-Architektur: Community-Austausch

Dieses Dokument beschreibt das Datenbankschema, die Supabase-Einrichtung und
die Anbindung ans statische Astro-Frontend für die Austausch-Funktion auf
`www.fishertechservice.ch/austausch/`.

---

## Warum Supabase?

Die Webseite wird rein statisch über GitHub Pages ausgeliefert – es gibt keinen
laufenden Node- oder Python-Server. Ein klassisches selbst-gehostetes Postgres
oder MySQL wäre nur über ein eigenes Backend erreichbar, das hier nicht
existiert.

**Supabase** löst dieses Problem elegant:

| Merkmal | Supabase | Alternative: Firebase/Firestore |
|---------|----------|----------------------------------|
| Datenbank | Vollwertiges PostgreSQL | Proprietäres NoSQL (Dokumente) |
| Abfragesprache | Standard-SQL, PostgREST REST-API | Firebase SDK, keine SQL-Joins |
| Sicherheit | Row Level Security (RLS) direkt in Postgres | Firestore Security Rules |
| Echtzeit | Eingebaut via Postgres Logical Replication | Eingebaut via WebSocket |
| Auth | Integriert (Email, OAuth, Magic Link) | Firebase Auth |
| Preismodell | Grosszügiges Free-Tier (500 MB DB, 50k MAU) | Free-Tier vorhanden, aber teurer bei Wachstum |
| SQL-Vertrautheit | Hoch – Standard-Postgres-DDL | Gering – eigenes Datenmodell |

**Fazit:** Supabase gibt uns volles Postgres mit RLS, sodass die statische Seite
direkt und sicher mit der Datenbank kommunizieren kann. Die anon-Key-Konfiguration
im Browser ist sicher, weil RLS alle unberechtigten Zugriffe auf Datenbankebene
blockiert.

---

## Schema-Übersicht

```
auth.users (Supabase-intern)
    │  1:1 (CASCADE)
    ▼
profiles
    │  1:N (SET NULL bei Löschung)
    ├──► posts ◄─── posts (self-referenz: parent_post_id für Antworten)
    │
    ├──► conversation_participants ◄──► conversations
    │
    └──► conversation_messages
```

### Tabellen

| Tabelle | Zweck |
|---------|-------|
| `profiles` | Öffentliche Nutzerprofile (an auth.users gekoppelt) |
| `posts` | Forum-Beiträge und Antworten (threaded via parent_post_id) |
| `conversations` | Private Konversationen (1:1 oder Gruppe) |
| `conversation_participants` | Wer nimmt an welcher Konversation teil |
| `conversation_messages` | Chat-Nachrichten innerhalb einer Konversation |

### Thread-Modell für Forum-Posts

Ein `posts`-Eintrag mit `parent_post_id = NULL` ist ein Haupt-Beitrag (Thread-Eröffnung).
Ein Eintrag mit gesetzter `parent_post_id` ist eine Antwort. Beispiel aus dem Mockup:

```
post id=1, parent=NULL   → "Meine Spinnrute fühlt sich nicht mehr sauber an" (Thomas Müller)
  post id=2, parent=1   → "Häufig sind abgenutzte Ringe..." (V. Ivic)
post id=3, parent=NULL   → "Wie oft lasst ihr eure Rollen warten?" (Gabriel Eric)
```

### Rollen

| Rolle | Rechte |
|-------|--------|
| `member` | Beiträge lesen, eigene Beiträge erstellen/bearbeiten/soft-löschen |
| `moderator` | Alle Beiträge verbergen (`is_hidden`), hart löschen |
| `admin` | Wie moderator + Profilbearbeitung anderer Nutzer |

Der Betreiber (V. Ivic) sollte die Rolle `admin` erhalten (manuell in Supabase Dashboard).

---

## Supabase-Einrichtung (Schritt für Schritt)

### 1. Supabase-Projekt erstellen

1. Konto auf [supabase.com](https://supabase.com) anlegen (kostenlos)
2. Neues Projekt erstellen: Name z.B. `fishertechservice`, Region `eu-central-1` (Frankfurt)
3. Ein sicheres Datenbankpasswort wählen und sicher aufbewahren

### 2. Migrationen anwenden

**Option A: Supabase-Dashboard (einfach, kein CLI nötig)**

1. Dashboard öffnen → SQL Editor
2. Die vier Migrations-Dateien der Reihe nach ausführen:
   - `supabase/migrations/20260627000001_profiles.sql`
   - `supabase/migrations/20260627000002_posts.sql`
   - `supabase/migrations/20260627000003_conversations.sql`
   - `supabase/migrations/20260627000004_rls_policies.sql`
3. Jede Datei kopieren, in den SQL Editor einfügen und auf "Run" klicken

**Option B: Supabase CLI (empfohlen für Entwicklung)**

```bash
# CLI installieren
npm install -g supabase

# Projekt initialisieren (einmalig)
supabase init

# Mit dem Supabase-Projekt verknüpfen
supabase link --project-ref <dein-projekt-ref>
# Projekt-Ref findest du im Dashboard unter Project Settings → General

# Migrationen anwenden
supabase db push
```

### 3. Betreiber-Konto als Admin markieren

Nach der ersten Registrierung auf der Webseite:

1. Supabase Dashboard → Table Editor → `profiles`
2. Eigenen Eintrag suchen (via `username` oder `display_name`)
3. Spalte `rolle` auf `admin` setzen

Alternativ per SQL im SQL Editor:

```sql
UPDATE public.profiles
SET rolle = 'admin'
WHERE username = 'v.ivic';  -- eigenen Username anpassen
```

### 4. Auth-Einstellungen konfigurieren

Dashboard → Authentication → Settings:

- **Site URL:** `https://www.fishertechservice.ch`
- **Redirect URLs:** `https://www.fishertechservice.ch/austausch/`
- **Email-Provider:** aktiviert (Standard)
- Optional: OAuth-Provider (Google, GitHub) aktivieren

---

## Umgebungsvariablen

Die Zugangsdaten findest du im Supabase Dashboard unter
**Project Settings → API**.

Für die lokale Entwicklung `.env.local` anlegen (wird von `.gitignore` ignoriert):

```env
PUBLIC_SUPABASE_URL=https://dein-projekt-id.supabase.co
PUBLIC_SUPABASE_ANON_KEY=dein-anon-key
```

Für die GitHub-Pages-Deployments (kein Server → Variablen ins Build einbetten):

```bash
# In astro.config.mjs oder direkt im Frontend-Code referenzieren:
# import.meta.env.PUBLIC_SUPABASE_URL
# import.meta.env.PUBLIC_SUPABASE_ANON_KEY
```

**Sicherheitshinweis zu öffentlichen Schlüsseln:**

Der `anon key` ist bewusst öffentlich. Er darf ins Frontend und in den
Git-Repository (`.env.example`), denn er gibt ohne gültige Anmeldung nur
Lesezugriff auf Tabellen, die RLS-seitig öffentlich sind (z.B. Forum-Posts).

Der `service_role key` ist ein Backend-Schlüssel, der RLS umgeht und
**niemals** ins Frontend oder einen öffentlichen Repository darf.

---

## Row Level Security – Zusammenfassung

| Tabelle | Lesen | Erstellen | Bearbeiten | Löschen |
|---------|-------|-----------|------------|---------|
| `profiles` | Jeder | Eigenes | Eigenes / Admin | Eigenes / Admin |
| `posts` | Jeder (aktive) | Angemeldete | Eigene / Mod | Nur Moderatoren (hard) |
| `conversations` | Teilnehmer | Angemeldete | Ersteller / Mod | Nur Moderatoren |
| `conversation_participants` | Teilnehmer | Teilnehmer / Ersteller | Eigener Eintrag | Selbst / Mod |
| `conversation_messages` | Teilnehmer | Teilnehmer | Eigene / Mod | Nur Moderatoren (hard) |

Soft-Delete (Autor): `posts.deleted_at` und `conversation_messages.deleted_at`
werden per UPDATE gesetzt. Das Frontend zeigt dann "(Beitrag gelöscht)" an.

---

## Frontend-Anbindung (nächste Schritte)

Diese Schritte sind noch nicht implementiert – nur Hinweise für die
spätere JS-Integration:

### 1. Supabase-Client installieren

```bash
npm install @supabase/supabase-js
```

### 2. Client initialisieren (z.B. `src/lib/supabase.ts`)

```typescript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  import.meta.env.PUBLIC_SUPABASE_URL,
  import.meta.env.PUBLIC_SUPABASE_ANON_KEY
)
```

### 3. Forum-Posts laden (öffentlich, kein Login nötig)

```typescript
// Alle Haupt-Beiträge mit Autoren-Info, neueste zuerst
const { data: threads } = await supabase
  .from('posts')
  .select(`
    id, content, created_at,
    profiles ( display_name, avatar_url )
  `)
  .is('parent_post_id', null)
  .is('deleted_at', null)
  .eq('is_hidden', false)
  .order('created_at', { ascending: false })
  .limit(20)
```

### 4. Antworten laden

```typescript
const { data: replies } = await supabase
  .from('posts')
  .select(`id, content, created_at, profiles ( display_name, avatar_url )`)
  .eq('parent_post_id', threadId)
  .is('deleted_at', null)
  .order('created_at', { ascending: true })
```

### 5. Echtzeit-Updates (optional)

Supabase Realtime erlaubt Live-Updates ohne Seiten-Reload:

```typescript
supabase
  .channel('posts')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'posts'
  }, (payload) => {
    // Neuen Post in die UI einfügen
  })
  .subscribe()
```

### 6. Auth-Flow (Registrierung / Login)

Da die Seite statisch ist, läuft Auth über Supabase's eigene Flows:
- Magic Link (E-Mail)
- OAuth (Google, GitHub)
- Email + Passwort

Der Supabase-Client verwaltet die Session im `localStorage`. Beim Laden der
Seite `supabase.auth.getSession()` aufrufen.

---

## Migrations-Dateien

```
supabase/migrations/
├── 20260627000001_profiles.sql       # Benutzerprofile + Auth-Trigger
├── 20260627000002_posts.sql          # Forum-Posts & Antworten
├── 20260627000003_conversations.sql  # Private Chats
└── 20260627000004_rls_policies.sql   # Sicherheitsrichtlinien
```

Ausführungsreihenfolge: 001 → 002 → 003 → 004 (Abhängigkeiten beachten).

---

## Datenschutz / DSGVO

- Passwörter werden nie gespeichert – Supabase Auth verwaltet Hashes intern
- Bei Nutzer-Löschung: `profiles` wird per CASCADE gelöscht, Posts/Nachrichten
  behalten `author_id = NULL` (anonymisiert, Inhalte bleiben für Kontext erhalten)
- Soft-Delete: Nutzer können Inhalte als "gelöscht" markieren ohne harte Löschung
- Auf expliziten Wunsch (DSGVO Art. 17) kann ein Admin `deleted_at` setzen und
  den `content` durch einen Platzhalter ersetzen
