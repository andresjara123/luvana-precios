-- =====================================================================
-- LUVANA — fotos de productos (Supabase Storage)
-- Ejecutar UNA vez en: Supabase → SQL Editor → New query → Run
-- Crea la carpeta pública "fotos" y deja que SOLO las administradoras
-- suban, cambien o borren fotos. Cualquiera puede verlas (catálogo).
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists fotos_admin_insert on storage.objects;
create policy fotos_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fotos' and public.es_admin());

drop policy if exists fotos_admin_update on storage.objects;
create policy fotos_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'fotos' and public.es_admin())
  with check (bucket_id = 'fotos' and public.es_admin());

drop policy if exists fotos_admin_delete on storage.objects;
create policy fotos_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'fotos' and public.es_admin());
