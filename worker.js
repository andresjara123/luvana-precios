// Worker de LUVANA en Cloudflare.
// - fetch: sirve la página (archivos estáticos) igual que antes.
// - scheduled: una vez al día consulta Supabase para que el proyecto gratis
//   no se pause por inactividad (Supabase pausa tras 7 días sin uso).
export default {
  async fetch(request, env) {
    return env.ASSETS.fetch(request);
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(mantenerActivo(env));
  },
};

async function mantenerActivo(env) {
  const url = `${env.SUPABASE_URL}/rest/v1/productos_publicos?select=id&limit=1`;
  const res = await fetch(url, {
    headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}` },
  });
  console.log(`Supabase keep-alive: HTTP ${res.status}`);
  if (!res.ok) throw new Error(`Supabase respondió ${res.status}`);
}
