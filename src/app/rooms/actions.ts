"use server";

import { revalidatePath } from "next/cache";
import { db } from "@/lib/supabase";
import { formToRoomUpdate, type FormState } from "@/lib/validation";

// Traduce errores de Postgres a mensajes claros para la recepción.
function pgMessage(code: string | undefined, fallback: string) {
  if (code === "23514") return "La base rechazó el cambio: un dato no cumple las reglas.";
  if (code === "22P02") return "La base rechazó el cambio: valor con formato inválido.";
  if (code === "23503") return "El registro relacionado no existe.";
  return fallback;
}

export async function updateRoom(_prev: FormState, fd: FormData): Promise<FormState> {
  const parsed = formToRoomUpdate(fd);
  if (!parsed.success) {
    return {
      ok: false,
      message: "Revisa los campos marcados.",
      fieldErrors: parsed.error.flatten().fieldErrors,
    };
  }
  const { id, ...changes } = parsed.data;
  const { error } = await db().from("rooms").update(changes).eq("id", id);
  if (error) {
    return { ok: false, message: pgMessage(error.code, "No se pudo guardar. Inténtalo otra vez.") };
  }
  revalidatePath("/rooms");
  revalidatePath(`/rooms/${id}`);
  return { ok: true, message: "Cambios guardados." };
}
