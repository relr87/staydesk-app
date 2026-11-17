import Link from "next/link";
import type { Metadata } from "next";
import { db } from "@/lib/supabase";
import { roomFiltersSchema } from "@/lib/validation";
import {
  ROOM_STATUSES,
  roomStatusLabel,
  roomStatusStyle,
  type Room,
  type RoomType,
} from "@/lib/labels";

export const metadata: Metadata = { title: "Habitaciones" };

export default async function RoomsPage({ searchParams }: PageProps<"/rooms">) {
  const sp = await searchParams;
  const one = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) || undefined;
  const f = roomFiltersSchema.parse({
    q: one(sp.q) ?? "",
    status: one(sp.status),
    floor: one(sp.floor),
    type: one(sp.type),
  });

  let query = db()
    .from("rooms")
    .select("id, number, floor, type_code, status, occupied, notes, updated_at, room_types(name, accessible)")
    .order("number");
  if (f.q) query = query.like("number", `${f.q}%`);
  if (f.status) query = query.eq("status", f.status);
  if (f.floor) query = query.eq("floor", f.floor);
  if (f.type) query = query.eq("type_code", f.type);

  const [roomsRes, typesRes] = await Promise.all([
    query.returns<Room[]>(),
    db().from("room_types").select("code, name, accessible").order("name").returns<RoomType[]>(),
  ]);
  if (roomsRes.error) throw new Error(roomsRes.error.message);
  if (typesRes.error) throw new Error(typesRes.error.message);
  const rooms = roomsRes.data;
  const types = typesRes.data;

  const counts = Object.fromEntries(ROOM_STATUSES.map((s) => [s, 0])) as Record<string, number>;
  for (const r of rooms) counts[r.status]++;
  const filtered = Boolean(f.q || f.status || f.floor || f.type);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-2">
        <div>
          <h1 className="text-2xl font-semibold">Habitaciones</h1>
          <p className="text-sm text-stone-600">
            {rooms.length} {rooms.length === 1 ? "habitación" : "habitaciones"}
            {filtered ? " con estos filtros" : ""}
          </p>
        </div>
      </div>

      <form
        method="get"
        className="grid grid-cols-2 gap-3 rounded-xl border border-stone-200 bg-white p-4 sm:grid-cols-5"
        role="search"
      >
        <label className="col-span-2 flex flex-col gap-1 text-sm sm:col-span-1">
          Número
          <input
            name="q"
            defaultValue={f.q}
            inputMode="numeric"
            placeholder="Ej. 305"
            className="rounded-lg border border-stone-300 px-3 py-2"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Estado
          <select name="status" defaultValue={f.status ?? ""} className="rounded-lg border border-stone-300 px-3 py-2">
            <option value="">Todos</option>
            {ROOM_STATUSES.map((s) => (
              <option key={s} value={s}>
                {roomStatusLabel[s]}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Piso
          <select name="floor" defaultValue={f.floor ?? ""} className="rounded-lg border border-stone-300 px-3 py-2">
            <option value="">Todos</option>
            {[1, 2, 3, 4, 5, 6, 7].map((n) => (
              <option key={n} value={n}>
                Piso {n}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Tipo
          <select name="type" defaultValue={f.type ?? ""} className="rounded-lg border border-stone-300 px-3 py-2">
            <option value="">Todos</option>
            {types.map((t) => (
              <option key={t.code} value={t.code}>
                {t.name}
              </option>
            ))}
          </select>
        </label>
        <div className="flex items-end gap-2">
          <button className="flex-1 rounded-lg bg-[#0f3d3e] px-4 py-2 text-sm font-medium text-white">
            Filtrar
          </button>
          {filtered && (
            <Link href="/rooms" className="rounded-lg px-3 py-2 text-sm text-stone-600 underline">
              Limpiar
            </Link>
          )}
        </div>
      </form>

      <ul className="flex flex-wrap gap-2 text-xs">
        {ROOM_STATUSES.map((s) => (
          <li key={s} className={`rounded-full px-3 py-1 ring-1 ${roomStatusStyle[s]}`}>
            {roomStatusLabel[s]}: {counts[s]}
          </li>
        ))}
      </ul>

      {rooms.length === 0 ? (
        <div className="rounded-xl border border-dashed border-stone-300 bg-white p-10 text-center">
          <p className="font-medium">No hay habitaciones que coincidan.</p>
          <p className="mt-1 text-sm text-stone-600">Prueba con otro número o quita algún filtro.</p>
          <Link href="/rooms" className="mt-4 inline-block text-sm font-medium text-[#0f3d3e] underline">
            Ver todas
          </Link>
        </div>
      ) : (
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-6">
          {rooms.map((r) => (
            <li key={r.id}>
              <Link
                href={`/rooms/${r.id}`}
                className="block rounded-xl border border-stone-200 bg-white p-3 transition hover:border-stone-400"
              >
                <div className="flex items-baseline justify-between">
                  <span className="text-lg font-semibold">{r.number}</span>
                  <span className="text-xs text-stone-500">{r.type_code}</span>
                </div>
                <span className={`mt-2 inline-block rounded-full px-2 py-0.5 text-xs ring-1 ${roomStatusStyle[r.status]}`}>
                  {roomStatusLabel[r.status]}
                </span>
                <p className="mt-1 text-xs text-stone-500">{r.occupied ? "Ocupada" : "Vacía"}</p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
