"use client";

import { useActionState } from "react";
import { updateRoom } from "../actions";
import { ROOM_STATUSES, roomStatusLabel, type Room } from "@/lib/labels";
import type { FormState } from "@/lib/validation";

const initial: FormState = { ok: false, message: "" };

export function RoomForm({ room }: { room: Room }) {
  const [state, action, pending] = useActionState(updateRoom, initial);
  const err = state.fieldErrors ?? {};

  return (
    <form action={action} className="space-y-4 rounded-xl border border-stone-200 bg-white p-5">
      <input type="hidden" name="id" value={room.id} />

      <label className="flex flex-col gap-1 text-sm">
        Estado
        <select name="status" defaultValue={room.status} className="rounded-lg border border-stone-300 px-3 py-2">
          {ROOM_STATUSES.map((s) => (
            <option key={s} value={s}>
              {roomStatusLabel[s]}
            </option>
          ))}
        </select>
        {err.status && <span className="text-xs text-rose-700">{err.status[0]}</span>}
      </label>

      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" name="occupied" defaultChecked={room.occupied} className="size-4" />
        Ocupada por un huésped
      </label>

      <label className="flex flex-col gap-1 text-sm">
        Notas
        <textarea
          name="notes"
          defaultValue={room.notes ?? ""}
          maxLength={300}
          rows={3}
          className="rounded-lg border border-stone-300 px-3 py-2"
          placeholder="Ej. Huésped pidió almohada extra"
        />
        {err.notes && <span className="text-xs text-rose-700">{err.notes[0]}</span>}
      </label>

      <div className="flex items-center gap-3">
        <button
          disabled={pending}
          className="rounded-lg bg-[#0f3d3e] px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
        >
          {pending ? "Guardando…" : "Guardar"}
        </button>
        {state.message && (
          <p role="status" className={`text-sm ${state.ok ? "text-emerald-700" : "text-rose-700"}`}>
            {state.message}
          </p>
        )}
      </div>
    </form>
  );
}
