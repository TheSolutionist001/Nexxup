// Uebersetzt Fehler aus der Datenbank in verstaendliche Meldungen.
// Die Kennungen (content_blocked, rate_limited ...) setzt die Datenbank
// selbst (Migration 0017).
export function friendlyError(error: unknown, fallback: string): string {
  const message = (error as { message?: string } | null)?.message ?? '';
  if (message.includes('content_blocked')) {
    return 'Dein Text enthält Ausdrücke, die hier nicht erlaubt sind. Bitte formuliere ihn um.';
  }
  if (message.includes('rate_limited')) {
    return 'Das waren viele Aktionen in kurzer Zeit. Bitte versuche es später erneut.';
  }
  if (message.includes('Konto gesperrt')) {
    return 'Dein Konto ist gesperrt.';
  }
  if (message.includes('blocked')) {
    return 'Ihr könnt euch nicht schreiben (Blockierung).';
  }
  return fallback;
}
