import { ref } from 'vue';
import { defineStore } from 'pinia';
import { supabase } from '@/boot/supabase';
import type {
  DiscoverGroup,
  Group,
  GroupMemberStatus,
  GroupMemberWithName,
  GroupPreview,
  NewGroupInput,
  PollView,
} from '@/types/group';
import { buildPollViews, type PollOptionRow, type PollRow, type PollVoteRow } from '@/utils/polls';
import { fetchFirstNames } from '@/stores/chat-store';

// Gruppen sind neutrale Gemeinschaften ohne Teilnehmergrenze. Die Datenbank
// kennt aus frueheren Versionen noch "max_members" - der Wert wird nicht mehr
// angezeigt und beim Anlegen einfach sehr gross gesetzt.
const NO_MEMBER_LIMIT = 100000;

export const useGroupsStore = defineStore('groups', () => {
  const myGroups = ref<DiscoverGroup[]>([]);

  async function createGroup(input: NewGroupInput): Promise<string> {
    const { data, error } = await supabase.rpc('create_group', {
      p_name: input.name,
      p_description: input.description || null,
      p_max_members: NO_MEMBER_LIMIT,
      p_sport: 'sonstiges',
      p_next_meetup_at: null,
      p_city: input.city,
      p_lat: input.lat,
      p_lng: input.lng,
    });
    if (error) throw error;
    return data as string;
  }

  // radiusKm = null: nur eigene Gruppen.
  // Sonst zusaetzlich oeffentliche Gruppen im Umkreis (serverseitig per RLS gefiltert).
  async function discoverGroups(radiusKm: number | null): Promise<DiscoverGroup[]> {
    const { data, error } = await supabase.rpc('discover_groups_v2', { p_radius_km: radiusKm });
    if (error) throw error;
    return (data ?? []) as DiscoverGroup[];
  }

  async function fetchMyGroups() {
    myGroups.value = await discoverGroups(null);
  }

  async function fetchActiveCount(groupId: string): Promise<number> {
    const { data, error } = await supabase.rpc('group_active_count', { p_group_id: groupId });
    if (error) throw error;
    return (data as number) ?? 0;
  }

  // --- Umfragen ---
  async function fetchPolls(groupId: string, myId: string | null): Promise<PollView[]> {
    const { data: polls, error } = await supabase
      .from('group_polls')
      .select('id, question, created_by, created_at')
      .eq('group_id', groupId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    const pollRows = (polls ?? []) as PollRow[];
    if (pollRows.length === 0) return [];
    const ids = pollRows.map((p) => p.id);
    const [{ data: options, error: oErr }, { data: votes, error: vErr }] = await Promise.all([
      supabase.from('group_poll_options').select('id, poll_id, label, position').in('poll_id', ids),
      supabase.from('group_poll_votes').select('option_id, poll_id, user_id').in('poll_id', ids),
    ]);
    if (oErr) throw oErr;
    if (vErr) throw vErr;
    const voteRows = (votes ?? []) as PollVoteRow[];
    const names = await fetchFirstNames(voteRows.map((v) => v.user_id));
    return buildPollViews(pollRows, (options ?? []) as PollOptionRow[], voteRows, myId, names);
  }

  async function createPoll(groupId: string, question: string, options: string[]): Promise<void> {
    const { error } = await supabase.rpc('create_poll', {
      p_group_id: groupId,
      p_question: question.trim(),
      p_options: options.map((o) => o.trim()).filter(Boolean),
    });
    if (error) throw error;
  }

  async function setVote(pollId: string, optionId: string, on: boolean): Promise<void> {
    const { error } = on
      ? await supabase.from('group_poll_votes').insert({ poll_id: pollId, option_id: optionId })
      : // RLS erlaubt nur das Loeschen eigener Stimmen
        await supabase.from('group_poll_votes').delete().eq('option_id', optionId);
    if (error && error.code !== '23505') throw error;
  }

  async function deletePoll(pollId: string): Promise<void> {
    const { error } = await supabase.from('group_polls').delete().eq('id', pollId);
    if (error) throw error;
  }

  // Treffpunkt: nur fuer Mitglieder/Ersteller lesbar (RLS) - sonst null.

  async function fetchGroup(id: string): Promise<Group | null> {
    const { data, error } = await supabase
      .from('groups')
      .select('id, name, description, is_public_event, created_by, created_at, city, event_creation')
      .eq('id', id)
      .maybeSingle();
    if (error) throw error;
    return data as Group | null;
  }

  async function fetchMembers(groupId: string): Promise<GroupMemberWithName[]> {
    const { data: members, error } = await supabase
      .from('group_members')
      .select('*')
      .eq('group_id', groupId)
      .order('joined_at', { ascending: true });
    if (error) throw error;
    const rows = (members ?? []) as GroupMemberWithName[];

    if (rows.length === 0) return rows;

    // Namen separat laden (public_profiles ist eine View, kein einbettbarer FK).
    const ids = rows.map((m) => m.user_id);
    const { data: profiles } = await supabase
      .from('public_profiles')
      .select('id, first_name, city, username')
      .in('id', ids);

    const byId = new Map((profiles ?? []).map((p) => [p.id, p]));
    return rows.map((m) => ({
      ...m,
      first_name: byId.get(m.user_id)?.first_name ?? null,
      city: byId.get(m.user_id)?.city ?? null,
      username: (byId.get(m.user_id)?.username as string | null | undefined) ?? null,
    }));
  }

  async function joinGroup(groupId: string): Promise<GroupMemberStatus> {
    const { data, error } = await supabase.rpc('join_group', { p_group_id: groupId });
    if (error) throw error;
    return data as GroupMemberStatus;
  }

  async function leaveGroup(groupId: string): Promise<void> {
    const { error } = await supabase.rpc('leave_group', { p_group_id: groupId });
    if (error) throw error;
  }

  async function deleteGroup(groupId: string): Promise<void> {
    const { error } = await supabase.from('groups').delete().eq('id', groupId);
    if (error) throw error;
  }

  async function getGroupPreview(groupId: string): Promise<GroupPreview | null> {
    const { data, error } = await supabase
      .rpc('get_group_preview', { p_group_id: groupId })
      .maybeSingle();
    if (error) throw error;
    return data as GroupPreview | null;
  }

  // Stammdaten und Einstellungen aendern (nur Ersteller - RLS).
  async function updateGroup(
    groupId: string,
    updates: Partial<Pick<Group, 'name' | 'description' | 'is_public_event' | 'event_creation'>>,
  ): Promise<void> {
    const { error } = await supabase.from('groups').update(updates).eq('id', groupId);
    if (error) throw error;
  }

  // Mitglied entfernen (nur Ersteller - RLS). Zusagen in kuenftigen Events entfallen automatisch.
  async function removeMember(groupId: string, userId: string): Promise<void> {
    const { error } = await supabase.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);
    if (error) throw error;
  }

  // Eigene Einstellung: alle Events der Gruppe sehen oder nur die zu meinen Interessen.
  async function setMyEventFilter(groupId: string, filter: 'all' | 'interests'): Promise<void> {
    const { error } = await supabase.rpc('set_my_event_filter', { p_group_id: groupId, p_filter: filter });
    if (error) throw error;
  }

  // Ersteller: einem Mitglied erlauben/verbieten, Events zu organisieren.
  async function setMemberOrganizer(groupId: string, userId: string, can: boolean): Promise<void> {
    const { error } = await supabase.rpc('set_member_organizer', {
      p_group_id: groupId,
      p_user_id: userId,
      p_can: can,
    });
    if (error) throw error;
  }

  return {
    myGroups,
    createGroup,
    discoverGroups,
    fetchMyGroups,
    fetchActiveCount,
    fetchPolls,
    createPoll,
    setVote,
    deletePoll,
    fetchGroup,
    fetchMembers,
    joinGroup,
    leaveGroup,
    deleteGroup,
    getGroupPreview,
    updateGroup,
    removeMember,
    setMyEventFilter,
    setMemberOrganizer,
  };
});
