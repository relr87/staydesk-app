# StayDesk · kit de instalación (versión 25.8)

**Español** · [English below](#english)

StayDesk es una aplicación web de operación hotelera (recepción, housekeeping, mantenimiento, chat con huéspedes) en un solo archivo, pensada para hoteles de **Florida** (dólares, impuesto del condado, horario del Este o del Centro, español e inglés). Este kit la deja lista para publicar en su propio dominio, instalarla en celulares y computadoras y abrirla **sin Internet**.

> **Importante, sea honesto con su equipo:** esta versión es un prototipo de alta fidelidad para **un hotel**. Los datos se guardan en cada dispositivo (navegador) y los PIN se revisan en el propio dispositivo. Sin más, cada equipo trabaja solo. Desde la versión 25.2 existe un **servidor del hotel opcional** (vea «Servidor del hotel» más abajo): comparte la operación entre equipos y deja que el huésped chatee desde su celular, pero **todavía no sincroniza el dinero** (folios, caja). Inicio de sesión corporativo (SSO), conexión directa al PMS y certificaciones (SOC 2, PCI) siguen pendientes y necesitan la parte de servidor descrita en el plan de implementación.

## Qué trae

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La aplicación (un solo archivo, sin pedir nada a Internet: letras e íconos van dentro). Ya trae su política de seguridad (CSP) hecha a la medida. |
| `sw.js` | Guarda la página en el dispositivo para que abra rápido y sin Internet, y avisa cuando hay una versión nueva. |
| `_headers` | Cabeceras de seguridad para **Netlify** y **Cloudflare Pages**. |
| `vercel.json` | Lo mismo para **Vercel**. |
| `staticwebapp.config.json` | Lo mismo para **Azure Static Web Apps**. |
| `.htaccess` | Lo mismo para **Apache**. |
| `nginx.conf.example` + `nginx-headers.conf` | Lo mismo para **nginx**. |
| `web.config` | Lo mismo para **IIS**. |
| `SHA256SUMS.txt`, `VERSION.txt` | Para comprobar que los archivos no cambiaron. |

Aparte del kit (no lo suba a la web) va **`staydesk_firmar.py`**, la herramienta para TI que revisa y, si hace falta, actualiza la política de seguridad en los 7 archivos a la vez (vea «Si hay que cambiar index.html»).

## Publicarla en 10 minutos

1. **Netlify / Cloudflare Pages / Vercel / Azure (lo más fácil):** cree un sitio nuevo y suba (o arrastre) la carpeta completa. Ya incluyen HTTPS y compresión. Las cabeceras se aplican solas con el archivo de su servicio.
2. **Servidor propio (nginx, Apache, IIS):** copie los archivos a la carpeta web, active **HTTPS** y use el archivo de configuración de su servidor (`nginx.conf.example`, `.htaccess` o `web.config`).
3. **GitHub Pages:** suba la carpeta. No permite cabeceras propias; funciona porque la política de seguridad también está dentro de `index.html`.
4. **Un solo equipo, sin servidor:** abra `index.html` con doble clic. Funciona, pero sin la instalación sin Internet (los navegadores no permiten el servicio de guardado en archivos locales).

## Instalarla en celulares y computadoras

Abra la dirección en **Chrome o Edge** (menú → «Instalar app») o en **Safari del iPhone/iPad** (Compartir → «Agregar a pantalla de inicio»). Necesita **HTTPS** (o `localhost`).

## Sin Internet y actualizaciones

* Abra la app **una vez con Internet**; desde ese momento abre también sin conexión (los datos del hotel no dependen de Internet).
* Para actualizar: reemplace `index.html` y `sw.js` por los nuevos. La próxima vez que alguien abra la app con Internet se descarga en segundo plano y aparece el aviso «Hay una versión nueva…»; al cerrar y abrir ya usa la nueva. Una página que no sea de StayDesk (por ejemplo la de acceso al Wi-Fi del hotel) nunca reemplaza a la guardada.

## Lo que NO debe hacer

* **No edite `index.html` a mano.** La política de seguridad usa huellas (SHA-256) del código de ese archivo exacto, y esas huellas están copiadas en 7 archivos; si cambia una letra del código, el navegador bloquea la app. Todo se configura dentro de la app (nombre del hotel, moneda, impuesto, zona horaria, habitaciones, personal…) con **Configurar mi hotel** en la pantalla de entrada y, después, en **Usuarios → Mi hotel**.
* No ponga la app dentro de otra página (cabecera `frame-ancestors 'none'`).

## Si hay que cambiar index.html (solo TI)

Use la herramienta `staydesk_firmar.py` (necesita Python 3, sin nada más que instalar). Nunca cambia el código de la app, solo el texto de la política de seguridad y `SHA256SUMS.txt`.

* `python3 staydesk_firmar.py revisar CARPETA_DEL_KIT` solo mira y dice si las huellas, la versión y las sumas cuadran en los 7 archivos.
* `python3 staydesk_firmar.py firmar CARPETA_DEL_KIT` recalcula las huellas, las escribe en los 7 archivos y rehace `SHA256SUMS.txt`. Antes guarda una copia de lo que cambia en una carpeta `staydesk-respaldo-firmar-<fecha>` **al lado** del kit (no dentro, para que no se publique).
* Si cambia el servidor del hotel: `… firmar CARPETA_DEL_KIT --servidor https://su-proyecto.supabase.co`. Para que la app no hable con ningún servidor: `… firmar CARPETA_DEL_KIT --sin-servidor`.

Después de firmar, publique **todos** los archivos juntos (no solo `index.html`) y haga la lista de verificación.

## Servidor del hotel (opcional)

* Sin servidor, cada equipo trabaja solo y nada sale del dispositivo.
* Con servidor (un proyecto de Supabase), los equipos comparten la operación: habitaciones, asignaciones, limpieza, órdenes de mantenimiento, pedidos, llegadas, horas del personal y el chat con huéspedes. El dinero (folios, caja) **no** se sincroniza todavía. Sin Internet, los cambios esperan en el equipo y se envían al volver.
* Se activa en **Usuarios → Mi hotel**: primero **Modo de trabajo → Solo operaciones** y después **Servidor del hotel** (solo la gerencia). Desde ahí se generan códigos para conectar otros equipos y el enlace para que el huésped chatee desde su celular.
* La política de seguridad solo deja hablar con **un** servidor. Este kit trae permitido `https://oztadhzdxeftzgpipgso.supabase.co`. Si su hotel usa otro proyecto, cámbielo con `staydesk_firmar.py --servidor` (vea arriba); si no, la app no podrá conectarse.
* La parte del servidor (`server/`, con su `LEEME.md` y las migraciones de la base de datos) **no viene en este kit**; pídala junto con el plan de implementación.

## Lista de verificación para TI (10 minutos)

1. `https://su-dominio/` abre con candado (HTTPS).
2. `curl -I https://su-dominio/` muestra `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`.
3. Consola del navegador (F12) sin mensajes «Refused to…» al entrar, navegar y abrir ventanas.
4. F12 → Application → Service Workers: `sw.js` en estado *activated*.
5. Modo avión (o «Offline» en F12) y recargar: la app abre y deja iniciar sesión.
6. `python3 staydesk_firmar.py revisar CARPETA_DEL_KIT` termina con «Todo cuadra» y muestra el servidor del hotel que corresponde (o «ninguno»).
7. En la app: **Ayuda (?) → Acerca de** muestra la versión; **Usuarios → Copias de seguridad → Descargar copia ahora** guarda una copia de los datos en un archivo.

## Venta de alcohol (ley de Florida)

La app sigue la ley de Florida en cada cargo de alcohol a una habitación o a una cuenta de la casa:

* **Quién vende (cap. 562.13):** una persona menor de 18 años no puede vender alcohol; la app no se lo deja hacer. De 18 años en adelante sí puede. Por eso el personal de Front Desk necesita la fecha de nacimiento en su ficha; mientras falte, gerencia autoriza esas ventas con su PIN.
* **A quién (cap. 562.11):** no se vende alcohol a menores de 21. Antes de cada cargo, la persona que vende revisa con cuidado una identificación aceptada (licencia de conducir, identificación estatal, pasaporte o ID militar de EE. UU.), escribe la fecha de nacimiento que trae y confirma que es válida y que la foto coincide. Si el comprador tiene menos de 21, la app no deja hacer el cargo. La fecha del comprador solo sirve para calcular la edad: **no se guarda**. En la bitácora queda qué identificación se revisó y quién vendió.
* **Cómo sabe que es alcohol:** por el nombre del cargo (cerveza, vino, licores, cócteles y marcas comunes) o porque en la cuenta de la casa se marca **Es bebida con alcohol**. Si su hotel vende alcohol con otro nombre (por ejemplo, el minibar), póngale **(alcohol)** en el nombre al configurar los cargos rápidos: `Minibar (alcohol): 12`.
* Esto no reemplaza la licencia de bebidas del hotel ni la capacitación del personal. Confirme las reglas de su licencia con su asesor o con la División de Bebidas Alcohólicas y Tabaco de Florida.

## Datos y privacidad

* La app **no envía nada a terceros** (no hay estadísticas, anuncios, letras externas ni mapas). Solo si la gerencia conecta el **servidor del hotel**, los datos de operación y el chat con huéspedes van a ese servidor, y a ningún otro (la política de seguridad lo impide).
* Cada dispositivo guarda lo suyo en el navegador. **Borrar los datos del navegador borra los datos de StayDesk**: baje una copia cada día (**Usuarios → Copias de seguridad → Descargar copia ahora**) y guarde el archivo fuera del navegador.
* Safari borra los datos de sitios que no se usan en 7 días si la app no está instalada en la pantalla de inicio: instálela.
* **Datos personales (ley de Florida, FIPA):** el navegador guarda los datos **sin cifrar**. Si el hotel guarda nombres junto con números de licencia de conducir, de pasaporte o de tarjeta, la ley exige protegerlos y avisar de una filtración dentro de 30 días; para un piloto, no guarde números de documento ni de tarjeta y consulte a su asesor. Con el servidor del hotel conectado, nombres de huéspedes, habitaciones y mensajes del chat también quedan en ese servidor: inclúyalo en la misma revisión.
* **Temporada de huracanes (1 de junio al 30 de noviembre):** la app abre sin Internet después de la primera visita, pero sin Internet no sincroniza equipos (aunque haya servidor, los cambios esperan en cada equipo) y la copia diaria no sale sola del dispositivo. Antes de una tormenta cargue los equipos, baje una copia en archivo e imprima la hoja de asignación.

## Soporte

**Ayuda (?) → Acerca de → Copiar información para soporte** copia la versión, el navegador y el estado de los datos, sin datos de huéspedes.

---

<a id="english"></a>

# StayDesk · install kit (version 25.8)

StayDesk is a single-file hotel operations web app (front desk, housekeeping, maintenance, guest chat) built for **Florida** hotels (US dollars, county tax, Eastern or Central time, Spanish and English). This kit makes it ready to host on your own domain, install on phones and computers, and open **without Internet**.

> **Be straight with your team:** this version is a high-fidelity prototype for **one hotel**. Data is saved on each device (browser) and PINs are checked on the device itself. On its own, each device works alone. Since version 25.2 there is an **optional hotel server** (see "Hotel server" below) that shares operations across devices and lets guests chat from their own phone, but it **does not sync money yet** (folios, cash drawer). Corporate sign-in (SSO), a direct PMS connection and certifications (SOC 2, PCI) are still pending and need the server side described in the implementation plan.

## What is inside

`index.html` (the app, already carrying a tailor-made Content-Security-Policy) · `sw.js` (offline copy + update notice) · header files for Netlify/Cloudflare Pages (`_headers`), Vercel (`vercel.json`), Azure Static Web Apps (`staticwebapp.config.json`), Apache (`.htaccess`), nginx (`nginx.conf.example`, `nginx-headers.conf`) and IIS (`web.config`) · `SHA256SUMS.txt`, `VERSION.txt`. Delivered separately (do not upload it to the web): **`staydesk_firmar.py`**, the IT tool that checks and, when needed, updates the security policy in all 7 files at once.

## Publish in 10 minutes

1. **Netlify / Cloudflare Pages / Vercel / Azure (easiest):** create a site and upload the whole folder; HTTPS and compression come built in and the headers apply from your service's file.
2. **Your own server (nginx, Apache, IIS):** copy the files to the web folder, enable **HTTPS** and use your server's file.
3. **GitHub Pages:** upload the folder; it cannot set custom headers, but the policy is also inside `index.html`.
4. **One computer, no server:** double-click `index.html`. It works, but not the offline install (browsers do not allow the cache service on local files).

## Install and offline

Open the address in **Chrome/Edge** (menu → "Install app") or **iPhone/iPad Safari** (Share → "Add to Home Screen"); it needs **HTTPS** (or `localhost`). Open the app **once online**; after that it also opens offline. To update, replace `index.html` and `sw.js`; the next online visit downloads the new page in the background and shows "There is a new version…". A page that is not StayDesk (for example a hotel Wi-Fi sign-in page) never replaces the saved one.

## Do NOT

* **Do not hand-edit `index.html`:** the security policy uses SHA-256 hashes of that file's code, copied into 7 files; change one character of code and the browser blocks the app. Configure everything inside the app (hotel name, currency, tax, time zone, rooms, staff…) with **Set up my hotel** on the sign-in screen and, later, **Users → My hotel**.
* Do not embed the app in another page.

## If index.html must change (IT only)

Use `staydesk_firmar.py` (Python 3, nothing to install). It never changes the app's code, only the security policy text and `SHA256SUMS.txt`. `python3 staydesk_firmar.py revisar KIT_FOLDER` only checks hashes, version and checksums across the 7 files. `python3 staydesk_firmar.py firmar KIT_FOLDER` recomputes the hashes, writes them to the 7 files and rebuilds `SHA256SUMS.txt`, after saving a copy of what changes in a `staydesk-respaldo-firmar-<date>` folder **next to** the kit (not inside, so it is never published). Add `--servidor https://your-project.supabase.co` to change the allowed hotel server, or `--sin-servidor` so the app talks to no server. After signing, publish **all** the files together and run the checklist.

## Hotel server (optional)

Without a server each device works alone and nothing leaves it. With a server (a Supabase project) devices share operations: rooms, assignments, cleaning, maintenance orders, requests, arrivals, staff hours and guest chat. Money (folios, cash drawer) does **not** sync yet. Offline, changes wait on the device and are sent when it is back online. Turn it on in **Users → My hotel**: first **Work mode → Operations only**, then **Hotel server** (managers only); from there you create codes for other devices and the **Guest link** for chatting from a phone. The security policy allows **one** server only; this kit allows `https://oztadhzdxeftzgpipgso.supabase.co`. If your hotel uses another project, change it with `staydesk_firmar.py --servidor`, or the app cannot connect. The server side (`server/`, with its `LEEME.md` and database migrations) is **not included in this kit**; request it with the implementation plan.

## IT checklist (10 minutes)

HTTPS padlock · `curl -I` shows the security headers · browser console has no "Refused to…" messages · F12 → Application → Service Workers shows `sw.js` *activated* · airplane mode + reload still opens and signs in · `python3 staydesk_firmar.py revisar KIT_FOLDER` ends with "Todo cuadra" (all good) and shows the expected hotel server (or none) · **Help (?) → About** shows the version and **Users → Backups → Download backup now** saves a data file.

## Alcohol sales (Florida law)

Every alcohol charge to a room or a house account follows Florida law:

* **Who sells (s. 562.13):** a person under 18 cannot sell alcohol, and the app does not let them. Staff 18 and older can. Front Desk staff therefore need a date of birth in their profile; until it is added, a manager authorizes those sales with their PIN.
* **To whom (s. 562.11):** no alcohol to anyone under 21. Before each charge, the seller carefully checks an accepted ID (driver license, state ID card, passport or U.S. military ID), enters its date of birth and confirms it is valid and the photo matches. If the buyer is under 21, the app blocks the charge. The buyer's date of birth is only used to compute the age and **is not stored**; the log records which ID was checked and who sold.
* **How it knows it is alcohol:** by the charge name (beer, wine, liquor, cocktails and common brands) or because **This is an alcoholic drink** is ticked on a house account. If your hotel sells alcohol under another name (for example, the minibar), add **(alcohol)** to the name when you set up quick charges: `Minibar (alcohol): 12`.
* This does not replace the hotel's beverage license or staff training. Confirm your license rules with your adviser or the Florida Division of Alcoholic Beverages and Tobacco.

## Data and privacy

The app sends **nothing to third parties** (no analytics, ads, external fonts or maps). Only if a manager connects the **hotel server** do operations data and guest chat go to that server, and to no other (the security policy prevents it). Each device keeps its own data in the browser; **clearing browser data clears StayDesk data**, so download a backup every day (**Users → Backups → Download backup now**) and keep the file outside the browser. Safari clears data of sites unused for 7 days unless the app is installed on the home screen. **Florida law (FIPA):** the browser stores data **unencrypted**; if the hotel keeps names together with driver's license, passport or card numbers, the law requires protecting them and notifying a breach within 30 days, so for a pilot do not store document or card numbers and ask your adviser. With the hotel server connected, guest names, rooms and chat messages also live on that server: include it in the same review. **Hurricane season (June 1 to November 30):** the app opens offline after the first visit, but offline it does not sync devices (even with a server, changes wait on each device) and the daily backup does not leave the device on its own; before a storm charge the devices, download a backup file and print the assignment sheet.

## Support

**Help (?) → About → Copy support info** copies the version, browser and data state, without guest data.
