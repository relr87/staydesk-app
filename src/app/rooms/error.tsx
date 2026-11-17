"use client";

export default function RoomsError({ error, retry }: { error: Error & { digest?: string }; retry: () => void }) {
  return (
    <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-8 text-center">
      <p className="font-medium text-rose-900">No pudimos cargar las habitaciones.</p>
      <p className="mt-1 text-sm text-rose-800">
        Revisa la conexión e inténtalo otra vez.{error.digest ? ` (código ${error.digest})` : ""}
      </p>
      <button
        onClick={() => retry()}
        className="mt-4 rounded-lg bg-rose-900 px-4 py-2 text-sm font-medium text-white"
      >
        Reintentar
      </button>
    </div>
  );
}
