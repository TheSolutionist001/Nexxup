// Reine Logik rund um Events (ohne Datenbank) - siehe tests/unit/events.test.ts

interface Timed {
  id: string;
  starts_at: string;
  duration_minutes: number;
}

export function eventEnd(e: Timed): Date {
  return new Date(new Date(e.starts_at).getTime() + e.duration_minutes * 60_000);
}

// Ueberschneiden sich zwei Events zeitlich? (direkt aneinander anschliessend zaehlt nicht)
export function overlaps(a: Timed, b: Timed): boolean {
  return new Date(a.starts_at) < eventEnd(b) && new Date(b.starts_at) < eventEnd(a);
}

/**
 * Terminueberschneidungen: alle Events, bei denen ich schon zugesagt habe
 * (oder einen Platz angeboten bekam) und die sich mit `target` ueberschneiden.
 */
export function findConflicts<T extends Timed & { my_status: string | null }>(target: Timed, mine: T[]): T[] {
  return mine.filter(
    (e) => e.id !== target.id && (e.my_status === 'going' || e.my_status === 'offered') && overlaps(target, e),
  );
}

// Freie Plaetze (null = unbegrenzt)
export function spotsLeft(max: number | null, taken: number): number | null {
  return max === null ? null : Math.max(0, max - taken);
}

// Kurzer Text zur Belegung: "3 dabei" / "3 von 10 dabei" / "Voll · 2 warten"
export function occupancyLabel(max: number | null, going: number, waiting: number): string {
  if (max === null) return `${going} dabei`;
  if (going >= max) return waiting > 0 ? `Voll · ${waiting} warten` : 'Voll';
  return `${going} von ${max} dabei`;
}

// Verbleibende Minuten eines Platz-Angebots (mindestens 0)
export function offerMinutesLeft(expiresAt: string | null, now: Date = new Date()): number {
  if (!expiresAt) return 0;
  return Math.max(0, Math.ceil((new Date(expiresAt).getTime() - now.getTime()) / 60_000));
}

// Laeuft das Event noch oder liegt es in der Zukunft?
export function isEventOpen(e: Timed, now: Date = new Date()): boolean {
  return eventEnd(e) > now;
}

// datetime-local-Feld <-> ISO
export function toLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
