import { describe, expect, it } from 'vitest';
import { findConflicts, occupancyLabel, offerMinutesLeft, overlaps, spotsLeft } from '@/utils/events';

const ev = (id: string, start: string, minutes = 90, my_status: string | null = null) => ({
  id,
  starts_at: start,
  duration_minutes: minutes,
  my_status,
});

describe('Terminüberschneidung', () => {
  it('erkennt sich überschneidende Zeiten', () => {
    expect(overlaps(ev('a', '2026-11-20T18:00:00Z'), ev('b', '2026-11-20T19:00:00Z'))).toBe(true);
    expect(overlaps(ev('a', '2026-11-20T18:00:00Z'), ev('b', '2026-11-20T17:00:00Z', 61))).toBe(true);
  });
  it('direkt anschließende Termine überschneiden sich nicht', () => {
    expect(overlaps(ev('a', '2026-11-20T18:00:00Z', 60), ev('b', '2026-11-20T19:00:00Z'))).toBe(false);
    expect(overlaps(ev('a', '2026-11-20T18:00:00Z'), ev('b', '2026-11-21T18:00:00Z'))).toBe(false);
  });
  it('warnt nur bei Events, bei denen ich zugesagt habe oder ein Angebot habe', () => {
    const target = ev('t', '2026-11-20T18:00:00Z');
    const mine = [
      ev('going', '2026-11-20T18:30:00Z', 90, 'going'),
      ev('offered', '2026-11-20T17:30:00Z', 90, 'offered'),
      ev('waitlist', '2026-11-20T18:30:00Z', 90, 'waitlist'),
      ev('none', '2026-11-20T18:30:00Z', 90, null),
      ev('later', '2026-11-20T21:00:00Z', 90, 'going'),
      ev('t', '2026-11-20T18:00:00Z', 90, 'going'), // das Event selbst
    ];
    expect(findConflicts(target, mine).map((e) => e.id)).toEqual(['going', 'offered']);
  });
});

describe('Belegung', () => {
  it('freie Plätze', () => {
    expect(spotsLeft(null, 5)).toBeNull();
    expect(spotsLeft(10, 7)).toBe(3);
    expect(spotsLeft(10, 12)).toBe(0);
  });
  it('Text zur Belegung', () => {
    expect(occupancyLabel(null, 3, 0)).toBe('3 dabei');
    expect(occupancyLabel(10, 3, 0)).toBe('3 von 10 dabei');
    expect(occupancyLabel(10, 10, 0)).toBe('Voll');
    expect(occupancyLabel(10, 10, 2)).toBe('Voll · 2 warten');
  });
  it('Restzeit eines Angebots', () => {
    const now = new Date('2026-11-20T18:00:00Z');
    expect(offerMinutesLeft('2026-11-20T18:42:10Z', now)).toBe(43);
    expect(offerMinutesLeft('2026-11-20T17:00:00Z', now)).toBe(0);
    expect(offerMinutesLeft(null, now)).toBe(0);
  });
});
