// Lokale Test-Datenbank (PGlite = Postgres im Speicher): laedt die
// Supabase-Attrappen und ALLE Migrationen der Reihe nach. So lassen sich
// Zugriffsregeln (RLS) und Datenbank-Funktionen ohne echte Datenbank pruefen.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';

const MIGRATIONS = 'supabase/migrations';

export async function createDb(): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(readFileSync('tests/db/stubs.sql', 'utf8'));
  for (const file of readdirSync(MIGRATIONS).sort()) {
    let sql = readFileSync(join(MIGRATIONS, file), 'utf8');
    // Erweiterungen (PostGIS, pg_net, pg_cron) gibt es hier nur als Attrappen
    sql = sql.replace(/^\s*create extension[^;]*;/gim, '');
    sql = sql.replace(/extensions\.geography\(Point, 4326\)/g, 'extensions.geography');
    sql = sql.replace(/using gist \(/g, '(');
    try {
      await db.exec(sql);
    } catch (e) {
      throw new Error(`Migration ${file} schlug fehl: ${(e as Error).message}`);
    }
  }
  return db;
}

let counter = 0;

// Legt ein Konto an (der Trigger erzeugt das Profil) und liefert die Nutzer-ID.
export async function newUser(db: PGlite, firstName: string, sports: string[] = []): Promise<string> {
  counter += 1;
  const res = await db.query<{ id: string }>(
    `insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id`,
    [`user${counter}@test.invalid`, JSON.stringify({ first_name: firstName, gender: 'keine_angabe', city: 'Tamm' })],
  );
  const id = res.rows[0]!.id;
  if (sports.length > 0) {
    await db.query(`update public.profiles set sports = $1 where id = $2`, [sports, id]);
  }
  return id;
}

// Fuehrt SQL als angemeldeter Nutzer aus (wie ein Aufruf aus der App).
export async function as<T = Record<string, unknown>>(
  db: PGlite,
  userId: string,
  sql: string,
  params: unknown[] = [],
): Promise<T[]> {
  await db.query(`select set_config('request.jwt.claims', $1, false)`, [
    JSON.stringify({ sub: userId, role: 'authenticated' }),
  ]);
  await db.exec('set role authenticated');
  try {
    const res = await db.query<T>(sql, params);
    return res.rows;
  } finally {
    await db.exec('reset role');
    await db.query(`select set_config('request.jwt.claims', '', false)`);
  }
}

// Wie as(), liefert aber die Fehlermeldung statt zu werfen (null = kein Fehler).
export async function errorOf(db: PGlite, userId: string, sql: string, params: unknown[] = []): Promise<string | null> {
  try {
    await as(db, userId, sql, params);
    return null;
  } catch (e) {
    return (e as Error).message;
  }
}

// Versendete Push-Nachrichten (die Attrappe schreibt sie in net.sent)
export async function pushes(db: PGlite): Promise<{ to: string; title: string }[]> {
  const res = await db.query<{ to: string; title: string }>(
    `select body -> 'include_aliases' -> 'external_id' ->> 0 as "to", body -> 'headings' ->> 'de' as title
     from net.sent order by id`,
  );
  return res.rows;
}
