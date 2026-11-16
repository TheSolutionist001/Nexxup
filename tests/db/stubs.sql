-- Minimale Nachbildung der Supabase-Umgebung fuer lokale Tests (PGlite).
-- Ersetzt: Rollen, auth-Schema, PostGIS, pg_net, Vault, pg_cron, Realtime.
create role anon nologin;
create role authenticated nologin;
create role supabase_auth_admin nologin;

create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  instance_id uuid,
  aud text,
  role text,
  email text unique,
  raw_user_meta_data jsonb default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_sign_in_at timestamptz,
  email_confirmed_at timestamptz
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid
$$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;

-- PostGIS-Attrappe: Koordinaten als Text "lng lat", Abstand grob in Metern
create schema extensions;
grant usage on schema extensions to authenticated, anon;
create domain extensions.geometry as text;
create domain extensions.geography as text;
create function extensions.ST_MakePoint(float8, float8) returns extensions.geometry language sql immutable as $$ select ($1::text || ' ' || $2::text)::extensions.geometry $$;
create function extensions.ST_SetSRID(extensions.geometry, int) returns extensions.geometry language sql immutable as $$ select $1 $$;
create function extensions.ST_X(extensions.geometry) returns float8 language sql immutable as $$ select split_part($1::text, ' ', 1)::float8 $$;
create function extensions.ST_Y(extensions.geometry) returns float8 language sql immutable as $$ select split_part($1::text, ' ', 2)::float8 $$;
create function extensions.ST_Distance(extensions.geography, extensions.geography) returns float8 language sql immutable as $$
  select 111320 * sqrt(power(split_part($1::text,' ',1)::float8 - split_part($2::text,' ',1)::float8, 2)
                     + power(split_part($1::text,' ',2)::float8 - split_part($2::text,' ',2)::float8, 2))
$$;
create function extensions.ST_DWithin(extensions.geography, extensions.geography, numeric) returns boolean language sql immutable as $$
  select extensions.ST_Distance($1, $2) <= $3
$$;

-- pg_net + Vault: Push-Aufrufe landen in einer Tabelle (pruefbar im Test)
create schema net;
create table net.sent (id serial primary key, url text, body jsonb, at timestamptz default now());
create function net.http_post(url text, headers jsonb default '{}', body jsonb default '{}') returns bigint language sql as $$
  insert into net.sent (url, body) values (url, body) returning id::bigint
$$;
create schema vault;
create table vault.decrypted_secrets (name text, decrypted_secret text);
insert into vault.decrypted_secrets values ('onesignal_app_id', 'test-app'), ('onesignal_rest_api_key', 'test-key');

-- pg_cron-Attrappe
create schema cron;
create table cron.job (jobid serial primary key, jobname text, schedule text, command text);
create function cron.schedule(text, text, text) returns bigint language sql as $$
  insert into cron.job (jobname, schedule, command) values ($1, $2, $3) returning jobid::bigint
$$;
create function cron.unschedule(bigint) returns boolean language sql as $$
  with d as (delete from cron.job where jobid = $1 returning 1) select exists (select 1 from d)
$$;

create publication supabase_realtime;
