-- ==========================================================================
-- Startklar fuer den Test unter Freunden (und spaeter die App-Stores)
--
-- Laienfassung - was diese Datei bewirkt:
--  1. Profil: kurzer "Ueber mich"-Text und Lieblingssportarten (oeffentlich
--     sichtbar wie Vorname + Stadt).
--  2. Gruppen: Niveau (alle / Anfaenger / Mittel / Fortgeschritten) und
--     mehr Sportarten.
--  3. Warteliste: Nachruecken passiert jetzt IMMER automatisch, egal wie ein
--     Platz frei wird (Austritt, Entfernen durch Ersteller, Sperre, geloeschtes
--     Konto, groessere Gruppe) - vorher nur beim normalen "Gruppe verlassen".
--  4. Melden: jetzt auch einzelne Nachrichten und Gruppen (Pflicht fuer die
--     App-Stores: jede Art von Nutzer-Inhalt muss meldbar sein). Admins koennen
--     Meldungen als erledigt markieren, Nachrichten/Gruppen loeschen.
--  5. Wortfilter: grob beleidigende Ausdruecke werden schon beim Absenden
--     abgelehnt (Store-Pflicht: "Filter vor dem Veroeffentlichen").
--  6. Spam-Bremse: Obergrenzen fuer Nachrichten, Gesuche, Gruppen, Meldungen.
--  7. Feedback: Tester koennen aus der App Rueckmeldungen schicken; nur
--     Admins koennen sie lesen.
--  8. Konto loeschen: Nutzer koennen ihr Konto samt Daten selbst loeschen
--     (DSGVO + Store-Pflicht). Eigene Gruppen gehen an das dienstaelteste
--     Mitglied ueber, statt fuer alle zu verschwinden.
--  9. Tempo: Indizes und schnellere Zugriffsregeln (Hinweise des
--     Supabase-Advisors).
-- ==========================================================================

-- ===== 1. Profil: Ueber mich + Lieblingssportarten =====
alter table public.profiles
  add column if not exists bio text,
  add column if not exists sports text[] not null default '{}';

alter table public.profiles drop constraint if exists profiles_bio_len;
alter table public.profiles add constraint profiles_bio_len check (bio is null or char_length(bio) <= 200);
alter table public.profiles drop constraint if exists profiles_first_name_len;
alter table public.profiles add constraint profiles_first_name_len check (char_length(first_name) <= 40) not valid;
alter table public.profiles drop constraint if exists profiles_sports_check;
alter table public.profiles add constraint profiles_sports_check check (
  cardinality(sports) <= 8
  and sports <@ array[
    'fussball', 'laufen', 'wandern', 'radfahren', 'tennis', 'volleyball',
    'basketball', 'fitness', 'schwimmen', 'yoga', 'klettern', 'padel',
    'badminton', 'tischtennis', 'handball', 'kampfsport', 'tanzen',
    'wintersport', 'golf', 'sonstiges'
  ]
);

grant update (bio, sports) on public.profiles to authenticated;

-- Oeffentliche Sicht um die zwei neuen Spalten erweitern (weiterhin KEIN
-- Geschlecht, kein Standort, kein Admin-/Sperr-Status).
create or replace view public.public_profiles
  with (security_invoker = false)
as
  select id, first_name, city, bio, sports
  from public.profiles;

revoke all on public.public_profiles from anon;
grant select on public.public_profiles to authenticated;

-- ===== 2. Gruppen: Niveau + mehr Sportarten =====
alter table public.groups
  add column if not exists skill_level text not null default 'alle';
alter table public.groups drop constraint if exists groups_skill_level_check;
alter table public.groups add constraint groups_skill_level_check
  check (skill_level in ('alle', 'anfaenger', 'mittel', 'fortgeschritten'));
grant update (skill_level) on public.groups to authenticated;

alter table public.groups drop constraint if exists groups_sport_check;
alter table public.groups add constraint groups_sport_check check (sport in (
  'fussball', 'laufen', 'wandern', 'radfahren', 'tennis', 'volleyball',
  'basketball', 'fitness', 'schwimmen', 'yoga', 'klettern', 'padel',
  'badminton', 'tischtennis', 'handball', 'kampfsport', 'tanzen',
  'wintersport', 'golf', 'sonstiges'
));

alter table public.board_posts drop constraint if exists board_posts_sport_check;
alter table public.board_posts add constraint board_posts_sport_check check (sport in (
  'fussball', 'laufen', 'wandern', 'radfahren', 'tennis', 'volleyball',
  'basketball', 'fitness', 'schwimmen', 'yoga', 'klettern', 'padel',
  'badminton', 'tischtennis', 'handball', 'kampfsport', 'tanzen',
  'wintersport', 'golf', 'sonstiges'
));

-- ===== 3. Warteliste: automatisches Nachruecken per Trigger =====
-- Fuellt freie Plaetze einer Gruppe mit den am laengsten Wartenden auf.
-- Sperrt die Gruppen-Zeile (wie join_group), damit nichts doppelt vergeben wird.
create or replace function public.fill_group_from_waitlist(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_max integer;
  v_active integer;
  v_next uuid;
begin
  select max_members into v_max from public.groups where id = p_group_id for update;
  if not found then
    return; -- Gruppe wird gerade geloescht
  end if;

  loop
    select count(*) into v_active
    from public.group_members where group_id = p_group_id and status = 'active';
    exit when v_active >= v_max;

    select id into v_next
    from public.group_members
    where group_id = p_group_id and status = 'waitlist'
    order by joined_at asc
    limit 1;
    exit when v_next is null;

    update public.group_members set status = 'active' where id = v_next;
  end loop;
end;
$BODY$;

revoke all on function public.fill_group_from_waitlist(uuid) from public, anon, authenticated;

create or replace function public.on_member_removed()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if old.status = 'active' then
    perform public.fill_group_from_waitlist(old.group_id);
  end if;
  return old;
end;
$BODY$;

drop trigger if exists on_member_removed on public.group_members;
create trigger on_member_removed
  after delete on public.group_members
  for each row execute function public.on_member_removed();

create or replace function public.on_group_capacity_raised()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  perform public.fill_group_from_waitlist(new.id);
  return new;
end;
$BODY$;

drop trigger if exists on_group_capacity_raised on public.groups;
create trigger on_group_capacity_raised
  after update of max_members on public.groups
  for each row when (new.max_members > old.max_members)
  execute function public.on_group_capacity_raised();

revoke all on function public.on_member_removed() from public, anon, authenticated;
revoke all on function public.on_group_capacity_raised() from public, anon, authenticated;

-- leave_group: nur noch austreten - das Nachruecken uebernimmt der Trigger.
create or replace function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  perform 1 from public.groups where id = p_group_id for update;
  delete from public.group_members
  where group_id = p_group_id and user_id = auth.uid();
end;
$BODY$;

revoke all on function public.leave_group(uuid) from public, anon;
grant execute on function public.leave_group(uuid) to authenticated;

-- ===== 4. Melden: Nachrichten und Gruppen + "erledigt" =====
alter table public.reports
  add column if not exists reported_message_id uuid references public.chat_messages(id) on delete cascade,
  add column if not exists reported_group_id uuid references public.groups(id) on delete cascade,
  add column if not exists resolved_at timestamptz;

alter table public.reports drop constraint if exists reports_check;
alter table public.reports drop constraint if exists reports_one_target;
alter table public.reports add constraint reports_one_target
  check (num_nonnulls(reported_post_id, reported_profile_id, reported_message_id, reported_group_id) = 1);

create unique index if not exists reports_unique_message_idx
  on public.reports (reporter_id, reported_message_id) where reported_message_id is not null;
create unique index if not exists reports_unique_group_idx
  on public.reports (reporter_id, reported_group_id) where reported_group_id is not null;

-- Melden darf man nur, was man selbst sehen kann (die Unterabfragen laufen
-- mit den Rechten des Meldenden -> RLS der jeweiligen Tabelle greift).
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own" on public.reports
  for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and resolved_at is null
    and (reported_message_id is null
         or exists (select 1 from public.chat_messages m where m.id = reported_message_id and m.sender_id <> (select auth.uid())))
    and (reported_group_id is null
         or exists (select 1 from public.groups g where g.id = reported_group_id))
  );

drop function if exists public.admin_list_reports();
create or replace function public.admin_list_reports()
returns table (
  report_id uuid,
  kind text,
  content text,
  reported_post_id uuid,
  reported_message_id uuid,
  reported_group_id uuid,
  target_user_id uuid,
  target_user_name text,
  target_is_banned boolean,
  reporter_id uuid,
  reporter_name text,
  reason text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;

  return query
    select
      r.id,
      case
        when r.reported_post_id is not null then 'post'
        when r.reported_message_id is not null then 'message'
        when r.reported_group_id is not null then 'group'
        else 'profile'
      end,
      coalesce(bp.body, m.body, g.name || coalesce(' – ' || g.description, ''), tp.bio),
      r.reported_post_id,
      r.reported_message_id,
      r.reported_group_id,
      t.target_id,
      tp.first_name,
      coalesce(tp.is_banned, false),
      r.reporter_id,
      wer.first_name,
      r.reason,
      r.created_at
    from public.reports r
    left join public.board_posts bp on bp.id = r.reported_post_id
    left join public.chat_messages m on m.id = r.reported_message_id
    left join public.groups g on g.id = r.reported_group_id
    cross join lateral (
      select coalesce(r.reported_profile_id, bp.author_id, m.sender_id, g.created_by) as target_id
    ) t
    left join public.profiles tp on tp.id = t.target_id
    left join public.profiles wer on wer.id = r.reporter_id
    where r.resolved_at is null
    order by r.created_at desc;
end;
$BODY$;

create or replace function public.admin_resolve_report(p_report_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  update public.reports set resolved_at = now() where id = p_report_id;
end;
$BODY$;

create or replace function public.admin_delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  delete from public.chat_messages where id = p_message_id;
end;
$BODY$;

create or replace function public.admin_delete_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  delete from public.groups where id = p_group_id;
end;
$BODY$;

-- Sperren entfernt jetzt auch Nachrichten und eigene Gruppen des Gesperrten.
create or replace function public.ban_user(p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  if p_target_id = auth.uid() then
    raise exception 'Man kann sich nicht selbst sperren';
  end if;
  if coalesce((select is_admin from public.profiles where id = p_target_id), false) then
    raise exception 'Ein Admin kann nicht gesperrt werden';
  end if;

  update public.profiles set is_banned = true where id = p_target_id;
  delete from public.board_posts where author_id = p_target_id;
  delete from public.chat_messages where sender_id = p_target_id;
  delete from public.groups where created_by = p_target_id;
  delete from public.group_members where user_id = p_target_id;
  update public.reports r set resolved_at = now()
  where r.resolved_at is null and r.reported_profile_id = p_target_id;
end;
$BODY$;

create or replace function public.admin_unban_user(p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  update public.profiles set is_banned = false where id = p_target_id;
end;
$BODY$;

revoke all on function public.admin_list_reports() from public, anon;
revoke all on function public.admin_resolve_report(uuid) from public, anon;
revoke all on function public.admin_delete_message(uuid) from public, anon;
revoke all on function public.admin_delete_group(uuid) from public, anon;
revoke all on function public.ban_user(uuid) from public, anon;
revoke all on function public.admin_unban_user(uuid) from public, anon;
grant execute on function public.admin_list_reports() to authenticated;
grant execute on function public.admin_resolve_report(uuid) to authenticated;
grant execute on function public.admin_delete_message(uuid) to authenticated;
grant execute on function public.admin_delete_group(uuid) to authenticated;
grant execute on function public.ban_user(uuid) to authenticated;
grant execute on function public.admin_unban_user(uuid) to authenticated;

-- Gemeldete Nachrichten sieht der Meldende nicht mehr (wie beim Brett).
drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select" on public.chat_messages
  for select to authenticated
  using (
    (
      (thread_id is not null and exists (
        select 1 from public.chat_threads t
        where t.id = chat_messages.thread_id and (select auth.uid()) in (t.user_a, t.user_b)
      ))
      or (group_id is not null and public.is_group_member(group_id))
    )
    and not exists (
      select 1 from public.reports r
      where r.reporter_id = (select auth.uid()) and r.reported_message_id = chat_messages.id
    )
  );

-- ===== 5. Wortfilter vor dem Veroeffentlichen =====
create table if not exists public.blocked_terms (
  term text primary key check (term = lower(term) and char_length(term) between 2 and 60)
);
alter table public.blocked_terms enable row level security;
-- Keine Policies: nur intern nutzbar. Pflege durch Admins per SQL.
revoke all on public.blocked_terms from anon, authenticated;

insert into public.blocked_terms (term) values
  ('hurensohn'), ('hurensöhne'), ('fotze'), ('nutte'), ('schlampe'), ('wichser'),
  ('missgeburt'), ('spast'), ('spasti'), ('kanake'), ('kanacke'), ('nigger'), ('neger'),
  ('schwuchtel'), ('fick dich'), ('heil hitler'), ('sieg heil'), ('vergasen'),
  ('faggot'), ('retard'), ('cunt'), ('whore'), ('kill yourself'), ('bring dich um')
on conflict do nothing;

-- true, wenn der Text einen gesperrten Ausdruck als ganzes Wort enthaelt.
create or replace function public.contains_blocked_term(p_text text)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select p_text is not null and exists (
    select 1 from public.blocked_terms b
    where lower(p_text) ~ ('(^|[^[:alnum:]äöüß])' || regexp_replace(b.term, '([.*+?^${}()|\[\]\\])', '\\\1', 'g') || '($|[^[:alnum:]äöüß])')
  );
$BODY$;

revoke all on function public.contains_blocked_term(text) from public, anon, authenticated;

-- Allgemeiner Trigger: prueft die als Argumente genannten Textspalten.
create or replace function public.reject_objectionable()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_col text;
  v_val text;
begin
  foreach v_col in array tg_argv loop
    v_val := to_jsonb(new) ->> v_col;
    if public.contains_blocked_term(v_val) then
      raise exception 'content_blocked' using errcode = 'P0001',
        hint = 'Der Text enthaelt Ausdruecke, die hier nicht erlaubt sind.';
    end if;
  end loop;
  return new;
end;
$BODY$;

revoke all on function public.reject_objectionable() from public, anon, authenticated;

drop trigger if exists filter_board_post on public.board_posts;
create trigger filter_board_post before insert or update of body on public.board_posts
  for each row execute function public.reject_objectionable('body');
drop trigger if exists filter_chat_message on public.chat_messages;
create trigger filter_chat_message before insert on public.chat_messages
  for each row execute function public.reject_objectionable('body');
drop trigger if exists filter_group on public.groups;
create trigger filter_group before insert or update of name, description on public.groups
  for each row execute function public.reject_objectionable('name', 'description');
drop trigger if exists filter_poll on public.group_polls;
create trigger filter_poll before insert on public.group_polls
  for each row execute function public.reject_objectionable('question');
drop trigger if exists filter_poll_option on public.group_poll_options;
create trigger filter_poll_option before insert on public.group_poll_options
  for each row execute function public.reject_objectionable('label');
drop trigger if exists filter_profile on public.profiles;
create trigger filter_profile before insert or update of first_name, bio on public.profiles
  for each row execute function public.reject_objectionable('first_name', 'bio');

-- ===== 6. Spam-Bremse =====
-- Argumente: Spalte mit der Nutzer-ID, Obergrenze, Zeitraum (z. B. '1 minute').
create or replace function public.rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_count integer;
begin
  if auth.uid() is null then
    return new; -- interne Vorgaenge (z. B. Wartung per SQL)
  end if;
  execute format(
    'select count(*) from public.%I where %I = $1 and created_at > now() - $2::interval',
    tg_table_name, tg_argv[0]
  ) into v_count using auth.uid(), tg_argv[2];
  if v_count >= tg_argv[1]::integer then
    raise exception 'rate_limited' using errcode = 'P0001',
      hint = 'Zu viele Aktionen in kurzer Zeit. Bitte spaeter erneut versuchen.';
  end if;
  return new;
end;
$BODY$;

revoke all on function public.rate_limit() from public, anon, authenticated;

drop trigger if exists rate_limit_chat on public.chat_messages;
create trigger rate_limit_chat before insert on public.chat_messages
  for each row execute function public.rate_limit('sender_id', '30', '1 minute');
drop trigger if exists rate_limit_posts on public.board_posts;
create trigger rate_limit_posts before insert on public.board_posts
  for each row execute function public.rate_limit('author_id', '10', '1 day');
drop trigger if exists rate_limit_groups on public.groups;
create trigger rate_limit_groups before insert on public.groups
  for each row execute function public.rate_limit('created_by', '10', '1 day');
drop trigger if exists rate_limit_reports on public.reports;
create trigger rate_limit_reports before insert on public.reports
  for each row execute function public.rate_limit('reporter_id', '30', '1 day');

-- ===== 7. Feedback der Tester =====
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid default auth.uid() references public.profiles(id) on delete set null,
  message text not null check (char_length(btrim(message)) between 3 and 2000),
  page text check (page is null or char_length(page) <= 200),
  created_at timestamptz not null default now()
);

alter table public.feedback enable row level security;

drop policy if exists "feedback_insert_own" on public.feedback;
create policy "feedback_insert_own" on public.feedback
  for insert to authenticated with check (user_id = (select auth.uid()));
-- Kein select fuer Nutzer: lesen nur Admins ueber admin_list_feedback().

revoke all on public.feedback from anon;
revoke all on public.feedback from authenticated;
grant insert on public.feedback to authenticated;

drop trigger if exists rate_limit_feedback on public.feedback;
create trigger rate_limit_feedback before insert on public.feedback
  for each row execute function public.rate_limit('user_id', '20', '1 day');

create or replace function public.admin_list_feedback()
returns table (id uuid, user_name text, message text, page text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if not public.is_admin() then
    raise exception 'Nur fuer Admins';
  end if;
  return query
    select f.id, p.first_name, f.message, f.page, f.created_at
    from public.feedback f
    left join public.profiles p on p.id = f.user_id
    order by f.created_at desc
    limit 200;
end;
$BODY$;

revoke all on function public.admin_list_feedback() from public, anon;
grant execute on function public.admin_list_feedback() to authenticated;

-- ===== 8. Konto loeschen =====
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Nicht angemeldet';
  end if;

  -- Eigene Gruppen mit weiteren aktiven Mitgliedern gehen an das
  -- dienstaelteste Mitglied ueber (statt fuer alle zu verschwinden).
  update public.groups g
  set created_by = (
    select gm.user_id
    from public.group_members gm
    where gm.group_id = g.id and gm.status = 'active' and gm.user_id <> v_me
    order by gm.joined_at asc
    limit 1
  )
  where g.created_by = v_me
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = g.id and gm.status = 'active' and gm.user_id <> v_me
    );

  -- Loescht das Login. Profil, Mitgliedschaften, Gesuche, Nachrichten,
  -- Zusagen, Stimmen, Blockierungen und Meldungen haengen per
  -- "on delete cascade" daran und verschwinden mit. Uebrige eigene Gruppen
  -- (ohne weitere Mitglieder) ebenfalls.
  delete from auth.users where id = v_me;
end;
$BODY$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ===== 9. Tempo =====
-- a) Fehlende Indizes auf Fremdschluesseln
create index if not exists board_posts_author_idx on public.board_posts (author_id);
create index if not exists chat_messages_sender_idx on public.chat_messages (sender_id, created_at desc);
create index if not exists chat_threads_post_idx on public.chat_threads (post_id);
create index if not exists chat_threads_user_b_idx on public.chat_threads (user_b);
create index if not exists group_members_user_idx on public.group_members (user_id);
create index if not exists group_poll_votes_user_idx on public.group_poll_votes (user_id);
create index if not exists group_polls_created_by_idx on public.group_polls (created_by);
create index if not exists groups_created_by_idx on public.groups (created_by);
create index if not exists meetup_rsvps_user_idx on public.meetup_rsvps (user_id);
create index if not exists reports_post_idx on public.reports (reported_post_id);
create index if not exists reports_profile_idx on public.reports (reported_profile_id);
create index if not exists reports_message_idx on public.reports (reported_message_id);
create index if not exists reports_group_idx on public.reports (reported_group_id);
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);
create index if not exists feedback_user_idx on public.feedback (user_id);

-- b) Zugriffsregeln: "auth.uid()" nur einmal pro Abfrage auswerten statt pro
--    Zeile. Die Regeln bleiben inhaltlich exakt gleich - es wird nur
--    "auth.uid()" durch "(select auth.uid())" ersetzt.
do $do$
declare
  p record;
  v_sql text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') ~ 'auth\.uid\(\)' or coalesce(with_check, '') ~ 'auth\.uid\(\)')
  loop
    v_sql := format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    if p.qual is not null then
      v_sql := v_sql || ' using (' ||
        replace(replace(p.qual, '( SELECT auth.uid() AS uid)', '~~UID~~'), 'auth.uid()', '(select auth.uid())') || ')';
    end if;
    if p.with_check is not null then
      v_sql := v_sql || ' with check (' ||
        replace(replace(p.with_check, '( SELECT auth.uid() AS uid)', '~~UID~~'), 'auth.uid()', '(select auth.uid())') || ')';
    end if;
    v_sql := replace(v_sql, '~~UID~~', '(select auth.uid())');
    execute v_sql;
  end loop;
end;
$do$;

notify pgrst, 'reload schema';
