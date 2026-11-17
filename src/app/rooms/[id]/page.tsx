import Link from "next/link";
import { notFound } from "next/navigation";
import * as z from "zod";
import { db } from "@/lib/supabase";
import { roomStatusLabel, roomStatusStyle, type Room } from "@/lib/labels";
import { RoomForm } from "./room-form";

export default async function RoomDetail({ params }: PageProps<"/rooms/[id]">) {
  const { id } = await params;
  if (!z.uuid().safeParse(id).success) notFound();

  const { data: room, error } = await db()
    .from("rooms")
    .select("id, number, floor, type_code, status, occupied, notes, updated_at, room_types(name, accessible)")
    .eq("id", id)
    .maybeSingle<Room>();
  if (error) throw new Error(error.message);
  if (!room) notFound();

  return (
    <div className="mx-auto max-w-xl space-y-5">
      <Link href="/rooms" className="text-sm text-stone-600 underline">
        ← Habitaciones
      </Link>
      <div>
        <h1 className="text-3xl font-semibold">Habitación {room.number}</h1>
        <p className="mt-1 text-sm text-stone-600">
          Piso {room.floor} · {room.room_types?.name ?? room.type_code}
          {room.room_types?.accessible ? " · accesible" : ""}
        </p>
        <span className={`mt-3 inline-block rounded-full px-3 py-1 text-sm ring-1 ${roomStatusStyle[room.status]}`}>
          {roomStatusLabel[room.status]}
        </span>
      </div>
      <RoomForm room={room} />
      <p className="text-xs text-stone-500">
        Última actualización: {new Date(room.updated_at).toLocaleString("es-MX", { timeZone: "America/New_York" })}
      </p>
    </div>
  );
}
