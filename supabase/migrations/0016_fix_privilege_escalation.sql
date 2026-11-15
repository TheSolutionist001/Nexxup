-- ==========================================================================
-- SICHERHEITS-FIX: Rechte-Ausweitung ueber das eigene Profil
--
-- Laienfassung: Bisher durfte jeder angemeldete Nutzer in SEINER Profil-Zeile
-- ALLE Spalten aendern - auch "is_admin" und "is_banned". Mit einem direkten
-- API-Aufruf haette man sich damit selbst zum Admin machen oder eine Sperre
-- aufheben koennen. Ab jetzt sind nur noch die harmlosen Spalten aenderbar;
-- Admin-/Sperr-Status aendert nur noch die Datenbank selbst (ban_user bzw.
-- manuell per SQL).
--
-- Gleiches Prinzip ("nur die noetigen Spalten") fuer Gruppen und Gesuche:
-- technische Spalten wie id, created_by, created_at sind nicht mehr aenderbar.
-- Der Standort (location) wird weiterhin nur ueber set_my_location() gesetzt.
-- ==========================================================================

revoke update on public.profiles from authenticated;
grant update (first_name, gender, city) on public.profiles to authenticated;

revoke update on public.groups from authenticated;
grant update (name, description, max_members, is_public_event, sport, next_meetup_at, city, meetup_repeat_weeks)
  on public.groups to authenticated;

revoke update on public.board_posts from authenticated;
grant update (body, target_genders, sport) on public.board_posts to authenticated;

-- Gruppen: max_members darf nicht unter die Zahl der aktiven Mitglieder sinken.
create or replace function public.check_group_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $BODY$
begin
  if new.max_members < (
    select count(*) from public.group_members where group_id = new.id and status = 'active'
  ) then
    raise exception 'max_members kleiner als die Zahl der aktiven Mitglieder';
  end if;
  return new;
end;
$BODY$;

drop trigger if exists check_group_capacity on public.groups;
create trigger check_group_capacity
  before update of max_members on public.groups
  for each row execute function public.check_group_capacity();

revoke all on function public.check_group_capacity() from public, anon, authenticated;

notify pgrst, 'reload schema';
