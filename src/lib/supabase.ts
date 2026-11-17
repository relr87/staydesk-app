import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

// Cliente SOLO de servidor. Usa la clave secreta, que nunca lleva el prefijo
// NEXT_PUBLIC_ y por eso nunca llega al navegador. "server-only" hace que el
// build falle si algún componente de cliente intenta importar este archivo.
let client: SupabaseClient | null = null;

export function db(): SupabaseClient {
  if (client) return client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) {
    throw new Error(
      "Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SECRET_KEY en las variables de entorno.",
    );
  }
  client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return client;
}
