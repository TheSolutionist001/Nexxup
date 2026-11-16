import { beforeAll, describe, expect, it } from 'vitest';
import type { PGlite } from '@electric-sql/pglite';
import { as, createDb, errorOf, newUser, pushes } from './helpers';

// Events in Gruppen: Zusage, Warteliste mit 1-Stunden-Angebot, Sichtbarkeit,
// Organisator-Rechte, Gaeste, Bezahlt-Liste. Laeuft gegen eine lokale
// Datenbank mit allen Migrationen.
describe('Events in Gruppen (Datenbank)', () => {
  let db: PGlite;
  let anna: string; // Gruppen-Erstellerin, mag Fussball
  let ben: string; // Mitglied, mag Fussball
  let cara: string; // Mitglied, keine Interessen
  let dino: string; // Mitglied, mag Tennis
  let gast: string; // kein Mitglied
  let fremd: string; // kein Mitglied, kein Link
  let group: string;
  let event: string;

  const status = async (user: string) =>
    (await db.query<{ status: string }>(`select status from public.event_participants where event_id = $1 and user_id = $2`, [event, user]))
      .rows[0]?.status ?? null;

  beforeAll(async () => {
    db = await createDb();
    anna = await newUser(db, 'Anna', ['fussball']);
    ben = await newUser(db, 'Ben', ['fussball']);
    cara = await newUser(db, 'Cara');
    dino = await newUser(db, 'Dino', ['tennis']);
    gast = await newUser(db, 'Gast');
    fremd = await newUser(db, 'Fremd');

    const g = await as<{ id: string }>(db, anna, `select public.create_group('Gruppo Bietigheim', null, 100000) as id`);
    group = g[0]!.id;
    for (const u of [ben, cara, dino]) await as(db, u, `select public.join_group($1)`, [group]);

    const e = await as<{ id: string }>(
      db,
      anna,
      `insert into public.group_events (group_id, created_by, title, sport, starts_at, max_participants, audience, fee_cents)
       values ($1, $2, 'Fussball am Freitag', 'fussball', now() + interval '3 days', 2, 'interested', 500)
       returning id`,
      [group, anna],
    );
    event = e[0]!.id;
  }, 120_000);

  it('Gruppe hat keine Teilnehmergrenze mehr: alle sind aktive Mitglieder', async () => {
    const rows = await db.query<{ n: number }>(`select count(*)::int as n from public.group_members where group_id = $1 and status = 'active'`, [group]);
    expect(rows.rows[0]!.n).toBe(4);
  });

  it('neues Event: Push nur an Mitglieder, für die es sichtbar ist', async () => {
    const sent = (await pushes(db)).filter((p) => p.title.startsWith('Neues Event'));
    expect(sent.map((p) => p.to)).toEqual([ben]); // Anna organisiert selbst, Cara/Dino ohne Fussball
  });

  it('Sichtbarkeit "nur Interessierte": Ben sieht es, Cara und Dino nicht', async () => {
    const titles = async (u: string) => (await as<{ title: string }>(db, u, `select title from public.my_events($1)`, [group])).map((r) => r.title);
    expect(await titles(ben)).toEqual(['Fussball am Freitag']);
    expect(await titles(cara)).toEqual([]);
    expect(await titles(dino)).toEqual([]);
    expect(await titles(anna)).toEqual(['Fussball am Freitag']); // Organisatorin immer
  });

  it('eigene Einstellung "nur meine Interessen" blendet fremde Sportarten aus', async () => {
    await as(db, anna, `insert into public.group_events (group_id, created_by, title, sport, starts_at) values ($1, $2, 'Tennis offen', 'tennis', now() + interval '5 days')`, [group, anna]);
    const titles = async (u: string) => (await as<{ title: string }>(db, u, `select title from public.my_events($1)`, [group])).map((r) => r.title);
    expect(await titles(ben)).toEqual(['Fussball am Freitag', 'Tennis offen']);
    await as(db, ben, `select public.set_my_event_filter($1, 'interests')`, [group]);
    expect(await titles(ben)).toEqual(['Fussball am Freitag']);
    await as(db, ben, `select public.set_my_event_filter($1, 'all')`, [group]);
  });

  it('Mitglied ist nicht automatisch dabei; Zusage bis zur Platzzahl, danach Warteliste', async () => {
    expect(await status(ben)).toBeNull();
    const join = async (u: string) => (await as<{ s: string }>(db, u, `select public.join_event($1) as s`, [event]))[0]!.s;
    expect(await join(anna)).toBe('going');
    expect(await join(ben)).toBe('going');
    expect(await join(cara)).toBe('waitlist');
    expect(await join(dino)).toBe('waitlist');
    expect(await join(ben)).toBe('going'); // doppelt tippen aendert nichts
  });

  it('Fremde können weder zusagen noch das Event sehen', async () => {
    expect(await errorOf(db, fremd, `select public.join_event($1)`, [event])).toMatch(/Nur Mitglieder/);
    expect(await as(db, fremd, `select id from public.group_events`)).toEqual([]);
    expect(await as(db, fremd, `select user_id from public.event_participants`)).toEqual([]);
  });

  it('Absage: die/der Nächste bekommt den Platz für 1 Stunde angeboten (mit Push), der Platz bleibt reserviert', async () => {
    await as(db, ben, `select public.leave_event($1)`, [event]);
    expect(await status(ben)).toBeNull();
    expect(await status(cara)).toBe('offered');
    expect(await status(dino)).toBe('waitlist');
    const offer = await db.query<{ mins: number }>(
      `select round(extract(epoch from offer_expires_at - now()) / 60)::int as mins from public.event_participants where event_id = $1 and user_id = $2`,
      [event, cara],
    );
    expect(offer.rows[0]!.mins).toBe(60);
    expect((await pushes(db)).filter((p) => p.title.startsWith('Platz frei')).map((p) => p.to)).toEqual([cara]);
    // Ben will zurueck: der Platz ist fuer Cara reserviert -> Warteliste
    expect((await as<{ s: string }>(db, ben, `select public.join_event($1) as s`, [event]))[0]!.s).toBe('waitlist');
  });

  it('Angebot läuft ab: Person fällt heraus, die Nächste ist dran', async () => {
    await db.query(`update public.event_participants set offer_expires_at = now() - interval '1 minute' where event_id = $1 and user_id = $2`, [event, cara]);
    await db.exec(`select public.process_events()`);
    expect(await status(cara)).toBeNull();
    expect(await status(dino)).toBe('offered');
    expect(await status(ben)).toBe('waitlist');
    const titles = (await pushes(db)).map((p) => `${p.title}>${p.to}`);
    expect(titles).toContain(`Angebot abgelaufen>${cara}`);
    expect(titles).toContain(`Platz frei: Fussball am Freitag>${dino}`);
  });

  it('Angebot annehmen: "Bin dabei" macht aus dem Angebot eine feste Zusage', async () => {
    expect((await as<{ s: string }>(db, dino, `select public.join_event($1) as s`, [event]))[0]!.s).toBe('going');
    expect(await status(dino)).toBe('going');
    expect(await status(ben)).toBe('waitlist');
  });

  it('mehr Plätze: Wartende bekommen ein Angebot; Platzzahl wird nie überschritten', async () => {
    await as(db, anna, `update public.group_events set max_participants = 3 where id = $1`, [event]);
    expect(await status(ben)).toBe('offered');
    await as(db, ben, `select public.join_event($1)`, [event]);
    const taken = await db.query<{ n: number }>(`select count(*)::int as n from public.event_participants where event_id = $1 and status in ('going','offered')`, [event]);
    expect(taken.rows[0]!.n).toBe(3);
    expect((await as<{ s: string }>(db, cara, `select public.join_event($1) as s`, [event]))[0]!.s).toBe('waitlist');
    await as(db, cara, `select public.leave_event($1)`, [event]);
  });

  it('Bezahlt-Liste: nur Organisator hakt ab; Mitglieder sehen nur den eigenen Status', async () => {
    expect(await errorOf(db, ben, `select public.set_event_paid($1, $2, true)`, [event, ben])).toMatch(/Organisator/);
    await as(db, anna, `select public.set_event_paid($1, $2, true)`, [event, ben]);
    const paid = async (u: string) => (await as<{ id: string }>(db, u, `select public.event_paid_user_ids($1) as id`, [event])).map((r) => r.id);
    expect(await paid(anna)).toEqual([ben]);
    expect(await paid(ben)).toEqual([ben]);
    expect(await paid(dino)).toEqual([]);
    // Die Spalte selbst ist fuer niemanden direkt lesbar
    expect(await errorOf(db, dino, `select paid_at from public.event_participants`)).toMatch(/permission denied/);
  });

  it('Gäste: nur mit gültigem Link, nur für dieses Event, ohne Zugang zur Gruppe', async () => {
    await as(db, anna, `update public.group_events set max_participants = 4 where id = $1`, [event]);
    // Das Kennwort des Links ist nicht direkt lesbar
    expect(await errorOf(db, ben, `select invite_token from public.group_events`)).toMatch(/permission denied/);
    expect(await errorOf(db, ben, `select public.set_event_invite($1, true)`, [event])).toMatch(/Organisator/);
    const token = (await as<{ t: string }>(db, anna, `select public.set_event_invite($1, true) as t`, [event]))[0]!.t;

    expect(await errorOf(db, gast, `select public.join_event_as_guest($1, gen_random_uuid())`, [event])).toMatch(/invite_invalid/);
    const preview = await as<{ title: string; group_name: string }>(db, gast, `select title, group_name from public.get_event_invite($1, $2)`, [event, token]);
    expect(preview[0]).toEqual({ title: 'Fussball am Freitag', group_name: 'Gruppo Bietigheim' });
    expect((await as<{ s: string }>(db, gast, `select public.join_event_as_guest($1, $2) as s`, [event, token]))[0]!.s).toBe('going');

    const mine = await as<{ title: string; group_name: string; is_guest: boolean }>(db, gast, `select title, group_name, is_guest from public.my_events()`);
    expect(mine).toEqual([{ title: 'Fussball am Freitag', group_name: 'Gruppo Bietigheim', is_guest: true }]);
    // Gast sieht das Event und die Teilnehmer, aber weder Gruppe noch Mitglieder noch andere Events
    expect((await as(db, gast, `select id from public.group_events`)).length).toBe(1);
    expect(await as(db, gast, `select id from public.groups`)).toEqual([]);
    expect(await as(db, gast, `select id from public.group_members`)).toEqual([]);
    expect(await errorOf(db, gast, `insert into public.chat_messages (group_id, body) values ($1, 'hi')`, [group])).toMatch(/row-level security/);

    // Link abschalten: weitere Gaeste kommen nicht mehr hinein
    await as(db, anna, `select public.set_event_invite($1, false)`, [event]);
    expect(await errorOf(db, fremd, `select public.join_event_as_guest($1, $2)`, [event, token])).toMatch(/invite_invalid/);
  });

  it('Wer Events anlegen darf, bestimmt die Gruppen-Erstellerin', async () => {
    const create = (u: string) =>
      errorOf(db, u, `insert into public.group_events (group_id, created_by, title, starts_at) values ($1, $2, 'Lauf', now() + interval '2 days')`, [group, u]);
    expect(await create(ben)).toBeNull(); // Standard: alle Mitglieder
    await as(db, anna, `update public.groups set event_creation = 'selected' where id = $1`, [group]);
    expect(await create(ben)).toMatch(/row-level security/);
    expect(await errorOf(db, ben, `select public.set_member_organizer($1, $2, true)`, [group, ben])).toMatch(/Ersteller/);
    await as(db, anna, `select public.set_member_organizer($1, $2, true)`, [group, ben]);
    expect(await create(ben)).toBeNull();
    expect(await create(cara)).toMatch(/row-level security/);
    expect(await create(gast)).toMatch(/row-level security/);
    // Nur Organisator oder Gruppen-Erstellerin duerfen ein Event aendern
    expect((await as(db, cara, `update public.group_events set title = 'gekapert' where id = $1 returning id`, [event])).length).toBe(0);
    expect((await as(db, anna, `update public.group_events set title = 'Fussball am Freitag' where id = $1 returning id`, [event])).length).toBe(1);
  });

  it('Gruppe verlassen: eigene Zusagen entfallen, Gäste bleiben', async () => {
    await as(db, dino, `select public.leave_group($1)`, [group]);
    expect(await status(dino)).toBeNull();
    expect(await status(gast)).toBe('going');
  });

  it('wiederkehrendes Event: nach dem Termin entsteht der nächste, ohne Teilnehmer', async () => {
    const r = await as<{ id: string }>(
      db,
      anna,
      `insert into public.group_events (group_id, created_by, title, starts_at, repeat_weeks) values ($1, $2, 'Wochenlauf', now() + interval '1 day', 1) returning id`,
      [group, anna],
    );
    await as(db, anna, `select public.join_event($1)`, [r[0]!.id]);
    await db.query(`update public.group_events set starts_at = now() - interval '4 hours' where id = $1`, [r[0]!.id]);
    await db.exec(`select public.process_events()`);
    const rows = await db.query<{ days: number; repeat_weeks: number | null; n: number }>(
      `select round(extract(epoch from e.starts_at - now()) / 86400)::int as days, e.repeat_weeks,
              (select count(*)::int from public.event_participants p where p.event_id = e.id) as n
       from public.group_events e where e.title = 'Wochenlauf' order by e.starts_at`,
    );
    expect(rows.rows).toEqual([
      { days: 0, repeat_weeks: null, n: 1 },
      { days: 7, repeat_weeks: 1, n: 0 },
    ]);
    // Ein zweiter Lauf legt nichts doppelt an
    await db.exec(`select public.process_events()`);
    const count = await db.query<{ n: number }>(`select count(*)::int as n from public.group_events where title = 'Wochenlauf'`);
    expect(count.rows[0]!.n).toBe(2);
  });

  it('Erinnerung geht nur an Zusagende und nur einmal', async () => {
    await db.query(`update public.group_events set starts_at = now() + interval '90 minutes' where id = $1`, [event]);
    await db.exec(`select public.process_events(); select public.process_events();`);
    const sent = (await pushes(db)).filter((p) => p.title.startsWith('Gleich geht'));
    expect(sent.map((p) => p.to).sort()).toEqual([anna, ben, gast].sort());
  });

  it('nicht angemeldete Besucher haben keinerlei Zugriff', async () => {
    await db.exec('set role anon');
    try {
      await expect(db.query(`select * from public.group_events`)).rejects.toThrow(/permission denied/);
      await expect(db.query(`select public.join_event($1)`, [event])).rejects.toThrow(/permission denied/);
    } finally {
      await db.exec('reset role');
    }
  });
});
