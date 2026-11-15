// Angaben zum Betreiber. BITTE VOR DEM START AUSFUELLEN (Pflichtangaben nach
// § 5 DDG fuer das Impressum und Kontakt fuer Datenschutz/Meldungen).
// Solange hier nichts steht, zeigen die Seiten einen deutlichen Hinweis.
export const operator = {
  name: '', // z. B. "Max Mustermann" oder Firmenname
  street: '', // Strasse + Hausnummer
  city: '', // PLZ + Ort
  country: 'Deutschland',
  email: '', // Kontakt-E-Mail (auch fuer Meldungen und Datenschutz-Anfragen)
  phone: '', // optional
};

export const operatorComplete = Boolean(operator.name && operator.street && operator.city && operator.email);

// Mindestalter fuer die Nutzung
export const MIN_AGE = 16;

// Stand der Texte (bei Aenderungen anpassen)
export const legalVersion = '15.11.2026';

export type LegalDoc = 'regeln' | 'datenschutz' | 'impressum';

export const legalTitles: Record<LegalDoc, string> = {
  regeln: 'Community-Regeln & Nutzungsbedingungen',
  datenschutz: 'Datenschutzerklärung',
  impressum: 'Impressum',
};
