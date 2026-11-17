-- StayDesk · Nivel 2 · Esquema base (aprobado en docs/nivel-2-plan.md de staydesk-web)

create type room_status   as enum ('dirty','cleaning','inspected','ready','out_of_order');
create type staff_role    as enum ('manager','front_desk','housekeeper','engineer');
create type task_type     as enum ('checkout','stayover','deep_clean');
create type task_status   as enum ('pending','in_progress','done','inspected');
create type req_category  as enum ('ac','plumbing','electrical','lock','tv_wifi','other');
create type req_priority  as enum ('low','normal','urgent');
create type req_status    as enum ('open','in_progress','closed');

create table room_types (
  code        text primary key check (code ~ '^[A-Z]{4,5}$'),
  name        text not null check (length(name) between 3 and 60),
  accessible  boolean not null default false
);

create table rooms (
  id          uuid primary key default gen_random_uuid(),
  number      text not null unique check (number ~ '^[0-9]{3,4}$'),
  floor       smallint not null check (floor between 1 and 20),
  type_code   text not null references room_types(code) on update cascade,
  status      room_status not null default 'dirty',
  occupied    boolean not null default false,
  notes       text check (length(notes) <= 300),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table staff (
  id          uuid primary key default gen_random_uuid(),
  full_name   text not null check (length(full_name) between 2 and 80),
  role        staff_role not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table housekeeping_tasks (
  id           uuid primary key default gen_random_uuid(),
  room_id      uuid not null references rooms(id) on delete cascade,
  assigned_to  uuid references staff(id) on delete set null,
  inspected_by uuid references staff(id) on delete set null,
  type         task_type not null,
  status       task_status not null default 'pending',
  due_date     date not null default current_date,
  started_at   timestamptz,
  finished_at  timestamptz,
  notes        text check (length(notes) <= 300),
  created_at   timestamptz not null default now(),
  check (finished_at is null or started_at is null or finished_at >= started_at)
);
-- una sola tarea abierta por cuarto y día
create unique index one_open_task_per_room_day on housekeeping_tasks(room_id, due_date)
  where status in ('pending','in_progress');

create table maintenance_requests (
  id           uuid primary key default gen_random_uuid(),
  room_id      uuid not null references rooms(id) on delete cascade,
  reported_by  uuid references staff(id) on delete set null,
  assigned_to  uuid references staff(id) on delete set null,
  category     req_category not null,
  priority     req_priority not null default 'normal',
  status       req_status not null default 'open',
  out_of_order boolean not null default false,
  description  text not null check (length(description) between 3 and 500),
  opened_at    timestamptz not null default now(),
  closed_at    timestamptz,
  check ((status = 'closed') = (closed_at is not null))
);

create index on rooms(status);
create index on rooms(floor);
create index on housekeeping_tasks(due_date, status);
create index on housekeeping_tasks(assigned_to);
create index on housekeeping_tasks(inspected_by);
create index on maintenance_requests(status, priority);
create index on maintenance_requests(room_id);
create index on maintenance_requests(reported_by);
create index on maintenance_requests(assigned_to);

-- ─── Reglas de negocio en la base ───────────────────────────────────────────

-- updated_at automático en rooms
create function touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger rooms_touch before update on rooms
  for each row execute function touch_updated_at();

-- assigned_to de una tarea debe ser camarera activa; inspected_by, manager o camarera
create function check_task_staff() returns trigger
language plpgsql set search_path = '' as $$
declare r public.staff_role; a boolean;
begin
  if new.assigned_to is not null then
    select role, active into r, a from public.staff where id = new.assigned_to;
    if r is distinct from 'housekeeper' or not a then
      raise exception 'La tarea solo se puede asignar a una camarera activa'
        using errcode = 'check_violation';
    end if;
  end if;
  if new.inspected_by is not null then
    select role into r from public.staff where id = new.inspected_by;
    if r not in ('manager','housekeeper') then
      raise exception 'Solo un gerente o camarera puede aprobar la inspección'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;

create trigger housekeeping_tasks_staff before insert or update on housekeeping_tasks
  for each row execute function check_task_staff();

-- assigned_to de una reparación debe ser ingeniero activo
create function check_request_staff() returns trigger
language plpgsql set search_path = '' as $$
declare r public.staff_role; a boolean;
begin
  if new.assigned_to is not null then
    select role, active into r, a from public.staff where id = new.assigned_to;
    if r is distinct from 'engineer' or not a then
      raise exception 'La reparación solo se puede asignar a un ingeniero activo'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;

create trigger maintenance_requests_staff before insert or update on maintenance_requests
  for each row execute function check_request_staff();

-- Tarea in_progress → cuarto cleaning; done → inspected; inspected → ready
create function task_moves_room() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.status = old.status then
    return new;
  end if;
  -- un cuarto fuera de servicio no cambia por limpieza
  update public.rooms set status = case new.status
      when 'in_progress' then 'cleaning'::public.room_status
      when 'done'        then 'inspected'::public.room_status
      when 'inspected'   then 'ready'::public.room_status
    end
  where id = new.room_id
    and status <> 'out_of_order'
    and new.status in ('in_progress','done','inspected');
  return new;
end $$;

create trigger housekeeping_tasks_room after insert or update of status on housekeeping_tasks
  for each row execute function task_moves_room();

-- Reparación abierta con out_of_order → cuarto out_of_order;
-- al cerrar la última que lo sacaba de venta → dirty
create function request_moves_room() returns trigger
language plpgsql set search_path = '' as $$
declare rid uuid;
begin
  rid := coalesce(new.room_id, old.room_id);
  if exists (select 1 from public.maintenance_requests
             where room_id = rid and out_of_order and status <> 'closed') then
    update public.rooms set status = 'out_of_order' where id = rid and status <> 'out_of_order';
  elsif (tg_op <> 'INSERT' and old.out_of_order) or (tg_op <> 'DELETE' and new.out_of_order) then
    -- solo si esta reparación era la que lo sacaba de venta
    update public.rooms set status = 'dirty' where id = rid and status = 'out_of_order';
  end if;
  -- si la reparación cambió de cuarto, revisar también el anterior
  if tg_op = 'UPDATE' and old.room_id <> new.room_id then
    if not exists (select 1 from public.maintenance_requests
                   where room_id = old.room_id and out_of_order and status <> 'closed') then
      update public.rooms set status = 'dirty' where id = old.room_id and status = 'out_of_order';
    end if;
  end if;
  return null;
end $$;

create trigger maintenance_requests_room after insert or update or delete on maintenance_requests
  for each row execute function request_moves_room();

-- ─── Seguridad ──────────────────────────────────────────────────────────────
-- En el Nivel 2 la app consulta desde el servidor con la clave secreta.
-- RLS activo y sin políticas: la clave pública no puede leer ni escribir nada.
alter table room_types           enable row level security;
alter table rooms                enable row level security;
alter table staff                enable row level security;
alter table housekeeping_tasks   enable row level security;
alter table maintenance_requests enable row level security;
