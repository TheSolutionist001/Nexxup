// Sportarten (muessen mit dem check-Constraint in 0017_launch_readiness.sql
// uebereinstimmen - ein Test prueft das). Emoji + Farbverlauf ersetzen vorerst echte Fotos.
export interface Sport {
  key: string;
  label: string;
  emoji: string;
  // Farbverlauf fuer Bildkarten (von hell nach dunkel)
  from: string;
  to: string;
}

export const sports: Sport[] = [
  { key: 'fussball', label: 'Fußball', emoji: '⚽', from: '#ff5a1f', to: '#5b1d06' },
  { key: 'laufen', label: 'Laufen', emoji: '🏃', from: '#5aa9ff', to: '#1e3a8a' },
  { key: 'wandern', label: 'Wandern', emoji: '🥾', from: '#3ccf7c', to: '#0f5132' },
  { key: 'radfahren', label: 'Radfahren', emoji: '🚴', from: '#ffb020', to: '#7c4a03' },
  { key: 'tennis', label: 'Tennis', emoji: '🎾', from: '#c6e94a', to: '#3f5a0c' },
  { key: 'volleyball', label: 'Volleyball', emoji: '🏐', from: '#38bdf8', to: '#0c4a6e' },
  { key: 'basketball', label: 'Basketball', emoji: '🏀', from: '#fb923c', to: '#7c2d12' },
  { key: 'fitness', label: 'Fitness', emoji: '💪', from: '#f472b6', to: '#831843' },
  { key: 'schwimmen', label: 'Schwimmen', emoji: '🏊', from: '#22d3ee', to: '#164e63' },
  { key: 'yoga', label: 'Yoga', emoji: '🧘', from: '#a78bfa', to: '#4c1d95' },
  { key: 'klettern', label: 'Klettern', emoji: '🧗', from: '#d6a36a', to: '#5b3a17' },
  { key: 'padel', label: 'Padel', emoji: '🎾', from: '#2dd4bf', to: '#115e59' },
  { key: 'badminton', label: 'Badminton', emoji: '🏸', from: '#facc15', to: '#713f12' },
  { key: 'tischtennis', label: 'Tischtennis', emoji: '🏓', from: '#f87171', to: '#7f1d1d' },
  { key: 'handball', label: 'Handball', emoji: '🤾', from: '#60a5fa', to: '#1e3a8a' },
  { key: 'kampfsport', label: 'Kampfsport', emoji: '🥋', from: '#e5e7eb', to: '#374151' },
  { key: 'tanzen', label: 'Tanzen', emoji: '💃', from: '#f0abfc', to: '#701a75' },
  { key: 'wintersport', label: 'Wintersport', emoji: '⛷️', from: '#bae6fd', to: '#075985' },
  { key: 'golf', label: 'Golf', emoji: '⛳', from: '#86efac', to: '#14532d' },
  { key: 'sonstiges', label: 'Sonstiges', emoji: '✨', from: '#a8a196', to: '#3a362e' },
];

const fallback = sports[sports.length - 1] as Sport;

export function getSport(key: string | null | undefined): Sport {
  return sports.find((s) => s.key === key) ?? fallback;
}

// CSS-Hintergrund fuer eine Bildkarte
export function sportGradient(key: string | null | undefined): string {
  const s = getSport(key);
  return `linear-gradient(135deg, ${s.from} 0%, ${s.to} 100%)`;
}

// Niveau einer Gruppe (muss zum DB-check groups_skill_level_check passen)
export const skillLevels: { label: string; value: string }[] = [
  { label: 'Alle Niveaus', value: 'alle' },
  { label: 'Anfänger', value: 'anfaenger' },
  { label: 'Mittel', value: 'mittel' },
  { label: 'Fortgeschritten', value: 'fortgeschritten' },
];

export function skillLabel(value: string | null | undefined): string {
  return skillLevels.find((s) => s.value === value)?.label ?? 'Alle Niveaus';
}
