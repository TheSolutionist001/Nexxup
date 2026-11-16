// Regeln fuer Nutzernamen - muessen zur Datenbank-Regel passen
// (profiles_username_format in Migration 0019).
export const USERNAME_PATTERN = /^[a-z0-9][a-z0-9_.]{2,19}$/;

export function normalizeUsername(input: string): string {
  return input.trim().replace(/^@/, '').toLowerCase();
}

// Gibt eine Fehlermeldung zurueck oder null, wenn der Name gueltig ist.
export function usernameError(input: string): string | null {
  const name = normalizeUsername(input);
  if (name.length < 3) return 'Mindestens 3 Zeichen';
  if (name.length > 20) return 'Höchstens 20 Zeichen';
  if (!USERNAME_PATTERN.test(name)) return 'Nur Kleinbuchstaben, Zahlen, Punkt und Unterstrich';
  return null;
}
