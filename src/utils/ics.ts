// Kalender-Datei (.ics) fuer einen Gruppentermin. Reine Text-Erzeugung,
// damit sie testbar ist; der Download passiert in downloadIcs().

export interface IcsEvent {
  uid: string;
  title: string;
  start: Date;
  durationMinutes?: number;
  location?: string | null;
  description?: string | null;
  // 1 = jede Woche, 2 = alle 2 Wochen ...; leer = einmalig
  repeatWeeks?: number | null;
}

// Sonderzeichen laut iCalendar-Standard maskieren
export function escapeIcs(text: string): string {
  return text.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

// UTC-Zeitstempel im Format 20261125T200000Z
export function icsDate(date: Date): string {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

export function buildIcs(event: IcsEvent, now: Date = new Date()): string {
  const end = new Date(event.start.getTime() + (event.durationMinutes ?? 90) * 60_000);
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Nexxup//DE',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${event.uid}@nexxup`,
    `DTSTAMP:${icsDate(now)}`,
    `DTSTART:${icsDate(event.start)}`,
    `DTEND:${icsDate(end)}`,
    `SUMMARY:${escapeIcs(event.title)}`,
  ];
  if (event.location) lines.push(`LOCATION:${escapeIcs(event.location)}`);
  if (event.description) lines.push(`DESCRIPTION:${escapeIcs(event.description)}`);
  if (event.repeatWeeks) lines.push(`RRULE:FREQ=WEEKLY;INTERVAL=${event.repeatWeeks}`);
  lines.push('END:VEVENT', 'END:VCALENDAR');
  return lines.join('\r\n') + '\r\n';
}

export function downloadIcs(event: IcsEvent, filename = 'termin.ics'): void {
  const blob = new Blob([buildIcs(event)], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
