// Feste Avatar-Farbe pro Person (aus der Nutzer-ID berechnet): Zwei Personen
// mit gleichem Vornamen bekommen so unterschiedliche Farben - und jede Person
// sieht ueberall gleich aus.
import { hashString } from '@/utils/map';

export function avatarHue(id: string | null | undefined): number {
  return hashString(id ?? '') % 360;
}

export function avatarStyle(id: string | null | undefined): { background: string; color: string } {
  return { background: `hsl(${avatarHue(id)} 70% 62%)`, color: '#16140f' };
}
