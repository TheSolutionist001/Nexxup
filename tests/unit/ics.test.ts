import { describe, expect, it } from 'vitest';
import { buildIcs, escapeIcs, icsDate } from '@/utils/ics';

describe('Kalender-Datei (.ics)', () => {
  const start = new Date('2026-11-25T20:00:00Z');
  const now = new Date('2026-11-15T10:00:00Z');

  it('formatiert Zeitstempel in UTC', () => {
    expect(icsDate(start)).toBe('20261125T200000Z');
  });

  it('maskiert Sonderzeichen', () => {
    expect(escapeIcs('Halle A, Tor 2; hinten\nlinks')).toBe('Halle A\\, Tor 2\\; hinten\\nlinks');
  });

  it('baut einen einmaligen Termin mit 90 Minuten Dauer', () => {
    const ics = buildIcs({ uid: 'g1', title: 'Fußball: Campioni', start, location: 'Sporthalle, Tamm' }, now);
    expect(ics).toContain('BEGIN:VEVENT\r\n');
    expect(ics).toContain('UID:g1@nexxup');
    expect(ics).toContain('DTSTART:20261125T200000Z');
    expect(ics).toContain('DTEND:20261125T213000Z');
    expect(ics).toContain('SUMMARY:Fußball: Campioni');
    expect(ics).toContain('LOCATION:Sporthalle\\, Tamm');
    expect(ics).not.toContain('RRULE');
    expect(ics.endsWith('END:VCALENDAR\r\n')).toBe(true);
  });

  it('setzt die Wiederholung bei wiederkehrenden Terminen', () => {
    const ics = buildIcs({ uid: 'g1', title: 'x', start, repeatWeeks: 2 }, now);
    expect(ics).toContain('RRULE:FREQ=WEEKLY;INTERVAL=2');
  });
});
