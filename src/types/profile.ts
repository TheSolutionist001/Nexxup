export type Gender = 'maennlich' | 'weiblich' | 'divers' | 'keine_angabe';

export interface Profile {
  id: string;
  first_name: string;
  // Eindeutiger Nutzername (ohne @), z. B. "sandro_4821"
  username: string;
  gender: Gender | null;
  city: string | null;
  // Oeffentlich sichtbar (wie Vorname + Stadt)
  bio: string | null;
  sports: string[];
  created_at: string;
  is_admin: boolean;
  is_banned: boolean;
}

export const genderOptions: { label: string; value: Gender }[] = [
  { label: 'Männlich', value: 'maennlich' },
  { label: 'Weiblich', value: 'weiblich' },
  { label: 'Divers', value: 'divers' },
  { label: 'Keine Angabe', value: 'keine_angabe' },
];

// Oeffentliche Sicht auf ein fremdes Profil (View public_profiles)
export interface PublicProfile {
  id: string;
  first_name: string | null;
  city: string | null;
  bio: string | null;
  sports: string[] | null;
  username: string | null;
}
