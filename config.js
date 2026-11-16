// Configuración de Supabase para LUVANA.
// Supabase → Project Settings → API (o Data API):
//   - "Project URL"  → url
//   - "anon public" (o "publishable") key → anonKey
// La clave anon es pública por diseño: la seguridad la dan las políticas (RLS) de schema.sql.
// NUNCA pongas aquí la clave "service_role" / "secret".
window.LUVANA_CONFIG = {
  url: 'https://letytgfyvzmhsyrqwuhn.supabase.co',
  anonKey: 'sb_publishable_J7Lrd1NN4RdW-r-06iCGTA_oIGvJyx2',
  // Número de WhatsApp de la tienda para recibir pedidos del catálogo (con 57 adelante, sin + ni espacios)
  whatsapp: '573187050354'
};
