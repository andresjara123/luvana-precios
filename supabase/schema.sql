-- =====================================================================
-- LUVANA Beauty & Care — esquema de base de datos (Supabase / Postgres)
-- Ejecutar UNA vez en: Supabase → SQL Editor → New query → Run
-- =====================================================================

-- ---------- Administradoras (quién puede ver costos y registrar ventas)
create table if not exists public.admins (
  email text primary key
);
alter table public.admins enable row level security;
-- Sin políticas: nadie la lee desde la web; solo la función es_admin().

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- ---------- Productos
create table if not exists public.productos (
  id         bigint generated always as identity primary key,
  nombre     text    not null,
  marca      text,
  categoria  text    not null default 'Maquillaje',
  precio     integer not null default 0 check (precio >= 0),
  costo      integer not null default 0 check (costo >= 0),
  stock      integer not null default 0 check (stock >= 0),
  foto       text,
  activo     boolean not null default true,
  creado     timestamptz not null default now(),
  actualizado timestamptz not null default now()
);

-- ---------- Ventas
create table if not exists public.ventas (
  id           bigint generated always as identity primary key,
  fecha        timestamptz not null default now(),
  cliente      text,
  metodo_pago  text not null default 'Efectivo',
  notas        text,
  total        integer not null default 0,
  costo_total  integer not null default 0,
  anulada      boolean not null default false
);

create table if not exists public.venta_items (
  id           bigint generated always as identity primary key,
  venta_id     bigint not null references public.ventas(id) on delete cascade,
  producto_id  bigint references public.productos(id) on delete set null,
  nombre       text    not null,
  cantidad     integer not null check (cantidad > 0),
  precio_unit  integer not null,
  costo_unit   integer not null
);

create index if not exists ventas_fecha_idx on public.ventas (fecha desc);
create index if not exists venta_items_venta_idx on public.venta_items (venta_id);

-- ---------- Seguridad: solo administradoras
alter table public.productos   enable row level security;
alter table public.ventas      enable row level security;
alter table public.venta_items enable row level security;

drop policy if exists admin_productos on public.productos;
create policy admin_productos on public.productos
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists admin_ventas on public.ventas;
create policy admin_ventas on public.ventas
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists admin_items on public.venta_items;
create policy admin_items on public.venta_items
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- ---------- Vista pública para el catálogo (SIN costos)
drop view if exists public.productos_publicos;
create view public.productos_publicos as
  select id, nombre, marca, categoria, precio, stock, foto
  from public.productos
  where activo;
grant select on public.productos_publicos to anon, authenticated;

-- ---------- Registrar una venta (descuenta inventario de forma segura)
-- items: [{"producto_id": 1, "cantidad": 2}, ...]
create or replace function public.registrar_venta(
  items jsonb,
  metodo_pago text default 'Efectivo',
  cliente text default null,
  notas text default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id     bigint;
  it       jsonb;
  p        public.productos%rowtype;
  q        integer;
  v_total  integer := 0;
  v_costo  integer := 0;
begin
  if not public.es_admin() then
    raise exception 'No autorizado';
  end if;
  if items is null or jsonb_array_length(items) = 0 then
    raise exception 'La venta no tiene productos';
  end if;

  insert into public.ventas (metodo_pago, cliente, notas)
  values (coalesce(metodo_pago, 'Efectivo'), nullif(cliente, ''), nullif(notas, ''))
  returning id into v_id;

  for it in select * from jsonb_array_elements(items) loop
    q := (it ->> 'cantidad')::integer;
    if q is null or q <= 0 then
      raise exception 'Cantidad inválida';
    end if;
    select * into p from public.productos
      where id = (it ->> 'producto_id')::bigint
      for update;
    if not found then
      raise exception 'Producto % no existe', it ->> 'producto_id';
    end if;
    if p.stock < q then
      raise exception 'No hay suficiente stock de "%" (quedan %)', p.nombre, p.stock;
    end if;
    update public.productos
      set stock = stock - q, actualizado = now()
      where id = p.id;
    insert into public.venta_items (venta_id, producto_id, nombre, cantidad, precio_unit, costo_unit)
      values (v_id, p.id, p.nombre, q, p.precio, p.costo);
    v_total := v_total + q * p.precio;
    v_costo := v_costo + q * p.costo;
  end loop;

  update public.ventas set total = v_total, costo_total = v_costo where id = v_id;
  return v_id;
end;
$$;

-- ---------- Anular una venta (devuelve las unidades al inventario)
create or replace function public.anular_venta(p_venta_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if not public.es_admin() then
    raise exception 'No autorizado';
  end if;
  if exists (select 1 from public.ventas where id = p_venta_id and anulada) then
    raise exception 'La venta ya estaba anulada';
  end if;
  for r in select producto_id, cantidad from public.venta_items where venta_id = p_venta_id loop
    if r.producto_id is not null then
      update public.productos set stock = stock + r.cantidad, actualizado = now()
      where id = r.producto_id;
    end if;
  end loop;
  update public.ventas set anulada = true where id = p_venta_id;
end;
$$;

revoke all on function public.registrar_venta(jsonb, text, text, text) from public, anon;
revoke all on function public.anular_venta(bigint) from public, anon;
grant execute on function public.registrar_venta(jsonb, text, text, text) to authenticated;
grant execute on function public.anular_venta(bigint) to authenticated;
