// Darstellung: System / Hell / Dunkel. Die Wahl wird pro Geraet gemerkt.
import { Dark } from 'quasar';

export type ThemePref = 'system' | 'light' | 'dark';

const KEY = 'nx-theme';

export function parseThemePref(value: string | null | undefined): ThemePref {
  return value === 'light' || value === 'dark' ? value : 'system';
}

export function readThemePref(): ThemePref {
  try {
    return parseThemePref(localStorage.getItem(KEY));
  } catch {
    return 'system';
  }
}

// Fuer Quasar: true/false erzwingt den Modus, 'auto' folgt dem System.
export function toQuasarDark(pref: ThemePref): boolean | 'auto' {
  return pref === 'system' ? 'auto' : pref === 'dark';
}

function syncMetaThemeColor() {
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', Dark.isActive ? '#12110d' : '#f6f2eb');
}

export function applyThemePref(pref: ThemePref, persist = true): void {
  Dark.set(toQuasarDark(pref));
  syncMetaThemeColor();
  if (!persist) return;
  try {
    localStorage.setItem(KEY, pref);
  } catch {
    // z. B. privates Fenster - dann gilt die Wahl nur bis zum Neuladen
  }
}

// Folgt dem System auch dann, wenn es waehrend der Nutzung umschaltet.
export function watchSystemTheme(): void {
  window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', () => setTimeout(syncMetaThemeColor, 0));
}
