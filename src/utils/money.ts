// Geldbetraege: gespeichert wird in Cent (ganze Zahl), angezeigt in Euro.

export function formatEuro(cents: number | null | undefined): string | null {
  if (cents === null || cents === undefined) return null;
  return (cents / 100).toLocaleString('de-DE', { style: 'currency', currency: 'EUR' });
}

// Liest Eingaben wie "5", "5,50", "5.5" oder "12,00 €". Leer = kein Betrag (null).
// Ungueltige oder zu grosse Werte ergeben undefined.
export function parseEuro(input: string | number | null | undefined): number | null | undefined {
  if (input === null || input === undefined) return null;
  const text = String(input).replace(/€/g, '').replace(/\s/g, '').replace(',', '.');
  if (text === '') return null;
  if (!/^\d+(\.\d{1,2})?$/.test(text)) return undefined;
  const cents = Math.round(parseFloat(text) * 100);
  if (cents === 0) return null;
  return cents > 1_000_000 ? undefined : cents;
}
