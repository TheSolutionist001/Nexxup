// Events innerhalb einer Gruppe (Tabelle group_events, Migration 0020)
export type EventStatus = 'going' | 'waitlist' | 'offered';
export type EventAudience = 'all' | 'interested';

// Rueckgabe von my_events(): Event + Zahlen + mein Status
export interface GroupEvent {
  id: string;
  group_id: string;
  group_name: string | null;
  created_by: string | null;
  organizer_name: string | null;
  title: string;
  description: string | null;
  sport: string;
  skill_level: string;
  starts_at: string;
  duration_minutes: number;
  // null = unbegrenzt
  max_participants: number | null;
  // Kosten pro Person in Cent (null = kostenlos)
  fee_cents: number | null;
  audience: EventAudience;
  place_name: string | null;
  // 1 = jede Woche ...; null = einmalig
  repeat_weeks: number | null;
  going_count: number;
  waitlist_count: number;
  my_status: EventStatus | null;
  my_offer_expires_at: string | null;
  is_guest: boolean;
  matches_interest: boolean;
}

// Einzelnes Event mit Adresse (direkt aus der Tabelle; nur fuer Berechtigte lesbar)
export interface EventRow {
  id: string;
  group_id: string;
  created_by: string | null;
  title: string;
  description: string | null;
  sport: string;
  skill_level: string;
  starts_at: string;
  duration_minutes: number;
  max_participants: number | null;
  fee_cents: number | null;
  audience: EventAudience;
  place_name: string | null;
  place_address: string | null;
  place_lat: number | null;
  place_lng: number | null;
  repeat_weeks: number | null;
}

export interface EventParticipant {
  user_id: string;
  status: EventStatus;
  is_guest: boolean;
  queued_at: string;
  offer_expires_at: string | null;
  first_name: string | null;
  username: string | null;
}

// Eingabe beim Anlegen/Aendern
export interface EventInput {
  title: string;
  description: string | null;
  sport: string;
  skill_level: string;
  starts_at: string; // ISO
  duration_minutes: number;
  max_participants: number | null;
  fee_cents: number | null;
  audience: EventAudience;
  place_name: string | null;
  place_address: string | null;
  place_lat: number | null;
  place_lng: number | null;
  repeat_weeks: number | null;
}

// Rueckgabe von get_event_invite() (Vorschau fuer eingeladene Gaeste)
export interface EventInvitePreview {
  id: string;
  title: string;
  sport: string;
  skill_level: string;
  starts_at: string;
  duration_minutes: number;
  fee_cents: number | null;
  place_name: string | null;
  group_name: string;
  organizer_name: string | null;
  going_count: number;
  max_participants: number | null;
  my_status: EventStatus | null;
}
