-- How tutors want to be paid, and what each request was booked as.
-- Tutor: 'hours' (service hours), 'money', or 'both'. Empty means they signed
-- up before this was asked; the app treats that as service hours.
alter table public.sl_profiles
  add column if not exists tutor_pay_pref text
  check (tutor_pay_pref in ('hours','money','both'));

-- Request: the one the student picked from what the tutor accepts.
alter table public.sl_requests
  add column if not exists pay_type text
  check (pay_type in ('hours','money'));
grant insert (pay_type), update (pay_type) on public.sl_requests to authenticated;

-- Students read tutors through this view, so it carries the preference too.
-- Same columns as before, with tutor_pay_pref added at the end.
create or replace view public.sl_tutors as
 SELECT c.user_id,
    p.tutor_alias,
    p.grade_level,
    p.tutor_bio,
    p.tutor_format,
    c.course,
    c.grade,
    c.year,
    c.availability,
    ( SELECT count(*) AS count
           FROM sl_requests r
          WHERE r.tutor_id = c.user_id AND r.status = 'done'::text) AS sessions_done,
    (EXISTS ( SELECT 1
           FROM sl_grades g
          WHERE g.user_id = c.user_id AND g.course = c.course AND g.status = 'verified'::text)) AS verified,
    p.last_seen_at,
    p.tutor_pay_pref
   FROM sl_tutor_courses c
     JOIN sl_profiles p ON p.id = c.user_id
  WHERE p.tutor_alias IS NOT NULL AND sl_is_member();
