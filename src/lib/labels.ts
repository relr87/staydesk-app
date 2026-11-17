export const ROOM_STATUSES = ["dirty", "cleaning", "inspected", "ready", "out_of_order"] as const;
export type RoomStatus = (typeof ROOM_STATUSES)[number];

export const roomStatusLabel: Record<RoomStatus, string> = {
  dirty: "Sucia",
  cleaning: "En limpieza",
  inspected: "Por aprobar",
  ready: "Lista",
  out_of_order: "Fuera de servicio",
};

export const roomStatusStyle: Record<RoomStatus, string> = {
  dirty: "bg-amber-100 text-amber-900 ring-amber-300",
  cleaning: "bg-sky-100 text-sky-900 ring-sky-300",
  inspected: "bg-violet-100 text-violet-900 ring-violet-300",
  ready: "bg-emerald-100 text-emerald-900 ring-emerald-300",
  out_of_order: "bg-rose-100 text-rose-900 ring-rose-300",
};

export type RoomType = { code: string; name: string; accessible: boolean };

export type Room = {
  id: string;
  number: string;
  floor: number;
  type_code: string;
  status: RoomStatus;
  occupied: boolean;
  notes: string | null;
  updated_at: string;
  room_types?: { name: string; accessible: boolean } | null;
};
