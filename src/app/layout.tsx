import type { Metadata, Viewport } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "StayDesk", template: "%s · StayDesk" },
  description: "Habitaciones, limpieza y mantenimiento del hotel en un solo lugar.",
};

export const viewport: Viewport = { themeColor: "#0f3d3e" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="es" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-stone-50 text-stone-900">
        <header className="sticky top-0 z-10 border-b border-stone-200 bg-[#0f3d3e] text-white">
          <nav className="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3">
            <Link href="/rooms" className="text-lg font-semibold tracking-tight">
              StayDesk
            </Link>
            <Link href="/rooms" className="text-sm text-white/85 hover:text-white">
              Habitaciones
            </Link>
          </nav>
        </header>
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6">{children}</main>
        <footer className="py-6 text-center text-xs text-stone-500">
          StayDesk Demo Inn · datos de ejemplo inventados
        </footer>
      </body>
    </html>
  );
}
