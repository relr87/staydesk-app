# Prueba en vivo · Nivel 2

App: **https://staydesk-app.vercel.app** (StayDesk 25.8) · Base: Supabase `staydesk-data`.

## 0. Una sola vez: vincular los equipos (≈ 2 min)

1. **Código de conexión.** En Supabase (`staydesk-data` → SQL Editor):
   ```sql
   insert into sd_codes(code, hotel_id, expires_at)
   values (sd_newcode(), '5d5d0000-0000-4000-8000-000000000001', now() + interval '1 day')
   returning code;
   ```
2. **Laptop.** Abre la app, entra como gerente y activa *Modo de trabajo → Solo operaciones*. Abre
   **Servidor del hotel** y llena:
   - Dirección: `https://jamailgolmlcyblzduqe.supabase.co`
   - Clave pública (anon): `sb_publishable_jUpCz5dHJuF5DdscvZpbgA_y0N_rp7m`. Es pública: con ella no se puede leer
     ninguna tabla, solo llamar a las funciones de la app.
   - Código: el del paso 1.

   Al conectar, la app descarga las 173 habitaciones, los 21 tickets y las 40 llegadas del servidor.
3. **Teléfono.** En la laptop, en **Servidor del hotel → Generar código para otro equipo**, comparte el enlace de invitación
   y ábrelo en el teléfono (o escanea su QR).

## 1. Crear en el teléfono y verlo en la laptop

En el teléfono, marca la **209** como LISTA o crea un ticket de mantenimiento. En 1 o 2 segundos aparece en la laptop.
Para comprobarlo en la base: `select * from rooms where number = 209;`.

## 2. Guardar algo inválido sin la validación del navegador

En la laptop, abre la consola del navegador (F12 → Console) y pega esto. Usa el propio token del equipo:

```js
const S = JSON.parse(localStorage.getItem('staydesk.sync'));
const push = data => fetch(S.url + '/rest/v1/rpc/sd_push', {method: 'POST',
  headers: {'Content-Type': 'application/json', apikey: S.key, Authorization: 'Bearer ' + S.key},
  body: JSON.stringify({p_device: S.dev, p_staff: 'demo', p_ops: [{op: 'demo-' + Date.now(), key: 'ar:9001', base: 0, data}]})
}).then(r => r.json()).then(r => console.log(JSON.stringify(r.results)));
push({id: 9001, n: 'Prueba Inválida', noches: 0, type: 'SXBL', done: false});
```

Respuesta esperada: `error: "invalid"`, con el motivo *violates check constraint "arrivals_nights_check"*. La llegada no se guarda
y el teléfono nunca la recibe. Con `noches: 2` y otro número de ficha (`ar:9002`), el servidor la acepta y aparece en el teléfono.

## 3. Buscar y filtrar

En **Habitaciones**, escribe `21` en el buscador; luego usa las pastillas «Vacantes sucias», «Mantenimiento»… y «Todos los tipos».

## 4. Borrar con confirmación

En **Reservaciones / Llegadas**, elige una llegada y pulsa **Cancelar**. La app pregunta «¿Cancelar esta reservación?».
Al confirmar, la ficha se borra en el servidor y la fila sale de la tabla `arrivals`.

## 5. Explicar una relación

`maintenance_tickets.room_number → rooms.number`, dentro del mismo hotel: un ticket solo puede existir para una habitación
que existe. Si se borra la habitación, se borran sus tickets (`on delete cascade`). Un ticket para la 999 se rechaza.
Ver el diagrama en el README.

## 6. No hay claves en el repo

- `git grep -n "sb_secret"` solo encuentra el README, que dice que no se usa.
- La clave secreta de Supabase no se usa en esta versión. La pública no da acceso a las tablas. Prueba:
  `fetch('https://jamailgolmlcyblzduqe.supabase.co/rest/v1/rooms?select=number', {headers: {apikey: KEY, Authorization: 'Bearer ' + KEY}})`
  devuelve `[]`.
