// Teilen ueber das Teilen-Menue des Geraets (Handy) - sonst Link kopieren.
export type ShareResult = 'shared' | 'copied' | 'cancelled' | 'failed';

export async function shareOrCopy(data: { title: string; text: string; url: string }): Promise<ShareResult> {
  if (typeof navigator.share === 'function') {
    try {
      await navigator.share(data);
      return 'shared';
    } catch (e) {
      // Nutzer hat das Menue geschlossen -> nichts weiter tun
      if ((e as { name?: string }).name === 'AbortError') return 'cancelled';
    }
  }
  try {
    await navigator.clipboard.writeText(data.url);
    return 'copied';
  } catch {
    return 'failed';
  }
}

// Adresse der App selbst (ohne "#/seite"), z. B. zum Einladen von Freunden.
export function appUrl(): string {
  return `${window.location.origin}${window.location.pathname}`;
}
