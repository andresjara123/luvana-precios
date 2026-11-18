-- =====================================================================
-- LUVANA — entradas de mercancía y pedido al proveedor
-- Ejecutar UNA vez en: Supabase → SQL Editor → New query → Run
-- (después de schema.sql). Se puede volver a ejecutar sin dañar nada.
-- =====================================================================

-- ---------- Datos nuevos por producto
alter table public.productos add column if not exists proveedor text;
alter table public.productos add column if not exists stock_minimo integer not null default 3;
do $$ begin
  alter table public.productos add constraint productos_stock_minimo_chk check (stock_minimo >= 0);
exception when duplicate_object then null; end $$;

-- ---------- Entradas de mercancía
create table if not exists public.entradas (
  id           bigint generated always as identity primary key,
  fecha        timestamptz not null default now(),
  proveedor    text,
  notas        text,
  total_costo  integer not null default 0,
  anulada      boolean not null default false
);

create table if not exists public.entrada_items (
  id              bigint generated always as identity primary key,
  entrada_id      bigint not null references public.entradas(id) on delete cascade,
  producto_id     bigint references public.productos(id) on delete set null,
  nombre          text    not null,
  cantidad        integer not null check (cantidad > 0),
  costo_unit      integer not null check (costo_unit >= 0),
  stock_anterior  integer not null,
  costo_anterior  integer not null
);

create index if not exists entradas_fecha_idx on public.entradas (fecha desc);
create index if not exists entrada_items_entrada_idx on public.entrada_items (entrada_id);

alter table public.entradas      enable row level security;
alter table public.entrada_items enable row level security;

drop policy if exists admin_entradas on public.entradas;
create policy admin_entradas on public.entradas
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists admin_entrada_items on public.entrada_items;
create policy admin_entrada_items on public.entrada_items
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- ---------- Registrar una entrada
-- items: [{"producto_id": 1, "cantidad": 12, "costo_unit": 3000}, ...]
-- Suma las unidades al inventario y actualiza el costo del producto con el
-- costo PROMEDIO entre lo que había y lo que llega (así la ganancia es real).
create or replace function public.registrar_entrada(
  items jsonb,
  proveedor text default null,
  notas text default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id    bigint;
  it      jsonb;
  p       public.productos%rowtype;
  q       integer;
  c       integer;
  nuevo   integer;
  v_total integer := 0;
  v_prov  text := nullif(trim(proveedor), '');
begin
  if not public.es_admin() then
    raise exception 'No autorizado';
  end if;
  if items is null or jsonb_array_length(items) = 0 then
    raise exception 'La entrada no tiene productos';
  end if;

  insert into public.entradas (proveedor, notas)
  values (v_prov, nullif(trim(registrar_entrada.notas), ''))
  returning id into v_id;

  for it in select * from jsonb_array_elements(items) loop
    q := (it ->> 'cantidad')::integer;
    c := (it ->> 'costo_unit')::integer;
    if q is null or q <= 0 then raise exception 'Cantidad inválida'; end if;
    if c is null or c < 0 then raise exception 'Costo inválido'; end if;

    select * into p from public.productos
      where id = (it ->> 'producto_id')::bigint
      for update;
    if not found then
      raise exception 'Producto % no existe', it ->> 'producto_id';
    end if;

    nuevo := round((p.stock::numeric * p.costo + q::numeric * c) / (p.stock + q));

    insert into public.entrada_items (entrada_id, producto_id, nombre, cantidad, costo_unit, stock_anterior, costo_anterior)
      values (v_id, p.id, p.nombre, q, c, p.stock, p.costo);

    update public.productos
      set stock = stock + q,
          costo = nuevo,
          proveedor = coalesce(v_prov, p.proveedor),
          actualizado = now()
      where id = p.id;

    v_total := v_total + q * c;
  end loop;

  update public.entradas set total_costo = v_total where id = v_id;
  return v_id;
end;
$$;

-- ---------- Anular una entrada (por si se registró mal)
-- Resta las unidades y recalcula el costo promedio sin esa mercancía.
create or replace function public.anular_entrada(p_entrada_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r     record;
  p     public.productos%rowtype;
  resto integer;
begin
  if not public.es_admin() then
    raise exception 'No autorizado';
  end if;
  if not exists (select 1 from public.entradas where id = p_entrada_id) then
    raise exception 'La entrada no existe';
  end if;
  if exists (select 1 from public.entradas where id = p_entrada_id and anulada) then
    raise exception 'La entrada ya estaba anulada';
  end if;

  for r in select * from public.entrada_items where entrada_id = p_entrada_id loop
    if r.producto_id is null then continue; end if;
    select * into p from public.productos where id = r.producto_id for update;
    if not found then continue; end if;
    if p.stock < r.cantidad then
      raise exception 'No se puede anular: de "%" ya se vendieron unidades de esta entrada (quedan %, la entrada trajo %).', p.nombre, p.stock, r.cantidad;
    end if;
    resto := p.stock - r.cantidad;
    update public.productos
      set stock = resto,
          costo = case
                    when resto > 0 then greatest(0, round((p.stock::numeric * p.costo - r.cantidad::numeric * r.costo_unit) / resto))
                    else r.costo_anterior
                  end,
          actualizado = now()
      where id = p.id;
  end loop;

  update public.entradas set anulada = true where id = p_entrada_id;
end;
$$;

revoke all on function public.registrar_entrada(jsonb, text, text) from public, anon;
revoke all on function public.anular_entrada(bigint) from public, anon;
grant execute on function public.registrar_entrada(jsonb, text, text) to authenticated;
grant execute on function public.anular_entrada(bigint) to authenticated;
