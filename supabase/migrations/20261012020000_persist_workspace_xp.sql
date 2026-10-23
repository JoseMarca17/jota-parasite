-- XP persistente por workspace; cada tarea completada otorga XP una única vez.

alter table public.profiles_workspaces
  add column if not exists xp_total bigint not null default 0
  check (xp_total >= 0);

alter table public.tasks
  add column if not exists xp_awarded_at timestamptz;

-- Las tareas que ya estaban completadas reciben su recompensa inicial.
update public.tasks
set xp_awarded_at = coalesce(completed_at, created_at)
where is_completed = true
  and xp_awarded_at is null;

update public.profiles_workspaces as workspace
set xp_total = coalesce((
  select count(*)::bigint * 100
  from public.tasks as task
  where task.profile_id = workspace.id
    and task.user_id = workspace.user_id
    and task.xp_awarded_at is not null
), 0);

create or replace function public.award_task_xp_once()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $function$
begin
  if new.is_completed and new.xp_awarded_at is null then
    if tg_op = 'INSERT' or old.is_completed = false then
      new.xp_awarded_at := coalesce(new.completed_at, statement_timestamp());

      update public.profiles_workspaces
      set xp_total = xp_total + 100
      where id = new.profile_id
        and user_id = new.user_id;
    end if;
  end if;

  return new;
end;
$function$;

revoke all on function public.award_task_xp_once() from public, anon, authenticated;

drop trigger if exists tasks_award_xp_once on public.tasks;
create trigger tasks_award_xp_once
  before insert or update of is_completed, completed_at
  on public.tasks
  for each row
  execute function public.award_task_xp_once();

-- Los campos calculados de gamificación solo los modifica la base de datos.
-- El esquema remoto existente conserva grants amplios para anon y
-- authenticated; revocarlos explícitamente evita que sobrevivan permisos
-- heredados de la creación manual de las tablas base.
revoke all on table public.profiles_workspaces from public, anon, authenticated;
revoke all on table public.tasks from public, anon, authenticated;

grant select, delete on table public.profiles_workspaces to authenticated;
grant insert (user_id, name, color_hex, icon_name, frozen_days_mask)
  on table public.profiles_workspaces to authenticated;
grant update (name, color_hex, icon_name, frozen_days_mask)
  on table public.profiles_workspaces to authenticated;

grant select, delete on table public.tasks to authenticated;
grant insert (user_id, profile_id, title, description, due_date, affects_streak)
  on table public.tasks to authenticated;
grant update (title, description, due_date, is_completed, completed_at, affects_streak)
  on table public.tasks to authenticated;

create or replace function public.postpone_task(
  p_task_id uuid,
  p_days integer default 1
)
returns setof public.tasks
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  updated_task public.tasks;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_days < 1 or p_days > 365 then
    raise exception 'Postpone days must be between 1 and 365' using errcode = '22023';
  end if;

  update public.tasks
  set due_date = due_date + make_interval(days => p_days),
      postpone_count = postpone_count + 1
  where id = p_task_id
    and user_id = auth.uid()
  returning * into updated_task;

  if not found then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  return next updated_task;
  return;
end;
$function$;

revoke all on function public.postpone_task(uuid, integer) from public, anon, authenticated;
grant execute on function public.postpone_task(uuid, integer) to authenticated;
