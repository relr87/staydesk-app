import Link from "next/link";

export default function RoomNotFound() {
  return (
    <div className="rounded-xl border border-dashed border-stone-300 bg-white p-10 text-center">
      <p className="font-medium">Esa habitación no existe.</p>
      <Link href="/rooms" className="mt-4 inline-block text-sm font-medium text-[#0f3d3e] underline">
        Volver a habitaciones
      </Link>
    </div>
  );
}
