import * as z from "zod";
import { ROOM_STATUSES } from "./labels";

// Validación del servidor. La base además tiene sus propias restricciones
// (checks, enums, llaves foráneas y triggers): dos capas, nunca solo el navegador.

export const roomUpdateSchema = z.object({
  id: z.uuid({ error: "Habitación inválida" }),
  status: z.enum(ROOM_STATUSES, { error: "Estado inválido" }),
  occupied: z.boolean(),
  notes: z
    .string()
    .trim()
    .max(300, { error: "Las notas no pueden pasar de 300 caracteres" })
    .transform((v) => (v === "" ? null : v)),
});

export type FormState = {
  ok: boolean;
  message: string;
  fieldErrors?: Record<string, string[] | undefined>;
};

export function formToRoomUpdate(fd: FormData) {
  return roomUpdateSchema.safeParse({
    id: fd.get("id"),
    status: fd.get("status"),
    occupied: fd.get("occupied") === "on",
    notes: fd.get("notes") ?? "",
  });
}

export const roomFiltersSchema = z.object({
  q: z.string().trim().max(4).regex(/^[0-9]*$/).catch(""),
  status: z.enum(ROOM_STATUSES).optional().catch(undefined),
  floor: z.coerce.number().int().min(1).max(20).optional().catch(undefined),
  type: z.string().regex(/^[A-Z]{4,5}$/).optional().catch(undefined),
});
