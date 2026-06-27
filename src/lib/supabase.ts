// =============================================================================
// Supabase-Client für den Community-Austausch
//
// Liest die öffentlichen Zugangsdaten aus den Umgebungsvariablen
// (siehe .env.example / .env.local). Beide Werte sind bewusst öffentlich –
// die Sicherheit läuft über Row Level Security (RLS) in der Datenbank.
//
// Wichtig: Da die Seite rein statisch über GitHub Pages ausgeliefert wird,
// werden diese Variablen zum BUILD-Zeitpunkt eingebettet (import.meta.env).
// Sind sie nicht gesetzt, bleibt `supabase` null und das Frontend zeigt
// einen Konfigurations-Hinweis statt zu crashen.
// =============================================================================

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL as string | undefined;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY as string | undefined;

/** TRUE wenn die Supabase-Zugangsdaten konfiguriert sind. */
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

/**
 * Der gemeinsam genutzte Supabase-Client. `null`, solange keine
 * Zugangsdaten konfiguriert sind (z.B. lokaler Build ohne .env.local).
 */
export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl as string, supabaseAnonKey as string, {
      auth: {
        // Session im localStorage halten und automatisch erneuern.
        persistSession: true,
        autoRefreshToken: true,
        // Magic-Link / OAuth-Rückläufer aus der URL automatisch verarbeiten.
        detectSessionInUrl: true,
      },
    })
  : null;
