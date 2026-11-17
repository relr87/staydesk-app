-- StayDesk Demo Inn · datos de ejemplo INVENTADOS (ningún huésped ni empleado real)
-- 7 tipos · 173 habitaciones · 20 personas · ~60 tareas · 25 reparaciones
-- Se puede correr varias veces: borra y vuelve a llenar.

begin;

truncate maintenance_requests, housekeeping_tasks, rooms, staff, room_types restart identity cascade;

insert into room_types (code, name, accessible) values
  ('KING',  'King estándar',           false),
  ('DBLQ',  'Doble queen',             false),
  ('KADA',  'King accesible',          true),
  ('DQADA', 'Doble queen accesible',   true),
  ('KSTE',  'Suite king',              false),
  ('STUD',  'Estudio con cocineta',    false),
  ('PENT',  'Penthouse',               false);

-- 173 habitaciones: pisos 1-5 con 25, pisos 6-7 con 24
insert into rooms (number, floor, type_code, status, occupied)
select
  (f * 100 + n)::text,
  f,
  case
    when f = 7 and n <= 4           then 'PENT'
    when n in (1, 2)                then case when n = 1 then 'KADA' else 'DQADA' end
    when n % 10 = 0                 then 'KSTE'
    when n % 7 = 0                  then 'STUD'
    when n % 2 = 0                  then 'DBLQ'
    else 'KING'
  end,
  (array['dirty','cleaning','inspected','ready','ready','ready'])[1 + ((f * 7 + n * 3) % 6)]::room_status,
  ((f + n) % 3) <> 0
from generate_series(1, 7) f
cross join lateral generate_series(1, case when f <= 5 then 25 else 24 end) n;

insert into staff (full_name, role, active) values
  ('Marisol Quintero',  'manager',     true),
  ('Teodoro Vallejo',   'manager',     true),
  ('Lucía Arredondo',   'front_desk',  true),
  ('Bruno Castañeda',   'front_desk',  true),
  ('Inés Robledo',      'front_desk',  true),
  ('Rosa Elvira Peña',  'housekeeper', true),
  ('Daniela Ocampo',    'housekeeper', true),
  ('Yesenia Barragán',  'housekeeper', true),
  ('Gloria Montalvo',   'housekeeper', true),
  ('Paola Rentería',    'housekeeper', true),
  ('Carmen Solís Ruiz', 'housekeeper', true),
  ('Adela Fuentevilla', 'housekeeper', true),
  ('Noemí Carrasco',    'housekeeper', true),
  ('Fabiola Esquivel',  'housekeeper', false),
  ('Hernán Lozoya',     'engineer',    true),
  ('Ramiro Betancourt', 'engineer',    true),
  ('Óscar Villaseñor',  'engineer',    true),
  ('Julián Mendívil',   'engineer',    false),
  ('Sofía Larrañaga',   'front_desk',  true),
  ('Ernesto Galván',    'manager',     true);

-- 60 tareas de limpieza en los últimos 3 días y hoy
with hk as (
  select id, row_number() over (order by full_name) rn
  from staff where role = 'housekeeper' and active
), mgr as (
  select id from staff where role = 'manager' order by full_name limit 1
), pick as (
  select r.id room_id, row_number() over (order by r.number) i
  from rooms r
  where r.number::int % 3 = 0
  limit 60
)
insert into housekeeping_tasks (room_id, assigned_to, inspected_by, type, status, due_date, started_at, finished_at, notes)
select
  p.room_id,
  (select id from hk where rn = 1 + (p.i % 8)),
  case when st = 'inspected' then (select id from mgr) end,
  (array['checkout','stayover','stayover','deep_clean'])[1 + (p.i % 4)]::task_type,
  st,
  current_date - d,
  case when st <> 'pending' then (current_date - d) + time '09:00' + (p.i % 60) * interval '1 minute' end,
  case when st in ('done','inspected') then (current_date - d) + time '10:00' + (p.i % 50) * interval '1 minute' end,
  case when p.i % 9 = 0 then 'Huésped pidió toallas extra' when p.i % 13 = 0 then 'Revisar mancha en alfombra' end
from pick p
cross join lateral (select (p.i % 4)::int as d) dd
cross join lateral (
  select case
    when d > 0 then (array['done','inspected','inspected'])[1 + (p.i % 3)]
    else (array['pending','pending','in_progress','done','inspected'])[1 + (p.i % 5)]
  end::task_status as st
) s;

-- 25 reparaciones
with eng as (
  select id, row_number() over (order by full_name) rn from staff where role = 'engineer' and active
), rep as (
  select id, row_number() over (order by full_name) rn from staff where role in ('front_desk','housekeeper') and active
), pick as (
  select r.id room_id, row_number() over (order by r.number) i
  from rooms r where r.number::int % 7 = 1
  limit 25
)
insert into maintenance_requests (room_id, reported_by, assigned_to, category, priority, status, out_of_order, description, opened_at, closed_at)
select
  p.room_id,
  (select id from rep where rn = 1 + (p.i % 10)),
  case when st <> 'open' then (select id from eng where rn = 1 + (p.i % 3)) end,
  (array['ac','plumbing','electrical','lock','tv_wifi','other'])[1 + (p.i % 6)]::req_category,
  (array['low','normal','normal','urgent'])[1 + (p.i % 4)]::req_priority,
  st,
  p.i % 5 = 0,
  (array[
    'El aire acondicionado no enfría',
    'Fuga en el lavabo del baño',
    'Contacto junto al buró sin corriente',
    'La chapa electrónica no lee la tarjeta',
    'El televisor no se conecta al wifi',
    'Cortina rota en la ventana principal'
  ])[1 + (p.i % 6)],
  now() - (p.i % 6) * interval '1 day' - interval '3 hours',
  case when st = 'closed' then now() - (p.i % 6) * interval '1 day' - interval '1 hour' end
from pick p
cross join lateral (
  select (array['open','in_progress','closed','closed'])[1 + (p.i % 4)]::req_status as st
) s;

commit;
