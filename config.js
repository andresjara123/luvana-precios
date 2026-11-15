// Configuración de Supabase para LUVANA.
// Supabase → Project Settings → API (o Data API):
//   - "Project URL"  → url
//   - "anon public" (o "publishable") key → anonKey
// La clave anon es pública por diseño: la seguridad la dan las políticas (RLS) de schema.sql.
// NUNCA pongas aquí la clave "service_role" / "secret".
window.LUVANA_CONFIG = {
  url: '',
  anonKey: ''
};
