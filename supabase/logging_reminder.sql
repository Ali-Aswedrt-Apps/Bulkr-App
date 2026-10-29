-- The one notification that is about the app rather than about other people.
--
-- Prerequisites: `tracker_schema.sql`, `notifications.sql`, `push_devices.sql`,
-- `streak_restore.sql` (for `logging_streak`), `challenge_notifications.sql`
-- (for `notify_system`), `maintenance_cron.sql` (for pg_cron). Re-runnable.
--
-- Run this in the Supabase SQL editor (Dashboard -> SQL Editor -> New query).
--
-- ---------------------------------------------------------------------------
-- Why this is the one worth building
-- ---------------------------------------------------------------------------
-- Bulkr is a daily-logging app that never asks anybody to log. Every
-- notification it sends is social — somebody followed you, somebody joined
-- your challenge — and none of them is about the thing the app is for. A
-- person who forgets for two days has a broken streak and no idea, and the
-- first they hear of it is opening the app and finding the number gone.
--
-- The whole push apparatus already existed for the social events. This is the
-- one that pays for it.
--
-- ---------------------------------------------------------------------------
-- The rules, and what each is protecting
-- ---------------------------------------------------------------------------
-- A reminder is the notification most able to make somebody turn notifications
-- off, and the ones that do it are never the first — they are the one that
-- arrives at 3am, or the fourth in a week to somebody who already stopped
-- using the app. So:
--
--   * **Their evening, not ours.** Fired at 20:00 in the user's own offset.
--     A "log your food" at breakfast is asking about a day that has not
--     happened.
--   * **Only if they have not logged.** The entire point. Somebody who logged
--     at noon must never be told they have not.
--   * **Only if they were here recently.** An account that has not logged in
--     three weeks has stopped using the app, and a nightly buzz is not how
--     that gets reversed — it is how it gets uninstalled.
--   * **One at a time, ever.** See `notify_reminder` below.
--   * **Only if there is a device to send to.** No row for somebody who would
--     never see it.

-- ---------------------------------------------------------------------------
-- 1. Where the user's evening is
-- ---------------------------------------------------------------------------
-- An offset in minutes, not an IANA zone name. The app rewrites it on every
-- launch, so a device that moves country or crosses a daylight-saving boundary
-- corrects itself the next time it is opened — which is the failure a stored
-- zone name would handle more elegantly and which this handles well enough,
-- without a timezone database or a package to read one.
--
-- Minutes rather than hours because +05:30, +05:45 and +03:30 are real places
-- with real people in them.
--
-- Null means never launched a build that writes it: those accounts are skipped
-- rather than reminded at an hour picked for somebody else.

alter table public.users
  add column if not exists utc_offset_minutes integer;

comment on column public.users.utc_offset_minutes is
  'Device UTC offset in minutes, rewritten on each app launch. Null = unknown; '
  'the logging reminder skips those rather than guessing.';

-- ---------------------------------------------------------------------------
-- 2. The kind
-- ---------------------------------------------------------------------------
alter table public.notifications
  drop constraint if exists notifications_kind_check;

alter table public.notifications
  add constraint notifications_kind_check
    check (kind in (
      'follow', 'like', 'comment', 'reply',
      'challenge_joined', 'challenge_starting', 'challenge_ending',
      'challenge_ended', 'challenge_passed',
      -- Nothing has been logged today, and the evening is running out.
      'log_reminder'
    ));

-- ---------------------------------------------------------------------------
-- 3. One at a time, ever
-- ---------------------------------------------------------------------------
-- `notify_system` inserts `on conflict do nothing`, and the unique index is
-- (user_id, actor_id, kind, post_id, comment_id). A reminder has no actor, no
-- post and no comment — so every reminder to one person collides with every
-- other, and the second night's would be silently dropped forever.
--
-- That is the correct behaviour for "your challenge is ending", which happens
-- once. It is exactly wrong here, where the whole point is that it happens
-- again tomorrow.
--
-- So the previous one is deleted first. Which also fixes the other half: the
-- bell list is an activity feed, and a row per night would bury the follows
-- and comments under a month of reminders nobody needs to read twice.

create or replace function public.notify_reminder(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.notifications
   where user_id = p_user and kind = 'log_reminder';

  insert into public.notifications (user_id, actor_id, kind)
  values (p_user, null, 'log_reminder');
end;
$$;

revoke all on function public.notify_reminder(uuid) from public;
grant execute on function public.notify_reminder(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Somebody else's streak
-- ---------------------------------------------------------------------------
-- `logging_streak()` answers for `auth.uid()`, which is right for the app and
-- useless to a sweep running as the service role on everyone's behalf. This is
-- the same query taking the user as an argument, and `logging_streak()` is
-- redefined to delegate so the two cannot drift — a reminder quoting a
-- different number from the one on the tracker is worse than a reminder
-- quoting none.
--
-- SECURITY DEFINER because it reads another user's `daily_logs`, which no
-- policy allows. It returns a count, never a row.

create or replace function public.logging_streak_for(uid uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with days as (
    select distinct log_date
      from public.daily_logs
     where user_id = uid
       and log_date <= current_date
       and log_date > current_date - 730
    union
    select log_date
      from public.streak_restores
     where user_id = uid
       and log_date <= current_date
       and log_date > current_date - 730
  ),
  runs as (
    select log_date,
           log_date - (row_number() over (order by log_date))::integer as run
      from days
  ),
  latest as (
    select max(log_date) as last_day, count(*)::integer as length
      from runs
     group by run
     order by last_day desc
     limit 1
  )
  select coalesce(
    (select length from latest where last_day >= current_date - 1),
    0
  );
$$;

revoke all on function public.logging_streak_for(uuid) from public;
grant execute on function public.logging_streak_for(uuid) to service_role;

create or replace function public.logging_streak()
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$ select public.logging_streak_for(auth.uid()) $$;

revoke all on function public.logging_streak() from public;
grant execute on function public.logging_streak() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. The sweep
-- ---------------------------------------------------------------------------
-- Hourly, because 20:00 local is a different hour of UTC for every offset —
-- so each run picks out the band of the world for which it is now evening.
--
-- `local_now` is the user's wall clock. The day compared against `log_date` is
-- their local date too, which is the same calendar the app writes with (see
-- `MealSlot`, where a day starts at 04:00) — so "has not logged today" means
-- the same thing at both ends.

create or replace function public.logging_reminder_sweep()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  due record;
  sent integer := 0;
begin
  for due in
    select u.id
      from public.users u
     where u.utc_offset_minutes is not null
       -- Their evening. One hour wide, and the sweep runs hourly, so each
       -- account matches exactly one run a day.
       and extract(hour from (now() + make_interval(mins => u.utc_offset_minutes))) = 20
       -- Somebody to send it to.
       and exists (
         select 1 from public.device_tokens d where d.user_id = u.id
       )
       -- Nothing logged on their today.
       and not exists (
         select 1 from public.daily_logs l
          where l.user_id = u.id
            and l.log_date = (now() + make_interval(mins => u.utc_offset_minutes))::date
       )
       -- But they were here recently. Nagging an account that stopped three
       -- weeks ago is how an app gets its notifications turned off.
       and exists (
         select 1 from public.daily_logs l
          where l.user_id = u.id
            and l.log_date > (now() + make_interval(mins => u.utc_offset_minutes))::date - 7
       )
  loop
    perform public.notify_reminder(due.id);
    sent := sent + 1;
  end loop;

  return sent;
end;
$$;

revoke all on function public.logging_reminder_sweep() from public;
grant execute on function public.logging_reminder_sweep() to service_role;

-- ---------------------------------------------------------------------------
-- 6. The words
-- ---------------------------------------------------------------------------
-- The streak is the whole reason this is worth sending. "You have not logged
-- today" is a chore; "your 12-day streak ends at midnight" is a thing somebody
-- gets off the sofa for — and it is true, which is what separates it from the
-- notifications people learn to ignore.
--
-- Replaced whole, for the reason given in `challenge_notifications.sql`: a
-- kind added without its copy pushes as "New activity", and splitting the two
-- across files is how that happens.

create or replace function public.push_payload(p_notification uuid)
returns table (
  token text,
  platform text,
  title text,
  body text
)
language sql
security definer
set search_path = public
as $$
  select
    d.token,
    d.platform,
    'Bulkr' as title,
    case n.kind
      when 'follow'  then coalesce(a.display_name, a.username, 'Someone')
                          || ' followed you'
      when 'like'    then coalesce(a.display_name, a.username, 'Someone')
                          || ' liked your post'
      when 'comment' then coalesce(a.display_name, a.username, 'Someone')
                          || ' commented on your post'
      when 'reply'   then coalesce(a.display_name, a.username, 'Someone')
                          || ' replied to you'
      when 'challenge_joined' then
        coalesce(a.display_name, a.username, 'Someone')
        || ' joined ' || coalesce(ch.title, 'your challenge')
      when 'challenge_starting' then
        coalesce(ch.title, 'Your challenge') || ' starts tomorrow'
      when 'challenge_ending' then
        'One day left in ' || coalesce(ch.title, 'your challenge')
      when 'challenge_ended' then
        coalesce(ch.title, 'Your challenge') || ' has finished'
      when 'challenge_passed' then
        coalesce(a.display_name, a.username, 'Someone')
        || ' just went past you in ' || coalesce(ch.title, 'a challenge')
      when 'log_reminder' then
        case
          when public.logging_streak_for(n.user_id) > 1 then
            'Your ' || public.logging_streak_for(n.user_id)
            || '-day streak ends at midnight'
          else 'You have not logged anything today'
        end
      else 'New activity'
    end as body
  from public.notifications n
  join public.device_tokens d on d.user_id = n.user_id
  left join public.users a on a.id = n.actor_id
  left join public.challenges ch on ch.post_id = n.post_id
  left join public.post_comments c on c.id = n.comment_id
  where n.id = p_notification
    and n.read_at is null;
$$;

revoke execute on function public.push_payload(uuid) from public;
revoke execute on function public.push_payload(uuid) from authenticated;
grant execute on function public.push_payload(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 7. The schedule
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema extensions;

do $$
begin
  if to_regprocedure('public.logging_reminder_sweep()') is null then
    raise notice
      'Bulkr: public.logging_reminder_sweep() not found. Nothing scheduled.';
    return;
  end if;

  perform cron.unschedule('logging-reminder-sweep')
    where exists (
      select 1 from cron.job where jobname = 'logging-reminder-sweep'
    );

  -- On the hour, every hour. Each run is one timezone band's evening.
  perform cron.schedule(
    'logging-reminder-sweep',
    '0 * * * *',
    $cron$ select public.logging_reminder_sweep() $cron$
  );

  raise notice 'Bulkr: logging reminder scheduled hourly.';
end;
$$;

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------
-- Who the next run would reach, without sending anything:
--
--   select u.id, u.username, u.utc_offset_minutes,
--          (now() + make_interval(mins => u.utc_offset_minutes)) as their_time
--     from public.users u
--    where u.utc_offset_minutes is not null;
--
-- Force one to yourself, whatever the hour — it is safe, it replaces any
-- reminder you already had rather than adding one:
--
--   select public.notify_reminder(auth.uid());
--   select body from public.push_payload(
--     (select id from public.notifications
--       where user_id = auth.uid() and kind = 'log_reminder'));
--
-- Expect your real streak in the sentence. Zero rows means no device token
-- registered, or you have already read it.
--
--   select public.logging_reminder_sweep();
--
-- Returns how many were sent. Zero at most hours of the day is correct.
