export default function Loading() {
  return (
    <div className="space-y-6" aria-busy="true" aria-live="polite">
      <span className="sr-only">Cargando…</span>
      <div className="h-8 w-48 animate-pulse rounded bg-stone-200" />
      <div className="h-24 animate-pulse rounded-xl bg-stone-200" />
      <ul className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-6">
        {Array.from({ length: 18 }).map((_, i) => (
          <li key={i} className="h-24 animate-pulse rounded-xl bg-stone-200" />
        ))}
      </ul>
    </div>
  );
}
