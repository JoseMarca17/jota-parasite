-- Jota Parasite · Etapa 4
-- Historial semanal, días congelados y salvamento de racha con comodines.

alter table public.profiles_workspaces
  add column if not exists wildcards_period_start date not null
  default (date_trunc('month', current_date)::date);

-- Las tablas base del proyecto remoto se crearon antes de quedar versionadas
-- y no tienen la clave única compuesta requerida por las FK de este módulo.
-- id ya es PK, por lo que este índice no puede encontrar duplicados de pareja.
create unique index if not exists profiles_workspaces_id_user_id_key
  on public.profiles_workspaces (id, user_id);

-- Reestablece la integridad workspace/usuario que define la migración base.
-- El guard permite aplicar el mismo archivo sobre instalaciones nuevas.
do $migration$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.tasks'::regclass
      and conname = 'tasks_profile_user_id_fkey'
  ) then
    alter table public.tasks
      add constraint tasks_profile_user_id_fkey
      foreign key (profile_id, user_id)
      references public.profiles_workspaces (id, user_id)
      on delete cascade;
  end if;
end;
$migration$;

create table if not exists public.workspace_streak_days (
  user_id uuid not null references auth.users (id) on delete cascade,
  profile_id uuid not null,
  activity_date date not null,
  has_task_completion boolean not null default false,
  wildcard_used boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (profile_id, activity_date),
  constraint workspace_streak_days_profile_user_fkey
    foreign key (profile_id, user_id)
    references public.profiles_workspaces (id, user_id)
    on delete cascade,
  constraint workspace_streak_days_has_activity
    check (has_task_completion or wildcard_used)
);

create index if not exists workspace_streak_days_user_date_idx
  on public.workspace_streak_days (user_id, activity_date);

-- Historial inicial aproximado en UTC; las nuevas entradas usan fecha local del dispositivo.
insert into public.workspace_streak_days (
  user_id,
  profile_id,
  activity_date,
  has_task_completion
)
select
  user_id,
  profile_id,
  (coalesce(completed_at, created_at) at time zone 'UTC')::date,
  true
from public.tasks
where is_completed = true
  and affects_streak = true
group by
  user_id,
  profile_id,
  (coalesce(completed_at, created_at) at time zone 'UTC')::date
on conflict (profile_id, activity_date)
do update set has_task_completion = true;

alter table public.workspace_streak_days enable row level security;
revoke all on table public.workspace_streak_days from public, anon, authenticated;
grant select on table public.workspace_streak_days to authenticated;

drop policy if exists workspace_streak_days_owner_select
  on public.workspace_streak_days;
create policy workspace_streak_days_owner_select
  on public.workspace_streak_days
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.refresh_workspace_wildcards(p_local_today date)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  month_start date := date_trunc('month', p_local_today)::date;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_local_today < current_date - 1 or p_local_today > current_date + 1 then
    raise exception 'Local date is outside the allowed range' using errcode = '22023';
  end if;

  update public.profiles_workspaces
  set wildcards_available = 3,
      wildcards_period_start = month_start
  where user_id = auth.uid()
    and wildcards_period_start < month_start;
end;
$function$;

create or replace function public.record_workspace_completion(
  p_profile_id uuid,
  p_local_date date
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  workspace public.profiles_workspaces%rowtype;
  day_already_recorded boolean;
  missed_open_days integer := 0;
  next_streak integer;
begin
  select *
  into workspace
  from public.profiles_workspaces
  where id = p_profile_id
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Workspace not found' using errcode = 'P0002';
  end if;

  select exists (
    select 1
    from public.workspace_streak_days
    where profile_id = p_profile_id
      and activity_date = p_local_date
  ) into day_already_recorded;

  insert into public.workspace_streak_days (
    user_id,
    profile_id,
    activity_date,
    has_task_completion
  ) values (
    auth.uid(),
    p_profile_id,
    p_local_date,
    true
  )
  on conflict (profile_id, activity_date)
  do update set has_task_completion = true;

  if p_local_date between current_date - 1 and current_date + 1
     and extract(isodow from p_local_date)::integer = any(workspace.frozen_days_mask) then
    return;
  end if;

  if day_already_recorded or
     (workspace.last_completed_date is not null
      and p_local_date <= workspace.last_completed_date) then
    return;
  end if;

  if p_local_date < current_date - 1 or p_local_date > current_date + 1 then
    raise exception 'Local date is outside the allowed range' using errcode = '22023';
  end if;

  if workspace.last_completed_date is null then
    next_streak := 1;
  else
    select count(*)::integer
    into missed_open_days
    from generate_series(
      workspace.last_completed_date + 1,
      p_local_date - 1,
      interval '1 day'
    ) as generated(day)
    where extract(isodow from generated.day)::integer <> all(workspace.frozen_days_mask)
      and not exists (
        select 1
        from public.workspace_streak_days as activity
        where activity.profile_id = p_profile_id
          and activity.activity_date = generated.day::date
          and (activity.has_task_completion or activity.wildcard_used)
      );

    next_streak := case
      when missed_open_days = 0 then greatest(workspace.current_streak, 0) + 1
      else 1
    end;
  end if;

  update public.profiles_workspaces
  set current_streak = next_streak,
      max_streak = greatest(max_streak, next_streak),
      last_completed_date = p_local_date
  where id = p_profile_id
    and user_id = auth.uid();
end;
$function$;

create or replace function public.set_task_completion(
  p_task_id uuid,
  p_is_completed boolean,
  p_local_date date
)
returns setof public.tasks
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  task_row public.tasks%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into task_row
  from public.tasks
  where id = p_task_id
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if p_local_date < current_date - 1 or p_local_date > current_date + 1 then
    raise exception 'Local date is outside the allowed range' using errcode = '22023';
  end if;

  update public.tasks
  set is_completed = p_is_completed,
      completed_at = case
        when p_is_completed then coalesce(task_row.completed_at, statement_timestamp())
        else null
      end
  where id = p_task_id
    and user_id = auth.uid();

  if p_is_completed and task_row.affects_streak then
    perform public.record_workspace_completion(task_row.profile_id, p_local_date);
  end if;

  return query
  select *
  from public.tasks
  where id = p_task_id
    and user_id = auth.uid();
end;
$function$;

create or replace function public.save_workspace_streak(
  p_profile_id uuid,
  p_local_today date
)
returns setof public.profiles_workspaces
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  workspace public.profiles_workspaces%rowtype;
  month_start date := date_trunc('month', p_local_today)::date;
  missing_open_days integer := 0;
  target_day date;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_local_today < current_date - 1 or p_local_today > current_date + 1 then
    raise exception 'Local date is outside the allowed range' using errcode = '22023';
  end if;

  select *
  into workspace
  from public.profiles_workspaces
  where id = p_profile_id
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Workspace not found' using errcode = 'P0002';
  end if;

  if workspace.wildcards_period_start < month_start then
    workspace.wildcards_available := 3;
    workspace.wildcards_period_start := month_start;
  end if;

  if workspace.current_streak <= 0 or workspace.last_completed_date is null then
    raise exception 'No active streak to save' using errcode = '22023';
  end if;

  if workspace.wildcards_available <= 0 then
    raise exception 'No anti-shame shields left this month' using errcode = '22023';
  end if;

  if p_local_today <= workspace.last_completed_date then
    raise exception 'The streak has no missed day to save' using errcode = '22023';
  end if;

  select count(*)::integer, min(generated.day::date)
  into missing_open_days, target_day
  from generate_series(
    workspace.last_completed_date + 1,
    p_local_today - 1,
    interval '1 day'
  ) as generated(day)
  where extract(isodow from generated.day)::integer <> all(workspace.frozen_days_mask)
    and not exists (
      select 1
      from public.workspace_streak_days as activity
      where activity.profile_id = p_profile_id
        and activity.activity_date = generated.day::date
        and (activity.has_task_completion or activity.wildcard_used)
    );

  if missing_open_days > 1 then
    raise exception 'One wildcard can only cover one missed work day' using errcode = '22023';
  elsif missing_open_days = 0 then
    if extract(isodow from p_local_today)::integer = any(workspace.frozen_days_mask)
       or exists (
         select 1
         from public.workspace_streak_days
         where profile_id = p_profile_id
           and activity_date = p_local_today
           and (has_task_completion or wildcard_used)
       ) then
      raise exception 'There is no eligible day to save' using errcode = '22023';
    end if;
    target_day := p_local_today;
  end if;

  insert into public.workspace_streak_days (
    user_id,
    profile_id,
    activity_date,
    wildcard_used
  ) values (
    auth.uid(),
    p_profile_id,
    target_day,
    true
  )
  on conflict (profile_id, activity_date)
  do update set wildcard_used = true;

  update public.profiles_workspaces
  set current_streak = current_streak + 1,
      max_streak = greatest(max_streak, current_streak + 1),
      last_completed_date = target_day,
      wildcards_available = workspace.wildcards_available - 1,
      wildcards_period_start = month_start
  where id = p_profile_id
    and user_id = auth.uid();

  return query
  select *
  from public.profiles_workspaces
  where id = p_profile_id
    and user_id = auth.uid();
end;
$function$;

revoke all on function public.refresh_workspace_wildcards(date)
  from public, anon, authenticated;
revoke all on function public.record_workspace_completion(uuid, date)
  from public, anon, authenticated;
revoke all on function public.set_task_completion(uuid, boolean, date)
  from public, anon, authenticated;
revoke all on function public.save_workspace_streak(uuid, date)
  from public, anon, authenticated;

grant execute on function public.refresh_workspace_wildcards(date) to authenticated;
grant execute on function public.set_task_completion(uuid, boolean, date) to authenticated;
grant execute on function public.save_workspace_streak(uuid, date) to authenticated;

-- Todas las finalizaciones pasan por la función que registra la fecha local.
revoke update (is_completed, completed_at)
  on table public.tasks from authenticated;
