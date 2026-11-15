-- ==========================================================================
-- Korrektur zu 0017: Melden schlug mit "infinite recursion" fehl.
--
-- Ursache: Die Melde-Regel schaut in die Nachrichten (darf ich die Nachricht
-- sehen?), und die Nachrichten-Regel schaute zurueck in die Meldungen (habe
-- ich sie gemeldet?). Postgres verbietet solche Kreis-Bezuege zwischen Regeln.
-- Loesung: Die Frage "habe ich diese Nachricht gemeldet?" beantwortet jetzt
-- eine kleine Hilfsfunktion - damit ist der Kreis unterbrochen.
-- ==========================================================================

create or replace function public.has_reported_message(p_message_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $BODY$
  select exists (
    select 1 from public.reports r
    where r.reporter_id = auth.uid() and r.reported_message_id = p_message_id
  );
$BODY$;

revoke all on function public.has_reported_message(uuid) from public, anon;
grant execute on function public.has_reported_message(uuid) to authenticated;

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
    and not public.has_reported_message(id)
  );

notify pgrst, 'reload schema';
