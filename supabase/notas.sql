-- =====================================================================
-- LUVANA — notas de lo que piden las clientas y no hay en stock
-- Ejecutar UNA vez en: Supabase → SQL Editor → New query → Run
-- (después de schema.sql). Se puede volver a ejecutar sin dañar nada.
-- =====================================================================

create table if not exists public.solicitudes (
  id           bigint generated always as identity primary key,
  creado       timestamptz not null default now(),
  cliente      text,
  celular      text,
  producto     text    not null,
  producto_id  bigint references public.productos(id) on delete set null,
  cantidad     integer not null default 1 check (cantidad > 0),
  nota         text,
  estado       text    not null default 'Pendiente'
               check (estado in ('Pendiente', 'Pedido al proveedor', 'Avisada', 'Cerrada')),
  actualizado  timestamptz not null default now()
);

create index if not exists solicitudes_estado_idx on public.solicitudes (estado, creado desc);

alter table public.solicitudes enable row level security;

drop policy if exists admin_solicitudes on public.solicitudes;
create policy admin_solicitudes on public.solicitudes
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

revoke all on public.solicitudes from anon;
