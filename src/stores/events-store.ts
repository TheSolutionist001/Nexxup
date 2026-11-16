import { defineStore } from 'pinia';
import { supabase } from '@/boot/supabase';
import type {
  EventInput,
  EventInvitePreview,
  EventParticipant,
  EventRow,
  EventStatus,
  GroupEvent,
} from '@/types/event';

// Spalten, die die App lesen darf (invite_token ist bewusst nicht lesbar)
const EVENT_COLUMNS =
  'id, group_id, created_by, title, description, sport, skill_level, starts_at, duration_minutes, max_participants, fee_cents, audience, place_name, place_address, place_lat, place_lng, repeat_weeks';

export const useEventsStore = defineStore('events', () => {
  // Fuer mich sichtbare Events (alle Gruppen oder eine Gruppe). Die Datenbank
  // filtert nach Zielgruppe des Events und meiner Einstellung in der Gruppe.
  async function fetchMyEvents(groupId: string | null = null): Promise<GroupEvent[]> {
    const { data, error } = await supabase.rpc('my_events', { p_group_id: groupId });
    if (error) throw error;
    return (data ?? []) as GroupEvent[];
  }

  async function fetchEvent(id: string): Promise<EventRow | null> {
    const { data, error } = await supabase.from('group_events').select(EVENT_COLUMNS).eq('id', id).maybeSingle();
    if (error) throw error;
    return data as EventRow | null;
  }

  async function fetchGroupName(eventId: string): Promise<string | null> {
    const { data, error } = await supabase.rpc('event_group_name', { p_event_id: eventId });
    if (error) throw error;
    return (data as string | null) ?? null;
  }

  async function fetchParticipants(eventId: string): Promise<EventParticipant[]> {
    const { data, error } = await supabase
      .from('event_participants')
      .select('user_id, status, is_guest, queued_at, offer_expires_at')
      .eq('event_id', eventId)
      .order('queued_at', { ascending: true });
    if (error) throw error;
    const rows = (data ?? []) as Omit<EventParticipant, 'first_name' | 'username'>[];
    if (rows.length === 0) return [];
    const { data: profiles, error: pErr } = await supabase
      .from('public_profiles')
      .select('id, first_name, username')
      .in('id', rows.map((r) => r.user_id));
    if (pErr) throw pErr;
    const byId = new Map((profiles ?? []).map((p) => [p.id as string, p]));
    return rows.map((r) => ({
      ...r,
      first_name: (byId.get(r.user_id)?.first_name as string | null | undefined) ?? null,
      username: (byId.get(r.user_id)?.username as string | null | undefined) ?? null,
    }));
  }

  async function createEvent(groupId: string, userId: string, input: EventInput): Promise<string> {
    const { data, error } = await supabase
      .from('group_events')
      .insert({ group_id: groupId, created_by: userId, ...input })
      .select('id')
      .single();
    if (error) throw error;
    return (data as { id: string }).id;
  }

  async function updateEvent(id: string, input: EventInput): Promise<void> {
    const { error } = await supabase.from('group_events').update(input).eq('id', id);
    if (error) throw error;
  }

  async function deleteEvent(id: string): Promise<void> {
    const { error } = await supabase.from('group_events').delete().eq('id', id);
    if (error) throw error;
  }

  // "Bin dabei" (auch: angebotenen Platz annehmen). Liefert den neuen Status.
  async function joinEvent(id: string): Promise<EventStatus> {
    const { data, error } = await supabase.rpc('join_event', { p_event_id: id });
    if (error) throw error;
    return data as EventStatus;
  }

  async function joinAsGuest(id: string, token: string): Promise<EventStatus> {
    const { data, error } = await supabase.rpc('join_event_as_guest', { p_event_id: id, p_token: token });
    if (error) throw error;
    return data as EventStatus;
  }

  // Absagen / Warteliste verlassen / Angebot ablehnen
  async function leaveEvent(id: string): Promise<void> {
    const { error } = await supabase.rpc('leave_event', { p_event_id: id });
    if (error) throw error;
  }

  async function removeParticipant(id: string, userId: string): Promise<void> {
    const { error } = await supabase.rpc('remove_event_participant', { p_event_id: id, p_user_id: userId });
    if (error) throw error;
  }

  // --- Bezahlt-Merkliste (keine Zahlungsabwicklung) ---
  async function fetchPaidUserIds(id: string): Promise<string[]> {
    const { data, error } = await supabase.rpc('event_paid_user_ids', { p_event_id: id });
    if (error) throw error;
    return ((data ?? []) as string[]).map((v) => String(v));
  }

  async function setPaid(id: string, userId: string, paid: boolean): Promise<void> {
    const { error } = await supabase.rpc('set_event_paid', { p_event_id: id, p_user_id: userId, p_paid: paid });
    if (error) throw error;
  }

  // --- Gaeste-Einladung ---
  async function hasInvite(id: string): Promise<boolean> {
    const { data, error } = await supabase.rpc('event_has_invite', { p_event_id: id });
    if (error) throw error;
    return Boolean(data);
  }

  // Schaltet den Link ein (liefert das Kennwort) oder aus (null). Nur Organisator.
  async function setInvite(id: string, enabled: boolean): Promise<string | null> {
    const { data, error } = await supabase.rpc('set_event_invite', { p_event_id: id, p_enabled: enabled });
    if (error) throw error;
    return (data as string | null) ?? null;
  }

  async function fetchInvitePreview(id: string, token: string): Promise<EventInvitePreview | null> {
    const { data, error } = await supabase.rpc('get_event_invite', { p_event_id: id, p_token: token }).maybeSingle();
    if (error) throw error;
    return data as EventInvitePreview | null;
  }

  return {
    fetchMyEvents,
    fetchEvent,
    fetchGroupName,
    fetchParticipants,
    createEvent,
    updateEvent,
    deleteEvent,
    joinEvent,
    joinAsGuest,
    leaveEvent,
    removeParticipant,
    fetchPaidUserIds,
    setPaid,
    hasInvite,
    setInvite,
    fetchInvitePreview,
  };
});
