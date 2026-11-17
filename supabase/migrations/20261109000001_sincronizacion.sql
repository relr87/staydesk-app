-- StayDesk · servidor de sincronización (fase 1)
-- Reconstruida el 17 nov 2026 desde la base en vivo de StayDesk 25.8 (migraciones 0001_sincronizacion y
-- 0003_chat_no_se_borra), sin cambios de comportamiento. Es el «contrato con el servidor» que usa la app.
--
-- Cómo funciona: cada equipo vinculado envía las fichas que cambiaron (habitaciones rm:, tickets tk:, llegadas ar:,
-- pedidos rq:, personal st:, …) con la versión que tenía; el servidor guarda la que llega primero y avisa de conflictos.
-- Nadie lee ni escribe las tablas directamente: solo por estas funciones (RLS activo y sin políticas).

create extension if not exists pgcrypto with schema extensions;

create table public.sd_hotels (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(name) between 1 and 80),
  created_at timestamptz not null default now()
);

create table public.sd_codes (
  code       text primary key,
  hotel_id   uuid not null references public.sd_hotels(id),
  expires_at timestamptz not null,
  used_at    timestamptz,
  created_by uuid
);

create table public.sd_devices (
  id         uuid primary key default gen_random_uuid(),
  hotel_id   uuid not null references public.sd_hotels(id),
  name       text not null default '',
  token_hash bytea not null unique,
  created_at timestamptz not null default now(),
  last_seen  timestamptz,
  revoked_at timestamptz
);

create sequence public.sd_seq;

create table public.sd_entities (
  hotel_id   uuid not null references public.sd_hotels(id),
  key        text not null,
  version    integer not null,
  data       jsonb,
  deleted    boolean not null default false,
  seq        bigint not null,
  updated_at timestamptz not null default now(),
  device_id  uuid,
  staff      text,
  primary key (hotel_id, key)
);
create index sd_entities_hotel_seq on public.sd_entities (hotel_id, seq);

create table public.sd_ops (
  hotel_id   uuid not null references public.sd_hotels(id),
  op_id      text not null,
  device_id  uuid,
  key        text,
  result     jsonb not null,
  created_at timestamptz not null default now(),
  primary key (hotel_id, op_id)
);

alter table public.sd_hotels   enable row level security;
alter table public.sd_codes    enable row level security;
alter table public.sd_devices  enable row level security;
alter table public.sd_entities enable row level security;
alter table public.sd_ops      enable row level security;

-- ─── funciones internas ─────────────────────────────────────────────────────

create or replace function public.sd_newcode() returns text
language plpgsql set search_path to 'public', 'extensions' as $function$
declare a text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; s text := ''; b bytea := gen_random_bytes(8); i int;
begin
  for i in 0..7 loop s := s || substr(a, (get_byte(b, i) % length(a)) + 1, 1); end loop;
  return substr(s, 1, 4) || '-' || substr(s, 5, 4);
end $function$;

create or replace function public.sd_dev(p_token text) returns public.sd_devices
language sql stable security definer set search_path to 'public', 'extensions' as $function$
  select * from public.sd_devices
   where p_token is not null and length(p_token) = 64
     and token_hash = digest(p_token, 'sha256') and revoked_at is null
$function$;

create or replace function public.sd_last_seq(p_hotel uuid) returns bigint
language sql stable security definer set search_path to 'public', 'extensions' as $function$
  select coalesce((select seq from public.sd_entities where hotel_id = p_hotel order by seq desc limit 1), 0)
$function$;

-- solo el administrador (SQL / panel de Supabase): crea un hotel y su primer código de conexión
create or replace function public.sd_create_hotel(p_name text) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare h uuid; c text;
begin
  insert into public.sd_hotels(name) values (left(trim(p_name), 80)) returning id into h;
  c := public.sd_newcode();
  insert into public.sd_codes(code, hotel_id, expires_at) values (c, h, now() + interval '24 hours');
  return json_build_object('hotel_id', h, 'code', c, 'expires_at', now() + interval '24 hours');
end $function$;

-- ─── funciones que llama la app ─────────────────────────────────────────────

create or replace function public.sd_register(p_code text, p_name text) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare r public.sd_codes; t text; d uuid; hn text;
begin
  select * into r from public.sd_codes
   where code = upper(trim(coalesce(p_code, ''))) and used_at is null and expires_at > now()
   for update;
  if not found then perform pg_sleep(0.4); return json_build_object('error', 'code'); end if;
  update public.sd_codes set used_at = now() where code = r.code;
  t := encode(gen_random_bytes(32), 'hex');
  insert into public.sd_devices(hotel_id, name, token_hash)
       values (r.hotel_id, left(coalesce(p_name, ''), 60), digest(t, 'sha256')) returning id into d;
  select name into hn from public.sd_hotels where id = r.hotel_id;
  return json_build_object('device_token', t, 'device_id', d, 'hotel_id', r.hotel_id, 'hotel_name', hn);
end $function$;

create or replace function public.sd_device_code(p_device text) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare dv public.sd_devices; c text;
begin
  select * into dv from public.sd_dev(p_device);
  if dv.id is null then return json_build_object('error', 'device'); end if;
  c := public.sd_newcode();
  insert into public.sd_codes(code, hotel_id, expires_at, created_by) values (c, dv.hotel_id, now() + interval '15 minutes', dv.id);
  return json_build_object('code', c, 'expires_at', now() + interval '15 minutes');
end $function$;

create or replace function public.sd_devices_list(p_device text) returns json
language plpgsql stable security definer set search_path to 'public', 'extensions' as $function$
declare dv public.sd_devices;
begin
  select * into dv from public.sd_dev(p_device);
  if dv.id is null then return json_build_object('error', 'device'); end if;
  return json_build_object('devices', (select coalesce(json_agg(json_build_object('id', id, 'name', name, 'created_at', created_at, 'last_seen', last_seen, 'me', id = dv.id) order by created_at), '[]'::json)
                                        from public.sd_devices where hotel_id = dv.hotel_id and revoked_at is null));
end $function$;

create or replace function public.sd_revoke(p_device text, p_target uuid) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare dv public.sd_devices;
begin
  select * into dv from public.sd_dev(p_device);
  if dv.id is null then return json_build_object('error', 'device'); end if;
  update public.sd_devices set revoked_at = now() where id = p_target and hotel_id = dv.hotel_id and revoked_at is null;
  return json_build_object('ok', found);
end $function$;

create or replace function public.sd_pull(p_device text, p_since bigint) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare dv public.sd_devices; ch jsonb;
begin
  select * into dv from public.sd_dev(p_device);
  if dv.id is null then return json_build_object('error', 'device'); end if;
  update public.sd_devices set last_seen = now() where id = dv.id and (last_seen is null or last_seen < now() - interval '1 minute');
  select coalesce(jsonb_agg(jsonb_build_object('key', key, 'v', version, 'seq', seq, 'data', data, 'del', deleted, 'by', device_id) order by seq), '[]'::jsonb)
    into ch
    from (select * from public.sd_entities where hotel_id = dv.hotel_id and seq > coalesce(p_since, 0) order by seq limit 1000) z;
  return json_build_object('changes', ch, 'seq', public.sd_last_seq(dv.hotel_id), 'more', jsonb_array_length(ch) = 1000,
                           'hotel', (select name from public.sd_hotels where id = dv.hotel_id));
end $function$;

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
      -- las conversaciones de huéspedes no se borran desde un equipo
      prev := jsonb_build_object('op', o->>'op', 'key', k, 'ok', true, 'v', coalesce(cur.version, 0), 'seq', coalesce(cur.seq, 0));
    elsif (cur.key is null and b = 0) or (cur.key is not null and cur.version = b) then
      nv := coalesce(cur.version, 0) + 1; s := nextval('public.sd_seq');
      insert into public.sd_entities(hotel_id, key, version, data, deleted, seq, updated_at, device_id, staff)
           values (dv.hotel_id, k, nv, case when del then null else o->'data' end, del, s, now(), dv.id, left(coalesce(p_staff, ''), 24))
      on conflict (hotel_id, key) do update
        set version = excluded.version, data = excluded.data, deleted = excluded.deleted, seq = excluded.seq,
            updated_at = excluded.updated_at, device_id = excluded.device_id, staff = excluded.staff;
      prev := jsonb_build_object('op', o->>'op', 'key', k, 'ok', true, 'v', nv, 'seq', s);
    else
      prev := jsonb_build_object('op', o->>'op', 'key', k, 'conflict', true, 'v', coalesce(cur.version, 0), 'data', cur.data,
                                 'del', coalesce(cur.deleted, true), 'seq', coalesce(cur.seq, 0));
    end if;
    insert into public.sd_ops(hotel_id, op_id, device_id, key, result) values (dv.hotel_id, o->>'op', dv.id, k, prev);
    res := res || jsonb_build_array(prev);
  end loop;
  return json_build_object('results', res, 'seq', public.sd_last_seq(dv.hotel_id));
end $function$;

-- ─── permisos: la app (clave pública) solo puede llamar estas funciones ─────
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.sd_register(text, text)        to anon, authenticated;
grant execute on function public.sd_device_code(text)           to anon, authenticated;
grant execute on function public.sd_devices_list(text)          to anon, authenticated;
grant execute on function public.sd_revoke(text, uuid)          to anon, authenticated;
grant execute on function public.sd_pull(text, bigint)          to anon, authenticated;
grant execute on function public.sd_push(text, text, jsonb)     to anon, authenticated;
