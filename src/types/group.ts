export type GroupMemberStatus = 'active' | 'waitlist';

// Eine Gruppe ist eine neutrale Gemeinschaft; Sport, Termin, Plaetze und
// Kosten gehoeren zu den Events der Gruppe (siehe types/event.ts).
export interface Group {
  id: string;
  name: string;
  description: string | null;
  is_public_event: boolean;
  created_by: string;
  created_at: string;
  city: string | null;
  // Wer darf Events anlegen: alle Mitglieder oder nur ausgewaehlte
  event_creation: 'all' | 'selected';
}

export interface GroupMember {
  id: string;
  group_id: string;
  user_id: string;
  status: GroupMemberStatus;
  joined_at: string;
  // Vom Ersteller freigeschaltet, Events zu organisieren
  can_organize: boolean;
  // Eigene Einstellung: alle Events sehen oder nur die zu den eigenen Interessen
  event_filter: 'all' | 'interests';
}

// Mitglied plus oeffentlich sichtbarer Name (aus public_profiles)
export interface GroupMemberWithName extends GroupMember {
  first_name: string | null;
  city: string | null;
  username: string | null;
}

// Rueckgabe von get_group_preview (Einladelink-Vorschau)
export interface GroupPreview {
  id: string;
  name: string;
  description: string | null;
  max_members: number;
  active_count: number;
  is_full: boolean;
  already_member: boolean;
}

// Rueckgabe von discover_groups_v2 (eigene Gruppen + oeffentliche im Umkreis)
export interface DiscoverGroup {
  id: string;
  name: string;
  description: string | null;
  is_public_event: boolean;
  created_by: string;
  city: string | null;
  member_count: number;
  my_status: GroupMemberStatus | null;
  distance_m: number | null;
  // Ungefaehre Position (Stadt, auf ~1 km gerundet) fuer die Karte
  lat: number | null;
  lng: number | null;
  // Naechstes Event - nur fuer Mitglieder gefuellt
  next_event_at: string | null;
  next_event_title: string | null;
  next_event_sport: string | null;
  events_upcoming: number;
}

export interface NewGroupInput {
  name: string;
  description: string;
  city: string | null;
  lat: number | null;
  lng: number | null;
}

export interface PollOptionView {
  id: string;
  label: string;
  votes: number;
  mine: boolean;
  voters: string[];
}

export interface PollView {
  id: string;
  question: string;
  created_by: string;
  created_at: string;
  options: PollOptionView[];
  voterCount: number;
}
