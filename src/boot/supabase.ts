import { createClient } from '@supabase/supabase-js';
import { defineBoot } from '#q-app';

const supabaseUrl = import.meta.env.QCLI_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.QCLI_SUPABASE_ANON_KEY;

// Ohne Zugangsdaten (z. B. im automatischen Build) startet die App mit einem
// Platzhalter; echte Werte stehen in .env (siehe .env.example).
if (!supabaseUrl || !supabaseAnonKey) {
  console.warn(
    'Supabase-Zugangsdaten fehlen. QCLI_SUPABASE_URL und QCLI_SUPABASE_ANON_KEY in .env setzen (siehe .env.example).',
  );
}

export const supabase = createClient(
  supabaseUrl || 'https://placeholder.supabase.co',
  supabaseAnonKey || 'placeholder-anon-key',
  {
    auth: {
      // PKCE: Links aus E-Mails (Bestaetigung, Passwort zuruecksetzen) kommen
      // als "?code=..." zurueck. Das vertraegt sich mit den "#/seite"-Adressen
      // der App; die aeltere Variante haengt ihre Daten ebenfalls hinter "#".
      flowType: 'pkce',
    },
  },
);

// Wurde die App ueber einen "Passwort zuruecksetzen"-Link geoeffnet?
// Muss sofort hier abonniert werden: Supabase meldet das Ereignis direkt beim
// Start, noch bevor Router und Stores bereit sind. Der Router leitet dann auf
// die Seite "Neues Passwort" um (siehe router/index.ts).
export const recovery = { pending: false };
supabase.auth.onAuthStateChange((event) => {
  if (event === 'PASSWORD_RECOVERY') recovery.pending = true;
});

export default defineBoot(() => {
  // Der Client steht ueber `import { supabase } from '@/boot/supabase'` bereit.
});
