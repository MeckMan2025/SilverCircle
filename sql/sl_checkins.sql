-- Check-ins: every few days the app asks students how things are going, how
-- tutoring has been, and which of their classes they need help in.
-- Mood and tutoring answers are private (the student and administrators).
-- Tutors only see who asked for help in which class, through sl_help_wanted.
create table if not exists public.sl_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.sl_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  mood smallint not null check (mood between 1 and 4),          -- 1 rough … 4 great
  tutoring smallint check (tutoring between 1 and 5),           -- only if they've had sessions
  help_courses text[] not null default '{}',
  note text check (char_length(note) <= 500)
);
create index if not exists sl_checkins_user_time on public.sl_checkins (user_id, created_at desc);

alter table public.sl_checkins enable row level security;
drop policy if exists sl_checkins_insert on public.sl_checkins;
create policy sl_checkins_insert on public.sl_checkins for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists sl_checkins_read on public.sl_checkins;
create policy sl_checkins_read on public.sl_checkins for select to authenticated
  using (user_id = auth.uid() or sl_is_admin());
-- Supabase's default grants are broader; keep only what the app uses.
revoke all on public.sl_checkins from anon, authenticated;
grant select, insert on public.sl_checkins to authenticated;

-- Who wants help, by class: from each student's latest check-in in the last
-- 7 days, so saying "I'm good" next time takes them off the list.
create or replace view public.sl_help_wanted as
 SELECT c.user_id, h.course, c.created_at
   FROM sl_checkins c
     CROSS JOIN LATERAL unnest(c.help_courses) h(course)
  WHERE c.created_at > (now() - interval '7 days')
    AND c.id = (SELECT x.id FROM sl_checkins x WHERE x.user_id = c.user_id ORDER BY x.created_at DESC LIMIT 1)
    AND sl_is_member();
revoke all on public.sl_help_wanted from anon, authenticated;
grant select on public.sl_help_wanted to authenticated;
