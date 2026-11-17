-- StayDesk · Nivel 2: tablas relacionadas y validación en el servidor
--
-- La app sigue sincronizando «fichas» (sd_entities) como siempre. Desde esta migración, cada ficha de
-- habitación (rm:), ticket de mantenimiento (tk:) y llegada (ar:) se copia a tablas de verdad, con tipos,
-- llaves foráneas y restricciones. Si una ficha no cumple esas reglas, el servidor la RECHAZA (no se guarda
-- ni llega a los otros equipos) aunque alguien se haya saltado la validación del navegador.
--
--   sd_hotels 1─* room_types 1─* rooms 1─* maintenance_tickets
--                     │            └──* arrivals (habitación asignada, opcional)
--                     └──* arrivals (tipo reservado)

-- ─── tablas ─────────────────────────────────────────────────────────────────

create table public.room_types (
  hotel_id  uuid not null references public.sd_hotels(id) on delete cascade,
  code      text not null check (code ~ '^[A-Z0-9]{2,8}$'),
  bed       char(1) not null check (bed in ('K', 'Q')),            -- K = una King · Q = dos Queen
  primary key (hotel_id, code)
);

create table public.rooms (
  hotel_id    uuid not null references public.sd_hotels(id) on delete cascade,
  number      integer not null check (number between 1 and 99999),
  floor       smallint not null check (floor between 0 and 200),
  type_code   text not null,
  status      text not null check (status in ('limpia', 'sucia', 'ocupada', 'inspeccion', 'mant')),
  guest       text not null default '' check (length(guest) <= 80),
  priority    boolean not null default false,
  departure   boolean not null default false,
  updated_at  timestamptz not null default now(),
  primary key (hotel_id, number),
  foreign key (hotel_id, type_code) references public.room_types(hotel_id, code) on update cascade
);

create table public.maintenance_tickets (
  hotel_id      uuid not null references public.sd_hotels(id) on delete cascade,
  id            integer not null check (id > 0),
  room_number   integer not null,
  issue         text not null check (issue in ('Aire acondicionado', 'Plomería / fuga', 'Cerradura / llave',
                                               'TV / WiFi', 'Luz / eléctrico', 'Otro')),
  out_of_order  boolean not null default false,
  state         text not null check (state in ('abierto', 'curso', 'resuelto')),
  detail        text not null default '' check (length(detail) <= 500),
  due_min       integer check (due_min between -525600 and 525600),   -- minuto del día prometido
  updated_at    timestamptz not null default now(),
  primary key (hotel_id, id),
  foreign key (hotel_id, room_number) references public.rooms(hotel_id, number) on delete cascade
);

create table public.arrivals (
  hotel_id      uuid not null references public.sd_hotels(id) on delete cascade,
  id            integer not null check (id > 0),
  guest_name    text not null check (length(trim(guest_name)) between 1 and 80),
  nights        smallint not null check (nights between 1 and 365),
  adults        smallint check (adults between 0 and 20),
  eta           text check (eta ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  type_code     text not null,
  room_number   integer,
  confirmation  text check (length(confirmation) <= 40),
  done          boolean not null default false,
  updated_at    timestamptz not null default now(),
  primary key (hotel_id, id),
  foreign key (hotel_id, type_code)   references public.room_types(hotel_id, code),
  foreign key (hotel_id, room_number) references public.rooms(hotel_id, number) on delete set null
);

create index rooms_status        on public.rooms (hotel_id, status);
create index rooms_floor         on public.rooms (hotel_id, floor);
create index rooms_type          on public.rooms (hotel_id, type_code);
create index tickets_room        on public.maintenance_tickets (hotel_id, room_number);
create index tickets_state       on public.maintenance_tickets (hotel_id, state);
create index arrivals_type       on public.arrivals (hotel_id, type_code);
create index arrivals_room       on public.arrivals (hotel_id, room_number);

alter table public.room_types          enable row level security;
alter table public.rooms               enable row level security;
alter table public.maintenance_tickets enable row level security;
alter table public.arrivals            enable row level security;

-- ─── de ficha a tabla (con validación) ──────────────────────────────────────

create or replace function public.sd_bad(p_msg text) returns void
language plpgsql immutable set search_path to '' as $$
begin
  raise exception '%', p_msg using errcode = 'check_violation';
end $$;

-- lee un número entero de la ficha; si no es un entero, la ficha se rechaza
create or replace function public.sd_int(p_d jsonb, p_f text, p_req boolean default true) returns integer
language plpgsql immutable set search_path to '' as $$
declare v jsonb := p_d -> p_f;
begin
  if v is null or jsonb_typeof(v) = 'null' then
    if p_req then perform public.sd_bad(format('falta el campo «%s»', p_f)); end if;
    return null;
  end if;
  if jsonb_typeof(v) <> 'number' or (v #>> '{}') !~ '^-?[0-9]+$' then
    perform public.sd_bad(format('«%s» debe ser un número entero', p_f));
  end if;
  return (v #>> '{}')::integer;
end $$;

create or replace function public.sd_txt(p_d jsonb, p_f text) returns text
language plpgsql immutable set search_path to '' as $$
declare v jsonb := p_d -> p_f;
begin
  if v is null or jsonb_typeof(v) = 'null' then return null; end if;
  if jsonb_typeof(v) <> 'string' then perform public.sd_bad(format('«%s» debe ser texto', p_f)); end if;
  return v #>> '{}';
end $$;

create or replace function public.sd_bool(p_d jsonb, p_f text) returns boolean
language sql immutable set search_path to '' as $$
  select coalesce(case when jsonb_typeof(p_d -> p_f) = 'boolean' then (p_d ->> p_f)::boolean end, false)
$$;

create or replace function public.sd_project() returns trigger
language plpgsql security definer set search_path to '' as $$
declare
  pre text := split_part(new.key, ':', 1);
  kid text := split_part(new.key, ':', 2);
  d   jsonb := new.data;
  n   integer; t text;
begin
  if pre not in ('rm', 'tk', 'ar') then return null; end if;
  if kid !~ '^[0-9]{1,9}$' then perform public.sd_bad('clave de ficha inválida: ' || new.key); end if;
  n := kid::integer;

  if new.deleted or d is null then
    if pre = 'rm' then delete from public.rooms where hotel_id = new.hotel_id and number = n;
    elsif pre = 'tk' then delete from public.maintenance_tickets where hotel_id = new.hotel_id and id = n;
    else delete from public.arrivals where hotel_id = new.hotel_id and id = n; end if;
    return null;
  end if;
  if jsonb_typeof(d) <> 'object' then perform public.sd_bad('la ficha debe ser un objeto'); end if;
  if public.sd_int(d, 'id') <> n then perform public.sd_bad(format('la ficha %s trae otro número (%s)', new.key, d ->> 'id')); end if;

  if pre = 'rm' then
    t := public.sd_txt(d, 'type');
    if t is null or t !~ '^[A-Z0-9]{2,8}$' then perform public.sd_bad(format('habitación %s: tipo «%s» inválido', n, t)); end if;
    insert into public.room_types (hotel_id, code, bed)
         values (new.hotel_id, t, case when t ~ '^N?K' then 'K' else 'Q' end)
    on conflict do nothing;
    insert into public.rooms (hotel_id, number, floor, type_code, status, guest, priority, departure, updated_at)
         values (new.hotel_id, n, public.sd_int(d, 'f'), t, public.sd_txt(d, 'status'),
                 coalesce(public.sd_txt(d, 'guest'), ''), public.sd_bool(d, 'prio'), public.sd_bool(d, 'dep'), now())
    on conflict (hotel_id, number) do update
      set floor = excluded.floor, type_code = excluded.type_code, status = excluded.status, guest = excluded.guest,
          priority = excluded.priority, departure = excluded.departure, updated_at = excluded.updated_at;

  elsif pre = 'tk' then
    insert into public.maintenance_tickets (hotel_id, id, room_number, issue, out_of_order, state, detail, due_min, updated_at)
         values (new.hotel_id, n, public.sd_int(d, 'room'), public.sd_txt(d, 'issue'), public.sd_bool(d, 'oos'),
                 public.sd_txt(d, 'state'), coalesce(public.sd_txt(d, 'det'), ''), public.sd_int(d, 'due', false), now())
    on conflict (hotel_id, id) do update
      set room_number = excluded.room_number, issue = excluded.issue, out_of_order = excluded.out_of_order,
          state = excluded.state, detail = excluded.detail, due_min = excluded.due_min, updated_at = excluded.updated_at;

  else
    insert into public.arrivals (hotel_id, id, guest_name, nights, adults, eta, type_code, room_number, confirmation, done, updated_at)
         values (new.hotel_id, n, public.sd_txt(d, 'n'), public.sd_int(d, 'noches'), public.sd_int(d, 'adults', false),
                 nullif(public.sd_txt(d, 'hora'), ''), public.sd_txt(d, 'type'), public.sd_int(d, 'room', false),
                 nullif(public.sd_txt(d, 'conf'), ''), public.sd_bool(d, 'done'), now())
    on conflict (hotel_id, id) do update
      set guest_name = excluded.guest_name, nights = excluded.nights, adults = excluded.adults, eta = excluded.eta,
          type_code = excluded.type_code, room_number = excluded.room_number, confirmation = excluded.confirmation,
          done = excluded.done, updated_at = excluded.updated_at;
  end if;
  return null;
end $$;

create trigger sd_entities_project
  after insert or update on public.sd_entities
  for each row execute function public.sd_project();

-- ─── sd_push: una ficha rechazada no tumba el lote ──────────────────────────
-- Igual que antes, salvo el bloque begin … exception: si la ficha no pasa las reglas, no se guarda y se
-- contesta {error:'invalid', reason:…}. La app (25.8) ya maneja esa respuesta: no la reintenta en bucle y
-- lo anota en el Registro («el servidor no la aceptó»).
create or replace function public.sd_push(p_device text, p_staff text, p_ops jsonb) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare dv public.sd_devices; o jsonb; res jsonb := '[]'::jsonb; cur public.sd_entities; k text; b int; nv int; s bigint; prev jsonb; del boolean;
begin
  select * into dv from public.sd_dev(p_device);
  if dv.id is null then return json_build_object('error', 'device'); end if;
  if jsonb_typeof(p_ops) <> 'array' or jsonb_array_length(p_ops) > 200 then return json_build_object('error', 'ops'); end if;
  perform pg_advisory_xact_lock(hashtext(dv.hotel_id::text));
  update public.sd_devices set last_seen = now() where id = dv.id and (last_seen is null or last_seen < now() - interval '1 minute');
  for o in select value from jsonb_array_elements(p_ops) loop
    k := o->>'key';
    if k is null or k !~ '^[a-z]{1,4}:[A-Za-z0-9_.-]{1,40}$' or length(coalesce(o->>'op', '')) not between 8 and 64
       or octet_length(coalesce(o->'data', 'null'::jsonb)::text) > (case when k like 'gc:%' then 400000 else 65536 end) then
      res := res || jsonb_build_array(jsonb_build_object('op', o->>'op', 'key', k, 'error', 'invalid')); continue;
    end if;
    select result into prev from public.sd_ops where hotel_id = dv.hotel_id and op_id = o->>'op';
    if found then res := res || jsonb_build_array(prev); continue; end if;
    b := coalesce((o->>'base')::int, 0);
    del := coalesce((o->>'del')::boolean, false);
    cur := null;
    select * into cur from public.sd_entities where hotel_id = dv.hotel_id and key = k for update;
    if del and k like 'gc:%' then
      prev := jsonb_build_object('op', o->>'op', 'key', k, 'ok', true, 'v', coalesce(cur.version, 0), 'seq', coalesce(cur.seq, 0));
    elsif (cur.key is null and b = 0) or (cur.key is not null and cur.version = b) then
      begin
        nv := coalesce(cur.version, 0) + 1; s := nextval('public.sd_seq');
        insert into public.sd_entities(hotel_id, key, version, data, deleted, seq, updated_at, device_id, staff)
             values (dv.hotel_id, k, nv, case when del then null else o->'data' end, del, s, now(), dv.id, left(coalesce(p_staff, ''), 24))
        on conflict (hotel_id, key) do update
          set version = excluded.version, data = excluded.data, deleted = excluded.deleted, seq = excluded.seq,
              updated_at = excluded.updated_at, device_id = excluded.device_id, staff = excluded.staff;
        prev := jsonb_build_object('op', o->>'op', 'key', k, 'ok', true, 'v', nv, 'seq', s);
      exception when check_violation or foreign_key_violation or not_null_violation or invalid_text_representation
                  or numeric_value_out_of_range or string_data_right_truncation or datatype_mismatch then
        prev := jsonb_build_object('op', o->>'op', 'key', k, 'error', 'invalid', 'reason', left(sqlerrm, 200));
      end;
    else
      prev := jsonb_build_object('op', o->>'op', 'key', k, 'conflict', true, 'v', coalesce(cur.version, 0), 'data', cur.data,
                                 'del', coalesce(cur.deleted, true), 'seq', coalesce(cur.seq, 0));
    end if;
    insert into public.sd_ops(hotel_id, op_id, device_id, key, result) values (dv.hotel_id, o->>'op', dv.id, k, prev);
    res := res || jsonb_build_array(prev);
  end loop;
  return json_build_object('results', res, 'seq', public.sd_last_seq(dv.hotel_id));
end $function$;

revoke execute on function public.sd_bad(text), public.sd_int(jsonb, text, boolean), public.sd_txt(jsonb, text),
                           public.sd_bool(jsonb, text), public.sd_project() from public, anon, authenticated;
