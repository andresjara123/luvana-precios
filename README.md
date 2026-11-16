# LUVANA Beauty & Care — precios, ventas e inventario

- `index.html` — catálogo público de precios (para clientas). Sin costos.
- `admin.html` — administración privada: registrar ventas, inventario, historial y dashboard. Requiere iniciar sesión.
- `config.js` — URL y clave pública (anon) de Supabase.
- `supabase/schema.sql` — tablas, seguridad (RLS) y funciones de la base de datos.

## Puesta en marcha (una sola vez)

1. **Crear el proyecto** en Supabase (región más cercana: São Paulo).
2. **SQL Editor → New query**: pegar `supabase/schema.sql` y **Run**.
3. **SQL Editor → New query**: pegar el archivo privado `luvana-datos-iniciales.sql` (no está en este repositorio porque tiene los costos), cambiar `TU_CORREO@ejemplo.com` por tu correo y **Run**.
4. **Authentication → Users → Add user → Create new user**: tu mismo correo y una contraseña. Marca *Auto Confirm User*.
5. **Authentication → Sign In / Providers**: desactiva **Allow new users to sign up** (así nadie más puede crear cuenta).
6. **Project Settings → API**: copia *Project URL* y la clave *anon / publishable* en `config.js`. Nunca la clave *service_role / secret*.
7. Abre `https://tiendaluvanabeauty.com/admin.html` e inicia sesión.

## Seguridad

- Las tablas solo se pueden leer y modificar con un usuario cuyo correo esté en la tabla `admins`.
- El catálogo público lee la vista `productos_publicos`, que no incluye costos.
- Las ventas se registran con la función `registrar_venta`, que descuenta el inventario y no deja vender más unidades de las que hay.
