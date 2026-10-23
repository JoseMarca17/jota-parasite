-- Jota Parasite · Etapa 2
-- Workspaces y tareas aislados por el usuario autenticado.

create table if not exists public.profiles_workspaces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  color_hex bigint not null default 4285284024,
  icon_name text not null default 'school',
  current_streak integer not null default 0 check (current_streak >= 0),
  max_streak integer not null default 0 check (max_streak >= 0),
  last_completed_date date,
  wildcards_available integer not null default 3 check (wildcards_available >= 0),
  frozen_days_mask integer[] not null default array[6, 7]::integer[],
  constraint profiles_workspaces_id_user_id_key unique (id, user_id),
  constraint profiles_workspaces_frozen_days_mask_valid
    check (frozen_days_mask <@ array[1, 2, 3, 4, 5, 6, 7]::integer[])
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  profile_id uuid not null,
  title text not null,
  description text,
  due_date timestamptz not null,
  is_completed boolean not null default false,
  completed_at timestamptz,
  postpone_count integer not null default 0 check (postpone_count >= 0),
  affects_streak boolean not null default true,
  created_at timestamptz not null default now(),
  constraint tasks_profile_user_id_fkey
    foreign key (profile_id, user_id)
    references public.profiles_workspaces (id, user_id)
    on delete cascade
);

create index if not exists profiles_workspaces_user_id_idx
  on public.profiles_workspaces (user_id);

create index if not exists tasks_user_due_date_idx
  on public.tasks (user_id, due_date);

create index if not exists tasks_profile_due_date_idx
  on public.tasks (profile_id, due_date);

alter table public.profiles_workspaces enable row level security;
alter table public.tasks enable row level security;

revoke all on table public.profiles_workspaces from public, anon, authenticated;
revoke all on table public.tasks from public, anon, authenticated;
grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.profiles_workspaces to authenticated;
grant select, insert, update, delete on table public.tasks to authenticated;

drop policy if exists profiles_workspaces_owner_all on public.profiles_workspaces;
create policy profiles_workspaces_owner_all
  on public.profiles_workspaces
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists tasks_owner_select on public.tasks;
create policy tasks_owner_select
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tasks_owner_insert on public.tasks;
create policy tasks_owner_insert
  on public.tasks
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists tasks_owner_update on public.tasks;
create policy tasks_owner_update
  on public.tasks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists tasks_owner_delete on public.tasks;
create policy tasks_owner_delete
  on public.tasks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
