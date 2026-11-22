-- =====================================================================
-- LUVANA — gastos del negocio (para ver la ganancia neta)
-- Ejecutar UNA vez en: Supabase → SQL Editor → New query → Run
-- (después de schema.sql). Se puede volver a ejecutar sin dañar nada.
--
-- Ojo: la mercancía NO va aquí. Su costo ya se descuenta en cada venta
-- (y las compras se registran en Mercancía → Entradas).
-- =====================================================================

create table if not exists public.gastos (
  id           bigint generated always as identity primary key,
  fecha        date    not null default (now() at time zone 'America/Bogota')::date,
  categoria    text    not null default 'Otros',
  descripcion  text,
  valor        integer not null check (valor > 0),
  creado       timestamptz not null default now()
);

create index if not exists gastos_fecha_idx on public.gastos (fecha desc);

alter table public.gastos enable row level security;

drop policy if exists admin_gastos on public.gastos;
create policy admin_gastos on public.gastos
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

revoke all on public.gastos from anon;
