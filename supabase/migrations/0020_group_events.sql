-- ==========================================================================
-- Events innerhalb von Gruppen
--
-- Laienfassung - was sich aendert:
--  * Eine GRUPPE ist jetzt eine neutrale Gemeinschaft (z. B. "Gruppo
--    Bietigheim"): keine feste Sportart, keine Teilnehmergrenze.
--  * In der Gruppe werden EVENTS organisiert (Fussballspiel, Lauf ...), jedes
--    mit eigener Sportart, Zeit, Ort, Platzzahl und Kosten. Mehrere Events
--    koennen parallel laufen.
--  * Mitglied sein heisst NICHT automatisch dabei sein: Zusage pro Event
--    ("Bin dabei"). Ist das Event voll, kommt man auf die Warteliste.
--  * Sagt jemand ab, bekommt die naechste Person der Warteliste eine
--    Push-Nachricht und hat 1 STUNDE Zeit zuzusagen. Danach verfaellt das
--    Angebot und die uebernaechste Person ist dran. Solange ein Angebot
--    laeuft, ist der Platz reserviert.
--  * Sichtbarkeit: Der Organisator waehlt "alle Mitglieder" oder "nur
--    Interessierte" (Sportart steht im Profil). Jedes Mitglied waehlt pro
--    Gruppe "alle Events" oder "nur meine Interessen".
--  * Wer Events anlegen darf, bestimmt der Gruppen-Ersteller: alle Mitglieder
--    oder nur ausgewaehlte.
--  * Gaeste: Der Organisator kann einen Einladelink erzeugen. Wer darueber
--    zusagt, ist NUR bei diesem Event dabei und wird kein Gruppenmitglied
--    (sieht weder Gruppen-Chat noch Mitgliederliste).
--  * Die bisherigen "Termine" der Gruppen werden in Events ueberfuehrt.
--
-- Sicherheit: Events und Teilnehmer sehen nur Gruppenmitglieder, der
-- Gruppen-Ersteller und Teilnehmer (Gaeste). Zusagen, Absagen und
-- Wartelisten laufen ausschliesslich ueber Funktionen, die die Event-Zeile
-- sperren - so wird die Platzzahl auch bei gleichzeitigen Zusagen nie
-- ueberschritten (gleiches Prinzip wie beim Gruppenbeitritt).
-- ==========================================================================

-- ===== 1. Gruppen: neutral und ohne Teilnehmergrenze =====
alter table public.groups alter column max_members set default 100000;
update public.groups set max_members = 100000 where max_members < 100000;

alter table public.groups
  add column if not exists event_creation text not null default 'all';
alter table public.groups drop constraint if exists groups_event_creation_check;
alter table public.groups add constraint groups_event_creation_check
  check (event_creation in ('all', 'selected'));
grant update (event_creation) on public.groups to authenticated;

-- Pro Mitglied: darf Events organisieren? / welche Events will ich sehen?
alter table public.group_members
  add column if not exists can_organize boolean not null default false,
  add column if not exists event_filter text not null default 'all';
alter table public.group_members drop constraint if exists group_members_event_filter_check;
alter table public.group_members add constraint group_members_event_filter_check
  check (event_filter in ('all', 'interests'));

-- Wer auf einer alten Gruppen-Warteliste stand, ist jetzt normales Mitglied.
update public.group_members set status = 'active' where status = 'waitlist';

-- ===== 2. Tabellen =====
create table if not exists public.group_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  title text not null constraint group_events_title_len check (char_length(btrim(title)) between 1 and 80),
  description text constraint group_events_description_len check (description is null or char_length(description) <= 1000),
  sport text not null default 'sonstiges' constraint group_events_sport_check check (sport in (
    'fussball', 'laufen', 'wandern', 'radfahren', 'tennis', 'volleyball',
    'basketball', 'fitness', 'schwimmen', 'yoga', 'klettern', 'padel',
    'badminton', 'tischtennis', 'handball', 'kampfsport', 'tanzen',
    'wintersport', 'golf', 'sonstiges'
  )),
  skill_level text not null default 'alle' constraint group_events_skill_check
    check (skill_level in ('alle', 'anfaenger', 'mittel', 'fortgeschritten')),
  starts_at timestamptz not null,
  duration_minutes integer not null default 90 constraint group_events_duration_check check (duration_minutes between 15 and 1440),
  -- null = unbegrenzt viele Plaetze
  max_participants integer constraint group_events_max_check check (max_participants is null or max_participants between 1 and 1000),
  -- Kosten pro Person in Cent (null = kostenlos); reine Merkliste, keine Zahlung
  fee_cents integer constraint group_events_fee_check check (fee_cents is null or fee_cents between 1 and 1000000),
  -- 'all' = alle Mitglieder, 'interested' = nur wer die Sportart im Profil hat
  audience text not null default 'all' constraint group_events_audience_check check (audience in ('all', 'interested')),
  place_name text constraint group_events_place_name_len check (place_name is null or char_length(place_name) <= 200),
  place_address text constraint group_events_place_address_len check (place_address is null or char_length(place_address) <= 300),
  place_lat double precision constraint group_events_lat_check check (place_lat is null or place_lat between -90 and 90),
  place_lng double precision constraint group_events_lng_check check (place_lng is null or place_lng between -180 and 180),
  -- 1 = jede Woche ...; null = einmalig. Nach dem Termin entsteht automatisch der naechste.
  repeat_weeks smallint constraint group_events_repeat_check check (repeat_weeks is null or repeat_weeks between 1 and 4),
  -- Gesetzt = Gaeste koennen ueber den Einladelink zusagen
  invite_token uuid,
  created_at timestamptz not null default now()
);

create index if not exists group_events_group_idx on public.group_events (group_id, starts_at);
create index if not exists group_events_created_by_idx on public.group_events (created_by);
create index if not exists group_events_starts_idx on public.group_events (starts_at);

create table if not exists public.event_participants (
  event_id uuid not null references public.group_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- going = dabei, waitlist = wartet, offered = Platz angeboten (1 Std. Zeit)
  status text not null constraint event_participants_status_check check (status in ('going', 'waitlist', 'offered')),
  is_guest boolean not null default false,
  -- Reihenfolge auf der Warteliste
  queued_at timestamptz not null default now(),
  offer_expires_at timestamptz,
  paid_at timestamptz,
  primary key (event_id, user_id)
);

create index if not exists event_participants_user_idx on public.event_participants (user_id);
create index if not exists event_participants_offer_idx on public.event_participants (offer_expires_at) where status = 'offered';

create table if not exists public.event_reminders_sent (
  event_id uuid not null references public.group_events(id) on delete cascade,
  kind text not null,
  sent_at timestamptz not null default now(),
  primary key (event_id, kind)
);

alter table public.group_events enable row level security;
alter table public.event_participants enable row level security;
alter table public.event_reminders_sent enable row level security;
revoke all on public.event_reminders_sent from anon, authenticated;

-- ===== 3. Hilfsfunktionen (security definer: liefern nur ja/nein) =====
-- Diese Funktionen verhindern auch, dass sich die Zugriffsregeln der beiden
-- Tabellen gegenseitig abfragen (das wuerde Postgres als Endlosschleife ablehnen).

create or replace function public.is_event_participant(p_event_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select exists (
    select 1 from public.event_participants
    where event_id = p_event_id and user_id = auth.uid()
  );
$BODY$;

-- Darf ich dieses Event sehen? (Mitglied der Gruppe, Gruppen-Ersteller oder Teilnehmer/Gast)
create or replace function public.can_see_event(p_event_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select exists (
    select 1 from public.group_events e
    where e.id = p_event_id
      and (
        public.is_group_member(e.group_id)
        or public.is_group_creator(e.group_id)
        or public.is_event_participant(e.id)
      )
  );
$BODY$;

-- Darf ich in dieser Gruppe Events anlegen?
create or replace function public.can_organize_events(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select public.is_group_creator(p_group_id)
    or exists (
      select 1
      from public.group_members gm
      join public.groups g on g.id = gm.group_id
      where gm.group_id = p_group_id
        and gm.user_id = auth.uid()
        and gm.status = 'active'
        and (g.event_creation = 'all' or gm.can_organize)
    );
$BODY$;

-- Darf ich dieses Event verwalten? (wer es angelegt hat oder der Gruppen-Ersteller)
create or replace function public.can_manage_event(p_event_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select exists (
    select 1 from public.group_events e
    where e.id = p_event_id
      and (e.created_by = auth.uid() or public.is_group_creator(e.group_id))
  );
$BODY$;

-- Gruppenname zu einem Event - auch fuer Gaeste, die die (private) Gruppe
-- selbst nicht sehen duerfen.
create or replace function public.event_group_name(p_event_id uuid)
returns text
language sql
security definer
stable
set search_path = public
as $BODY$
  select g.name
  from public.group_events e
  join public.groups g on g.id = e.group_id
  where e.id = p_event_id and public.can_see_event(p_event_id);
$BODY$;

-- Hat das Event einen aktiven Gaeste-Link? (ohne das Kennwort zu verraten)
create or replace function public.event_has_invite(p_event_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select exists (
    select 1 from public.group_events e
    where e.id = p_event_id and e.invite_token is not null and public.can_see_event(p_event_id)
  );
$BODY$;

revoke all on function public.event_group_name(uuid) from public, anon;
revoke all on function public.event_has_invite(uuid) from public, anon;
grant execute on function public.event_group_name(uuid) to authenticated;
grant execute on function public.event_has_invite(uuid) to authenticated;
revoke all on function public.is_event_participant(uuid) from public, anon;
revoke all on function public.can_see_event(uuid) from public, anon;
revoke all on function public.can_organize_events(uuid) from public, anon;
revoke all on function public.can_manage_event(uuid) from public, anon;
grant execute on function public.is_event_participant(uuid) to authenticated;
grant execute on function public.can_see_event(uuid) to authenticated;
grant execute on function public.can_organize_events(uuid) to authenticated;
grant execute on function public.can_manage_event(uuid) to authenticated;

-- ===== 4. Zugriffsregeln =====
drop policy if exists "group_events_select" on public.group_events;
create policy "group_events_select" on public.group_events
  for select to authenticated
  using (
    public.is_group_member(group_id)
    or public.is_group_creator(group_id)
    or public.is_event_participant(id)
  );

drop policy if exists "group_events_insert" on public.group_events;
create policy "group_events_insert" on public.group_events
  for insert to authenticated
  with check (created_by = (select auth.uid()) and public.can_organize_events(group_id));

drop policy if exists "group_events_update" on public.group_events;
create policy "group_events_update" on public.group_events
  for update to authenticated
  using (public.can_manage_event(id))
  with check (public.can_manage_event(id));

drop policy if exists "group_events_delete" on public.group_events;
create policy "group_events_delete" on public.group_events
  for delete to authenticated
  using (public.can_manage_event(id));

revoke all on public.group_events from anon;
revoke all on public.group_events from authenticated;
grant delete on public.group_events to authenticated;
-- Lesen: alle Spalten AUSSER invite_token (das Kennwort des Gaeste-Links
-- bekommt nur der Organisator ueber set_event_invite()).
grant select (id, group_id, created_by, title, description, sport, skill_level, starts_at, duration_minutes,
              max_participants, fee_cents, audience, place_name, place_address, place_lat, place_lng,
              repeat_weeks, created_at)
  on public.group_events to authenticated;
grant insert (group_id, created_by, title, description, sport, skill_level, starts_at, duration_minutes,
              max_participants, fee_cents, audience, place_name, place_address, place_lat, place_lng, repeat_weeks)
  on public.group_events to authenticated;
grant update (title, description, sport, skill_level, starts_at, duration_minutes,
              max_participants, fee_cents, audience, place_name, place_address, place_lat, place_lng, repeat_weeks)
  on public.group_events to authenticated;

-- Teilnehmer: lesen darf, wer das Event sehen darf. "Bezahlt" (paid_at) ist
-- bewusst NICHT lesbar - dafuer gibt es event_paid_user_ids().
drop policy if exists "event_participants_select" on public.event_participants;
create policy "event_participants_select" on public.event_participants
  for select to authenticated
  using (user_id = (select auth.uid()) or public.can_see_event(event_id));
-- Schreiben nur ueber die Funktionen unten.

revoke all on public.event_participants from anon;
revoke all on public.event_participants from authenticated;
grant select (event_id, user_id, status, is_guest, queued_at, offer_expires_at)
  on public.event_participants to authenticated;

-- Wortfilter, Sperre, Spam-Bremse
drop trigger if exists filter_group_event on public.group_events;
create trigger filter_group_event before insert or update of title, description on public.group_events
  for each row execute function public.reject_objectionable('title', 'description');
drop trigger if exists reject_banned_group_event on public.group_events;
create trigger reject_banned_group_event before insert on public.group_events
  for each row execute function public.reject_if_banned();
drop trigger if exists rate_limit_group_events on public.group_events;
create trigger rate_limit_group_events before insert on public.group_events
  for each row execute function public.rate_limit('created_by', '30', '1 day');
drop trigger if exists reject_banned_event_participant on public.event_participants;
create trigger reject_banned_event_participant before insert on public.event_participants
  for each row execute function public.reject_if_banned();

-- ===== 5. Warteliste: Platz anbieten =====
-- Bietet freie Plaetze den am laengsten Wartenden an (1 Stunde Zeit) und
-- schickt ihnen eine Push-Nachricht. Vorher muss die Event-Zeile gesperrt sein.
create or replace function public.offer_free_spots(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_event public.group_events;
  v_taken integer;
  v_next uuid;
begin
  select * into v_event from public.group_events where id = p_event_id for update;
  if not found or v_event.starts_at < now() then
    return;
  end if;

  loop
    select count(*) into v_taken
    from public.event_participants
    where event_id = p_event_id and status in ('going', 'offered');
    exit when v_event.max_participants is not null and v_taken >= v_event.max_participants;

    select user_id into v_next
    from public.event_participants
    where event_id = p_event_id and status = 'waitlist'
    order by queued_at asc
    limit 1;
    exit when v_next is null;

    update public.event_participants
    set status = 'offered', offer_expires_at = now() + interval '1 hour'
    where event_id = p_event_id and user_id = v_next;

    perform public.send_push_to_user(
      v_next,
      'Platz frei: ' || v_event.title,
      'Du bist dran! Sag innerhalb von 1 Stunde in der App zu, sonst geht der Platz an die naechste Person.'
    );
  end loop;
end;
$BODY$;

revoke all on function public.offer_free_spots(uuid) from public, anon, authenticated;

-- ===== 6. Zusagen / Absagen =====
-- Gemeinsamer Kern fuer Mitglieder und Gaeste. Sperrt die Event-Zeile.
create or replace function public.join_event_internal(p_event_id uuid, p_is_guest boolean)
returns text
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_event public.group_events;
  v_existing public.event_participants;
  v_taken integer;
  v_status text;
begin
  select * into v_event from public.group_events where id = p_event_id for update;
  if not found then
    raise exception 'Event nicht gefunden';
  end if;
  if v_event.starts_at + make_interval(mins => v_event.duration_minutes) < now() then
    raise exception 'event_over';
  end if;

  select * into v_existing
  from public.event_participants
  where event_id = p_event_id and user_id = auth.uid();

  if found then
    -- Angebotenen Platz annehmen
    if v_existing.status = 'offered' then
      update public.event_participants
      set status = 'going', offer_expires_at = null
      where event_id = p_event_id and user_id = auth.uid();
      return 'going';
    end if;
    return v_existing.status;
  end if;

  select count(*) into v_taken
  from public.event_participants
  where event_id = p_event_id and status in ('going', 'offered');

  if v_event.max_participants is null or v_taken < v_event.max_participants then
    v_status := 'going';
  else
    v_status := 'waitlist';
  end if;

  insert into public.event_participants (event_id, user_id, status, is_guest)
  values (p_event_id, auth.uid(), v_status, p_is_guest);

  return v_status;
end;
$BODY$;

revoke all on function public.join_event_internal(uuid, boolean) from public, anon, authenticated;

-- "Bin dabei" fuer Gruppenmitglieder (und fuer Gaeste, die schon eingetragen sind,
-- z. B. um einen angebotenen Platz anzunehmen).
create or replace function public.join_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_group uuid;
begin
  select group_id into v_group from public.group_events where id = p_event_id;
  if v_group is null then
    raise exception 'Event nicht gefunden';
  end if;
  if not (public.is_group_member(v_group) or public.is_event_participant(p_event_id)) then
    raise exception 'Nur Mitglieder der Gruppe koennen zusagen';
  end if;
  return public.join_event_internal(p_event_id, not public.is_group_member(v_group));
end;
$BODY$;

-- Zusage als Gast ueber den Einladelink (nur fuer dieses eine Event).
create or replace function public.join_event_as_guest(p_event_id uuid, p_token uuid)
returns text
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_group uuid;
begin
  select group_id into v_group
  from public.group_events
  where id = p_event_id and invite_token is not null and invite_token = p_token;
  if v_group is null then
    raise exception 'invite_invalid';
  end if;
  if exists (
    select 1 from public.groups g
    where g.id = v_group and public.is_blocked_between(g.created_by)
  ) then
    raise exception 'invite_invalid';
  end if;
  return public.join_event_internal(p_event_id, not public.is_group_member(v_group));
end;
$BODY$;

-- Absagen (auch: angebotenen Platz ablehnen, Warteliste verlassen).
create or replace function public.leave_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_status text;
begin
  perform 1 from public.group_events where id = p_event_id for update;

  delete from public.event_participants
  where event_id = p_event_id and user_id = auth.uid()
  returning status into v_status;

  if v_status in ('going', 'offered') then
    perform public.offer_free_spots(p_event_id);
  end if;
end;
$BODY$;

-- Organisator entfernt jemanden aus dem Event.
create or replace function public.remove_event_participant(p_event_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_status text;
begin
  if not public.can_manage_event(p_event_id) then
    raise exception 'Nur der Organisator kann Teilnehmer entfernen';
  end if;
  perform 1 from public.group_events where id = p_event_id for update;

  delete from public.event_participants
  where event_id = p_event_id and user_id = p_user_id
  returning status into v_status;

  if v_status in ('going', 'offered') then
    perform public.offer_free_spots(p_event_id);
  end if;
end;
$BODY$;

revoke all on function public.join_event(uuid) from public, anon;
revoke all on function public.join_event_as_guest(uuid, uuid) from public, anon;
revoke all on function public.leave_event(uuid) from public, anon;
revoke all on function public.remove_event_participant(uuid, uuid) from public, anon;
grant execute on function public.join_event(uuid) to authenticated;
grant execute on function public.join_event_as_guest(uuid, uuid) to authenticated;
grant execute on function public.leave_event(uuid) to authenticated;
grant execute on function public.remove_event_participant(uuid, uuid) to authenticated;

-- Mehr Plaetze -> Wartenden anbieten. Verlaesst jemand die GRUPPE, verliert
-- er auch seine Zusagen in deren kuenftigen Events (Gaeste sind keine Mitglieder
-- und bleiben unberuehrt).
create or replace function public.on_event_capacity_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  perform public.offer_free_spots(new.id);
  return new;
end;
$BODY$;

drop trigger if exists on_event_capacity_changed on public.group_events;
create trigger on_event_capacity_changed
  after update of max_participants on public.group_events
  for each row
  when (new.max_participants is distinct from old.max_participants)
  execute function public.on_event_capacity_changed();

create or replace function public.on_member_left_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_event uuid;
begin
  for v_event in
    delete from public.event_participants ep
    using public.group_events e
    where e.id = ep.event_id
      and e.group_id = old.group_id
      and ep.user_id = old.user_id
      and not ep.is_guest
      and e.starts_at > now()
      and ep.status in ('going', 'offered', 'waitlist')
    returning ep.event_id
  loop
    perform public.offer_free_spots(v_event);
  end loop;
  return old;
end;
$BODY$;

drop trigger if exists on_member_left_group on public.group_members;
create trigger on_member_left_group
  after delete on public.group_members
  for each row execute function public.on_member_left_group();

revoke all on function public.on_event_capacity_changed() from public, anon, authenticated;
revoke all on function public.on_member_left_group() from public, anon, authenticated;

-- ===== 7. Bezahlt-Merkliste pro Event =====
create or replace function public.set_event_paid(p_event_id uuid, p_user_id uuid, p_paid boolean)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.can_manage_event(p_event_id) then
    raise exception 'Nur der Organisator kann Zahlungen abhaken';
  end if;
  update public.event_participants
  set paid_at = case when p_paid then coalesce(paid_at, now()) else null end
  where event_id = p_event_id and user_id = p_user_id;
end;
$BODY$;

-- Wer ist als bezahlt vermerkt? Organisator: alle. Sonst: hoechstens man selbst.
create or replace function public.event_paid_user_ids(p_event_id uuid)
returns setof uuid
language sql
security definer
stable
set search_path = public
as $BODY$
  select ep.user_id
  from public.event_participants ep
  where ep.event_id = p_event_id
    and ep.paid_at is not null
    and (ep.user_id = auth.uid() or public.can_manage_event(p_event_id));
$BODY$;

revoke all on function public.set_event_paid(uuid, uuid, boolean) from public, anon;
revoke all on function public.event_paid_user_ids(uuid) from public, anon;
grant execute on function public.set_event_paid(uuid, uuid, boolean) to authenticated;
grant execute on function public.event_paid_user_ids(uuid) to authenticated;

-- ===== 8. Gaeste-Einladung =====
-- Schaltet den Einladelink ein (liefert das Kennwort des Links) oder aus (null).
create or replace function public.set_event_invite(p_event_id uuid, p_enabled boolean)
returns uuid
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_token uuid;
begin
  if not public.can_manage_event(p_event_id) then
    raise exception 'Nur der Organisator kann Gaeste einladen';
  end if;
  update public.group_events
  set invite_token = case when p_enabled then coalesce(invite_token, gen_random_uuid()) else null end
  where id = p_event_id
  returning invite_token into v_token;
  return v_token;
end;
$BODY$;

-- Vorschau fuer Eingeladene (nur mit gueltigem Link). Zeigt bewusst wenig:
-- keine Teilnehmernamen, keine Adresse.
create or replace function public.get_event_invite(p_event_id uuid, p_token uuid)
returns table (
  id uuid,
  title text,
  sport text,
  skill_level text,
  starts_at timestamptz,
  duration_minutes integer,
  fee_cents integer,
  place_name text,
  group_name text,
  organizer_name text,
  going_count integer,
  max_participants integer,
  my_status text
)
language sql
security definer
stable
set search_path = public
as $BODY$
  select
    e.id, e.title, e.sport, e.skill_level, e.starts_at, e.duration_minutes, e.fee_cents,
    e.place_name, g.name, p.first_name,
    (select count(*)::integer from public.event_participants ep where ep.event_id = e.id and ep.status in ('going', 'offered')),
    e.max_participants,
    (select ep.status from public.event_participants ep where ep.event_id = e.id and ep.user_id = auth.uid())
  from public.group_events e
  join public.groups g on g.id = e.group_id
  left join public.profiles p on p.id = e.created_by
  where e.id = p_event_id and e.invite_token is not null and e.invite_token = p_token;
$BODY$;

revoke all on function public.set_event_invite(uuid, boolean) from public, anon;
revoke all on function public.get_event_invite(uuid, uuid) from public, anon;
grant execute on function public.set_event_invite(uuid, boolean) to authenticated;
grant execute on function public.get_event_invite(uuid, uuid) to authenticated;

-- ===== 9. Einstellungen in der Gruppe =====
-- Mitglied: alle Events sehen oder nur die zu den eigenen Interessen.
create or replace function public.set_my_event_filter(p_group_id uuid, p_filter text)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if p_filter not in ('all', 'interests') then
    raise exception 'Ungueltige Einstellung';
  end if;
  update public.group_members
  set event_filter = p_filter
  where group_id = p_group_id and user_id = auth.uid();
end;
$BODY$;

-- Gruppen-Ersteller: einem Mitglied erlauben/verbieten, Events zu organisieren.
create or replace function public.set_member_organizer(p_group_id uuid, p_user_id uuid, p_can boolean)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_group_creator(p_group_id) then
    raise exception 'Nur der Gruppen-Ersteller kann das festlegen';
  end if;
  update public.group_members
  set can_organize = p_can
  where group_id = p_group_id and user_id = p_user_id;
end;
$BODY$;

revoke all on function public.set_my_event_filter(uuid, text) from public, anon;
revoke all on function public.set_member_organizer(uuid, uuid, boolean) from public, anon;
grant execute on function public.set_my_event_filter(uuid, text) to authenticated;
grant execute on function public.set_member_organizer(uuid, uuid, boolean) to authenticated;

-- ===== 10. Listen fuer die App (INVOKER: die Zugriffsregeln oben greifen) =====
-- Events, die fuer MICH sichtbar sind: ueber meine Gruppen (gefiltert nach
-- Zielgruppe des Events und meiner Einstellung) sowie alle, bei denen ich
-- eingetragen bin oder die ich organisiere. p_group_id = null: alle Gruppen.
-- Zeigt laufende und kuenftige Events sowie die der letzten 24 Stunden.
create or replace function public.my_events(p_group_id uuid default null)
returns table (
  id uuid,
  group_id uuid,
  group_name text,
  created_by uuid,
  organizer_name text,
  title text,
  description text,
  sport text,
  skill_level text,
  starts_at timestamptz,
  duration_minutes integer,
  max_participants integer,
  fee_cents integer,
  audience text,
  place_name text,
  repeat_weeks smallint,
  going_count integer,
  waitlist_count integer,
  my_status text,
  my_offer_expires_at timestamptz,
  is_guest boolean,
  matches_interest boolean
)
language sql
stable
set search_path = public
as $BODY$
  select
    e.id, e.group_id, coalesce(g.name, public.event_group_name(e.id)), e.created_by, pp.first_name,
    e.title, e.description, e.sport, e.skill_level,
    e.starts_at, e.duration_minutes, e.max_participants, e.fee_cents, e.audience, e.place_name, e.repeat_weeks,
    (select count(*)::integer from public.event_participants x where x.event_id = e.id and x.status in ('going', 'offered')),
    (select count(*)::integer from public.event_participants x where x.event_id = e.id and x.status = 'waitlist'),
    me.status,
    me.offer_expires_at,
    coalesce(me.is_guest, false),
    e.sport = any (prof.sports)
  from public.group_events e
  left join public.groups g on g.id = e.group_id
  cross join (select coalesce((select sports from public.profiles where id = auth.uid()), '{}') as sports) prof
  left join public.public_profiles pp on pp.id = e.created_by
  left join public.group_members gm on gm.group_id = e.group_id and gm.user_id = auth.uid()
  left join public.event_participants me on me.event_id = e.id and me.user_id = auth.uid()
  where (p_group_id is null or e.group_id = p_group_id)
    and e.starts_at > now() - interval '24 hours'
    and (
      me.user_id is not null
      or e.created_by = auth.uid()
      or (
        (e.audience = 'all' or e.sport = any (prof.sports))
        and (coalesce(gm.event_filter, 'all') = 'all' or e.sport = any (prof.sports))
      )
    )
  order by e.starts_at asc;
$BODY$;

revoke all on function public.my_events(uuid) from public, anon;
grant execute on function public.my_events(uuid) to authenticated;

-- Gruppen-Uebersicht fuer "Entdecken" und "Meine Gruppen": eigene Gruppen +
-- oeffentliche im Umkreis (p_radius_km = null: nur eigene). Die Event-Angaben
-- sind fuer Nicht-Mitglieder automatisch leer (Zugriffsregeln der Events).
create or replace function public.discover_groups_v2(p_radius_km integer)
returns table (
  id uuid,
  name text,
  description text,
  is_public_event boolean,
  created_by uuid,
  city text,
  member_count integer,
  my_status text,
  distance_m double precision,
  lat double precision,
  lng double precision,
  next_event_at timestamptz,
  next_event_title text,
  next_event_sport text,
  events_upcoming integer
)
language sql
stable
set search_path = public, extensions
as $BODY$
  select
    g.id, g.name, g.description, g.is_public_event, g.created_by, g.city,
    public.group_active_count(g.id),
    gm.status,
    case
      when g.location is null or me.location is null then null
      else extensions.ST_Distance(g.location, me.location)
    end,
    round(extensions.ST_Y(g.location::extensions.geometry)::numeric, 2)::double precision,
    round(extensions.ST_X(g.location::extensions.geometry)::numeric, 2)::double precision,
    nxt.starts_at, nxt.title, nxt.sport,
    (select count(*)::integer from public.group_events e where e.group_id = g.id and e.starts_at > now())
  from public.groups g
  left join (select location from public.profiles where id = auth.uid()) me on true
  left join public.group_members gm on gm.group_id = g.id and gm.user_id = auth.uid()
  left join lateral (
    select e.starts_at, e.title, e.sport
    from public.group_events e
    where e.group_id = g.id and e.starts_at > now()
    order by e.starts_at asc
    limit 1
  ) nxt on true
  where gm.id is not null
     or (
       p_radius_km is not null
       and g.is_public_event
       and g.location is not null
       and me.location is not null
       and extensions.ST_DWithin(g.location, me.location, p_radius_km * 1000)
     )
  order by nxt.starts_at nulls last, g.created_at desc;
$BODY$;

revoke all on function public.discover_groups_v2(integer) from public, anon;
grant execute on function public.discover_groups_v2(integer) to authenticated;

-- ===== 11. Push bei neuem Event (nur an die, fuer die es sichtbar ist) =====
create or replace function public.notify_new_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  m record;
  v_group text;
begin
  select name into v_group from public.groups where id = new.group_id;
  for m in
    select gm.user_id
    from public.group_members gm
    join public.profiles p on p.id = gm.user_id
    where gm.group_id = new.group_id
      and gm.status = 'active'
      and gm.user_id is distinct from new.created_by
      and (new.audience = 'all' or new.sport = any (p.sports))
      and (gm.event_filter = 'all' or new.sport = any (p.sports))
  loop
    perform public.send_push_to_user(
      m.user_id,
      'Neues Event in ' || coalesce(v_group, 'deiner Gruppe'),
      new.title || ' am ' || to_char(new.starts_at at time zone 'Europe/Berlin', 'DD.MM. "um" HH24:MI "Uhr"') || '. Bist du dabei?'
    );
  end loop;
  return new;
end;
$BODY$;

drop trigger if exists notify_new_event on public.group_events;
create trigger notify_new_event
  after insert on public.group_events
  for each row execute function public.notify_new_event();

revoke all on function public.notify_new_event() from public, anon, authenticated;

-- ===== 12. Automatischer Lauf (alle 5 Minuten) =====
create or replace function public.process_events()
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  r record;
  m record;
  v_when text;
  v_new uuid;
begin
  -- a) Abgelaufene Platz-Angebote: Person faellt heraus, die naechste ist dran.
  for r in
    delete from public.event_participants ep
    where ep.status = 'offered' and ep.offer_expires_at < now()
    returning ep.event_id, ep.user_id
  loop
    perform public.send_push_to_user(
      r.user_id,
      'Angebot abgelaufen',
      'Der freie Platz wurde weitergegeben. Du kannst dich jederzeit wieder eintragen.'
    );
    perform public.offer_free_spots(r.event_id);
  end loop;

  -- b) Erinnerungen ca. 24 Std. und ca. 2 Std. vorher (nur an Zusagende)
  for r in
    select e.id, e.title, e.starts_at, k.kind
    from public.group_events e
    cross join (values ('24h', interval '24 hours'), ('2h', interval '2 hours')) as k(kind, lead_time)
    where e.starts_at > now()
      and e.starts_at - k.lead_time <= now()
      and (k.kind = '2h' or e.starts_at > now() + interval '3 hours')
      and not exists (
        select 1 from public.event_reminders_sent s where s.event_id = e.id and s.kind = k.kind
      )
  loop
    insert into public.event_reminders_sent (event_id, kind) values (r.id, r.kind) on conflict do nothing;
    v_when := to_char(r.starts_at at time zone 'Europe/Berlin', 'DD.MM. "um" HH24:MI "Uhr"');
    for m in
      select user_id from public.event_participants where event_id = r.id and status = 'going'
    loop
      perform public.send_push_to_user(
        m.user_id,
        case when r.kind = '24h' then 'Bald geht''s los: ' else 'Gleich geht''s los: ' end || r.title,
        'Termin am ' || v_when || '. Falls du doch nicht kannst, sag bitte in der App ab.'
      );
    end loop;
  end loop;

  -- c) Wiederkehrende Events: 3 Std. nach Beginn entsteht der naechste Termin
  --    (ohne Teilnehmer - jede/r sagt neu zu). Der alte wiederholt sich nicht mehr.
  for r in
    select * from public.group_events
    where repeat_weeks is not null and starts_at < now() - interval '3 hours'
    for update
  loop
    insert into public.group_events (
      group_id, created_by, title, description, sport, skill_level, starts_at, duration_minutes,
      max_participants, fee_cents, audience, place_name, place_address, place_lat, place_lng, repeat_weeks
    )
    values (
      r.group_id, r.created_by, r.title, r.description, r.sport, r.skill_level,
      r.starts_at + make_interval(weeks => r.repeat_weeks * (
        floor(extract(epoch from (now() - interval '3 hours' - r.starts_at)) / (r.repeat_weeks * 7 * 86400))::int + 1)),
      r.duration_minutes, r.max_participants, r.fee_cents, r.audience,
      r.place_name, r.place_address, r.place_lat, r.place_lng, r.repeat_weeks
    )
    returning id into v_new;
    update public.group_events set repeat_weeks = null where id = r.id;
  end loop;
end;
$BODY$;

revoke all on function public.process_events() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname in ('nexxup-process-meetups', 'nexxup-process-events');
select cron.schedule('nexxup-process-events', '*/5 * * * *', 'select public.process_events()');

-- ===== 13. Bisherige Gruppen-Termine in Events ueberfuehren =====
insert into public.group_events (
  group_id, created_by, title, sport, skill_level, starts_at, fee_cents, repeat_weeks,
  place_name, place_address, place_lat, place_lng
)
select
  g.id, g.created_by, g.name, g.sport, g.skill_level, g.next_meetup_at, g.fee_cents, g.meetup_repeat_weeks,
  mp.name, mp.address, mp.lat, mp.lng
from public.groups g
left join public.group_meetup_places mp on mp.group_id = g.id
where g.next_meetup_at is not null
  and g.next_meetup_at > now() - interval '3 hours'
  and not exists (select 1 from public.group_events e where e.group_id = g.id);

insert into public.event_participants (event_id, user_id, status)
select e.id, r.user_id, 'going'
from public.meetup_rsvps r
join public.groups g on g.id = r.group_id and g.next_meetup_at = r.meetup_at
join public.group_events e on e.group_id = g.id and e.starts_at = g.next_meetup_at
where r.status = 'yes'
on conflict do nothing;

-- Der alte Termin an der Gruppe wird nicht mehr verwendet.
update public.groups set next_meetup_at = null, meetup_repeat_weeks = null, fee_cents = null;

-- ===== 14. Admin-Kennzahlen auf Events umstellen =====
create or replace function public.admin_overview()
returns json
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  return json_build_object(
    'users_total', (select count(*) from public.profiles),
    'users_new_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'users_active_7d', (select count(*) from auth.users where last_sign_in_at > now() - interval '7 days'),
    'users_banned', (select count(*) from public.profiles where is_banned),
    'groups_total', (select count(*) from public.groups),
    'groups_public', (select count(*) from public.groups where is_public_event),
    'groups_new_7d', (select count(*) from public.groups where created_at > now() - interval '7 days'),
    'meetups_upcoming', (select count(*) from public.group_events where starts_at > now()),
    'posts_active', (select count(*) from public.board_posts where expires_at is null or expires_at > now()),
    'posts_new_7d', (select count(*) from public.board_posts where created_at > now() - interval '7 days'),
    'messages_7d', (select count(*) from public.chat_messages where created_at > now() - interval '7 days'),
    'rsvps_yes_upcoming', (
      select count(*) from public.event_participants ep
      join public.group_events e on e.id = ep.event_id
      where ep.status = 'going' and e.starts_at > now()
    ),
    'reports_open', (select count(*) from public.reports where resolved_at is null),
    'feedback_total', (select count(*) from public.feedback)
  );
end;
$BODY$;

revoke all on function public.admin_overview() from public, anon;
grant execute on function public.admin_overview() to authenticated;

-- ===== 15. Live-Updates =====
alter publication supabase_realtime add table public.group_events;
alter publication supabase_realtime add table public.event_participants;

notify pgrst, 'reload schema';
