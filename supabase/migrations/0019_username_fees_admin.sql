-- ==========================================================================
-- Nutzername, Kosten/Bezahlt-Liste fuer Termine, Admin-Uebersicht
--
-- Laienfassung:
--  1. Nutzername: Jede Person bekommt einen eindeutigen Namen wie
--     "@sandro_4821". Zwei "Sandro" lassen sich damit sicher unterscheiden.
--     Er wird bei der Registrierung automatisch vergeben und kann im Profil
--     geaendert werden (klein, 3-20 Zeichen, nur a-z, 0-9, Punkt, Unterstrich).
--  2. Kosten: Der Gruppenleiter kann "Kosten pro Person" hinterlegen und pro
--     Termin abhaken, wer bezahlt hat. Das ist nur eine Merkliste - die App
--     wickelt KEINE Zahlungen ab. Sehen kann die Liste nur der Gruppenleiter;
--     jedes Mitglied sieht ausschliesslich den eigenen Status.
--  3. Admin-Uebersicht: Kennzahlen, Nutzerliste und Gruppenliste - nur fuer
--     Admins (jede Funktion prueft das selbst).
-- ==========================================================================

-- ===== 1. Nutzername =====
alter table public.profiles add column if not exists username text;

-- Erzeugt einen freien Nutzernamen aus dem Vornamen (z. B. "Jörg" -> "joerg_4821").
create or replace function public.generate_username(p_first_name text)
returns text
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_base text;
  v_try text;
begin
  v_base := lower(coalesce(p_first_name, ''));
  v_base := replace(replace(replace(replace(v_base, 'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss');
  v_base := regexp_replace(v_base, '[^a-z0-9]', '', 'g');
  if char_length(v_base) < 2 then
    v_base := 'sport';
  end if;
  v_base := left(v_base, 12);
  loop
    v_try := v_base || '_' || lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (select 1 from public.profiles where username = v_try);
  end loop;
  return v_try;
end;
$BODY$;

revoke all on function public.generate_username(text) from public, anon, authenticated;

update public.profiles set username = public.generate_username(first_name) where username is null;

alter table public.profiles alter column username set not null;
alter table public.profiles drop constraint if exists profiles_username_format;
alter table public.profiles add constraint profiles_username_format
  check (username ~ '^[a-z0-9][a-z0-9_.]{2,19}$');
create unique index if not exists profiles_username_key on public.profiles (username);

grant update (username) on public.profiles to authenticated;

-- Neue Konten bekommen automatisch einen Nutzernamen.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  insert into public.profiles (id, first_name, gender, city, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    new.raw_user_meta_data ->> 'gender',
    new.raw_user_meta_data ->> 'city',
    public.generate_username(new.raw_user_meta_data ->> 'first_name')
  );
  return new;
end;
$BODY$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- Oeffentliche Sicht: Nutzername kommt dazu (neue Spalte am Ende).
create or replace view public.public_profiles
  with (security_invoker = false)
as
  select id, first_name, city, bio, sports, username
  from public.profiles;

revoke all on public.public_profiles from anon;
grant select on public.public_profiles to authenticated;

-- Wortfilter auch fuer den Nutzernamen
drop trigger if exists filter_profile on public.profiles;
create trigger filter_profile before insert or update of first_name, bio, username on public.profiles
  for each row execute function public.reject_objectionable('first_name', 'bio', 'username');

-- ===== 2. Kosten + Bezahlt-Liste =====
alter table public.groups add column if not exists fee_cents integer;
alter table public.groups drop constraint if exists groups_fee_range;
alter table public.groups add constraint groups_fee_range check (fee_cents is null or fee_cents between 1 and 1000000);
grant update (fee_cents) on public.groups to authenticated;

create table if not exists public.meetup_payments (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  meetup_at timestamptz not null,
  paid_at timestamptz not null default now(),
  primary key (group_id, user_id, meetup_at)
);

create index if not exists meetup_payments_user_idx on public.meetup_payments (user_id);

alter table public.meetup_payments enable row level security;

-- Lesen: der Gruppenleiter alles, jedes Mitglied nur die eigene Zeile.
drop policy if exists "meetup_payments_select" on public.meetup_payments;
create policy "meetup_payments_select" on public.meetup_payments
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_group_creator(group_id));
-- Schreiben nur ueber set_payment() (prueft: Gruppenleiter, Mitglied, aktueller Termin).

revoke all on public.meetup_payments from anon;
revoke all on public.meetup_payments from authenticated;
grant select on public.meetup_payments to authenticated;

-- Gruppenleiter hakt fuer den aktuellen Termin ab, wer bezahlt hat (oder nimmt es zurueck).
create or replace function public.set_payment(p_group_id uuid, p_user_id uuid, p_paid boolean)
returns void
language plpgsql
security definer
set search_path = public
as $BODY$
declare
  v_at timestamptz;
begin
  if not public.is_group_creator(p_group_id) then
    raise exception 'Nur der Gruppenleiter kann Zahlungen abhaken';
  end if;

  select next_meetup_at into v_at from public.groups where id = p_group_id;
  if v_at is null then
    raise exception 'Kein Termin eingetragen';
  end if;

  if not exists (
    select 1 from public.group_members where group_id = p_group_id and user_id = p_user_id
  ) then
    raise exception 'Kein Mitglied dieser Gruppe';
  end if;

  if p_paid then
    insert into public.meetup_payments (group_id, user_id, meetup_at)
    values (p_group_id, p_user_id, v_at)
    on conflict do nothing;
  else
    delete from public.meetup_payments
    where group_id = p_group_id and user_id = p_user_id and meetup_at = v_at;
  end if;
end;
$BODY$;

revoke all on function public.set_payment(uuid, uuid, boolean) from public, anon;
grant execute on function public.set_payment(uuid, uuid, boolean) to authenticated;

alter publication supabase_realtime add table public.meetup_payments;

-- ===== 3. Admin-Uebersicht =====
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
    'meetups_upcoming', (select count(*) from public.groups where next_meetup_at > now()),
    'posts_active', (select count(*) from public.board_posts where expires_at is null or expires_at > now()),
    'posts_new_7d', (select count(*) from public.board_posts where created_at > now() - interval '7 days'),
    'messages_7d', (select count(*) from public.chat_messages where created_at > now() - interval '7 days'),
    'rsvps_yes_upcoming', (
      select count(*) from public.meetup_rsvps r
      join public.groups g on g.id = r.group_id and g.next_meetup_at = r.meetup_at
      where r.status = 'yes' and r.meetup_at > now()
    ),
    'reports_open', (select count(*) from public.reports where resolved_at is null),
    'feedback_total', (select count(*) from public.feedback)
  );
end;
$BODY$;

create or replace function public.admin_list_users()
returns table (
  id uuid,
  first_name text,
  username text,
  city text,
  email text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  is_admin boolean,
  is_banned boolean,
  groups_count bigint,
  posts_count bigint
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
      p.id, p.first_name, p.username, p.city, u.email::text, p.created_at, u.last_sign_in_at,
      p.is_admin, p.is_banned,
      (select count(*) from public.group_members m where m.user_id = p.id),
      (select count(*) from public.board_posts b where b.author_id = p.id)
    from public.profiles p
    join auth.users u on u.id = p.id
    order by p.created_at desc
    limit 500;
end;
$BODY$;

create or replace function public.admin_list_groups()
returns table (
  id uuid,
  name text,
  sport text,
  city text,
  is_public_event boolean,
  creator_name text,
  creator_username text,
  members_active bigint,
  members_waitlist bigint,
  max_members integer,
  next_meetup_at timestamptz,
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
      g.id, g.name, g.sport, g.city, g.is_public_event, p.first_name, p.username,
      (select count(*) from public.group_members m where m.group_id = g.id and m.status = 'active'),
      (select count(*) from public.group_members m where m.group_id = g.id and m.status = 'waitlist'),
      g.max_members, g.next_meetup_at, g.created_at
    from public.groups g
    left join public.profiles p on p.id = g.created_by
    order by g.created_at desc
    limit 500;
end;
$BODY$;

revoke all on function public.admin_overview() from public, anon;
revoke all on function public.admin_list_users() from public, anon;
revoke all on function public.admin_list_groups() from public, anon;
grant execute on function public.admin_overview() to authenticated;
grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_list_groups() to authenticated;

notify pgrst, 'reload schema';
