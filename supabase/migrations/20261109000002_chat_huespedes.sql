-- StayDesk · chat con huéspedes (v25.2)
-- Reconstruida el 17 nov 2026 desde la base en vivo de StayDesk 25.8 (migración 0002_chat_huespedes), sin cambios.
-- El huésped escribe desde su celular directo al servidor: solo si da el número de habitación y el apellido
-- de quien está alojado ahí (la habitación debe estar «ocupada»).

create or replace function public.sd_gnorm(p text) returns text
language sql immutable set search_path to 'public' as $function$
  select trim(regexp_replace(lower(translate(coalesce(p, ''),
    'áàäâãåéèëêíìïîóòöôõúùüûñçýÿÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇÝ',
    'aaaaaaeeeeiiiiooooouuuuncyyAAAAAAEEEEIIIIOOOOOUUUUNCY')), '[^a-z0-9]+', ' ', 'g'))
$function$;

create or replace function public.sd_gmatch(p_hotel uuid, p_room integer, p_name text) returns text
language plpgsql stable security definer set search_path to 'public' as $function$
declare d jsonb; nt text[]; it text[];
begin
  select data into d from public.sd_entities where hotel_id = p_hotel and key = 'rm:' || p_room and not deleted;
  if d is null or d->>'status' <> 'ocupada' or coalesce(d->>'guest', '') = '' then return null; end if;
  nt := array_remove(string_to_array(public.sd_gnorm(d->>'guest'), ' '), '');
  it := array_remove(string_to_array(public.sd_gnorm(p_name), ' '), '');
  if coalesce(array_length(nt, 1), 0) = 0 or coalesce(array_length(it, 1), 0) = 0 then return null; end if;
  if it <@ nt and nt[array_length(nt, 1)] = any(it) then return d->>'guest'; end if;
  return null;
end $function$;

create or replace function public.sd_gc_guest(p_hotel uuid, p_room integer, p_name text) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare g text; d jsonb;
begin
  if p_hotel is null or p_room is null or p_room < 1 or p_room > 99999 then return json_build_object('error', 'match'); end if;
  g := public.sd_gmatch(p_hotel, p_room, left(coalesce(p_name, ''), 60));
  if g is null then perform pg_sleep(0.4); return json_build_object('error', 'match'); end if;
  select data into d from public.sd_entities where hotel_id = p_hotel and key = 'gc:' || p_room and not deleted;
  if d is not null and (d->>'g' is distinct from g) then d := null; end if;
  return json_build_object('ok', true, 'guest', g, 'conv', d, 'hotel', (select name from public.sd_hotels where id = p_hotel));
end $function$;

create or replace function public.sd_gc_guest_send(p_hotel uuid, p_room integer, p_name text, p_msg jsonb, p_ack text, p_lg text) returns json
language plpgsql security definer set search_path to 'public', 'extensions' as $function$
declare g text; cur public.sd_entities; c jsonb; m jsonb; k text; now_ms bigint; nx bigint; prev_ts bigint; reopen boolean; msgs jsonb; it jsonb; n int; s bigint; i int;
begin
  if p_hotel is null or p_room is null or p_room < 1 or p_room > 99999 or jsonb_typeof(p_msg) <> 'object' then return json_build_object('error', 'bad'); end if;
  g := public.sd_gmatch(p_hotel, p_room, left(coalesce(p_name, ''), 60));
  if g is null then perform pg_sleep(0.4); return json_build_object('error', 'match'); end if;
  perform pg_advisory_xact_lock(hashtext(p_hotel::text));
  now_ms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  k := p_msg->>'k';
  if k = 't' then
    if length(trim(coalesce(p_msg->>'x', ''))) = 0 then return json_build_object('error', 'bad'); end if;
    m := jsonb_build_object('k', 't', 'x', left(p_msg->>'x', 600));
  elsif k = 'rq' then
    select coalesce(jsonb_agg(jsonb_build_object('k', left(e->>'k', 8), 'q', greatest(1, least(9, coalesce((e->>'q')::int, 1))))), '[]'::jsonb)
      into it from (select e from jsonb_array_elements(case when jsonb_typeof(p_msg->'it') = 'array' then p_msg->'it' else '[]'::jsonb end) e
                    where jsonb_typeof(e) = 'object' and coalesce(e->>'k', '') ~ '^[a-z]{1,8}$' limit 12) z;
    if jsonb_array_length(it) = 0 then return json_build_object('error', 'bad'); end if;
    m := jsonb_build_object('k', 'rq', 'it', it, 'x', left(coalesce(p_msg->>'x', ''), 140), 'st', 'new');
  elsif k = 'pb' then
    m := jsonb_build_object('k', 'pb', 'cat', left(coalesce(p_msg->>'cat', 'Otro'), 40), 'x', left(coalesce(p_msg->>'x', ''), 600), 'st', 'new');
    if coalesce(p_msg->>'ph', '') ~ '^data:image/jpeg;base64,[A-Za-z0-9+/=]+$' and length(p_msg->>'ph') <= 200000 then m := m || jsonb_build_object('ph', p_msg->>'ph'); end if;
  else
    return json_build_object('error', 'bad');
  end if;
  select * into cur from public.sd_entities where hotel_id = p_hotel and key = 'gc:' || p_room for update;
  c := case when cur.key is not null and not cur.deleted then cur.data else null end;
  if c is null or (c->>'g' is distinct from g) then
    nx := greatest(coalesce((c->>'nx')::bigint, 0), floor((now_ms - 1700000000000) / 1000)::bigint);
    c := jsonb_build_object('id', p_room::text, 'room', p_room, 'g', g, 'st', 'open', 'end', 0, 'lg', 'es', 't0', now_ms, 'tl', now_ms,
                            'nx', nx, 'm', '[]'::jsonb, 'rd', '{}'::jsonb, 'sn', 0, 'gr', 0);
  end if;
  msgs := case when jsonb_typeof(c->'m') = 'array' then c->'m' else '[]'::jsonb end;
  select max((e->>'ts')::bigint) into prev_ts from jsonb_array_elements(msgs) e where e->>'by' = 'g';
  if prev_ts is not null and now_ms - prev_ts < 900 then return json_build_object('error', 'rate'); end if;
  reopen := c->>'st' = 'done';
  select greatest(coalesce((c->>'nx')::bigint, 0), coalesce(max((e->>'i')::bigint), 0)) into nx from jsonb_array_elements(msgs) e;
  nx := nx + 1;
  msgs := msgs || jsonb_build_array(m || jsonb_build_object('i', nx, 'by', 'g', 'ts', now_ms));
  if p_ack in ('ackrq', 'ackpb') or (p_ack = 'ack' and (prev_ts is null or now_ms - prev_ts > 3600000 or reopen)) then
    nx := nx + 1;
    msgs := msgs || jsonb_build_array(jsonb_build_object('i', nx, 'by', 'x', 'k', 'sy', 'sy', p_ack, 'ts', now_ms));
  end if;
  n := jsonb_array_length(msgs);
  if n > 80 then
    select jsonb_agg(e order by o) into msgs from jsonb_array_elements(msgs) with ordinality t(e, o) where o > n - 80;
  end if;
  c := c || jsonb_build_object('m', msgs, 'nx', nx, 'tl', now_ms, 'st', 'open', 'end', 0, 'lg', case when p_lg = 'en' then 'en' else 'es' end);
  while octet_length(c::text) > 380000 loop
    select min(o) into i from jsonb_array_elements(c->'m') with ordinality t(e, o) where e ? 'ph';
    exit when i is null;
    c := jsonb_set(c, array['m', (i - 1)::text], (c->'m'->(i - 1)) - 'ph');
  end loop;
  s := nextval('public.sd_seq');
  insert into public.sd_entities(hotel_id, key, version, data, deleted, seq, updated_at, device_id, staff)
       values (p_hotel, 'gc:' || p_room, coalesce(cur.version, 0) + 1, c, false, s, now(), null, 'huésped')
  on conflict (hotel_id, key) do update
    set version = excluded.version, data = excluded.data, deleted = false, seq = excluded.seq,
        updated_at = excluded.updated_at, device_id = null, staff = excluded.staff;
  return json_build_object('ok', true, 'guest', g, 'conv', c);
end $function$;

revoke execute on function public.sd_gnorm(text), public.sd_gmatch(uuid, integer, text) from public, anon, authenticated;
grant execute on function public.sd_gc_guest(uuid, integer, text)                          to anon, authenticated;
grant execute on function public.sd_gc_guest_send(uuid, integer, text, jsonb, text, text)  to anon, authenticated;
