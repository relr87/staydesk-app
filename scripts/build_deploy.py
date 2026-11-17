"""Arma deploy/ (lo que publica Vercel) a partir del kit oficial de StayDesk 25.8.

Uso:  python3 scripts/build_deploy.py RUTA_DEL_KIT        (por ejemplo ../staydesk/deploy)

Único cambio al kit: la regla de seguridad (CSP, «connect-src») permite también el servidor del Nivel 2
(proyecto de Supabase staydesk-data). Se cambia en la etiqueta <meta> de index.html y en las configuraciones
de cada servidor web. Los <script> no se tocan, así que sus huellas SHA-256 de la CSP siguen valiendo.
Al final se regenera SHA256SUMS.txt."""
import hashlib, os, shutil, sys

OLD = "connect-src 'self' https://oztadhzdxeftzgpipgso.supabase.co"
NEW = "connect-src 'self' https://oztadhzdxeftzgpipgso.supabase.co https://jamailgolmlcyblzduqe.supabase.co"
PATCH = ['index.html', 'vercel.json', '_headers', '.htaccess', 'nginx-headers.conf', 'staticwebapp.config.json', 'web.config']

src = sys.argv[1] if len(sys.argv) > 1 else '../staydesk/deploy'
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'deploy')
if os.path.isdir(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst)

for name in PATCH:
    p = os.path.join(dst, name)
    t = open(p, encoding='utf8', newline='').read()
    n = t.count(OLD)
    assert n == 1, (name, n)            # cada archivo debe tener exactamente una CSP con la dirección anterior
    open(p, 'w', encoding='utf8', newline='').write(t.replace(OLD, NEW))
    print('CSP ampliada en', name)

sums = []
for name in sorted(os.listdir(dst)):
    if name == 'SHA256SUMS.txt' or not os.path.isfile(os.path.join(dst, name)):
        continue
    h = hashlib.sha256(open(os.path.join(dst, name), 'rb').read()).hexdigest()
    sums.append(f'{h}  {name}')
open(os.path.join(dst, 'SHA256SUMS.txt'), 'w', encoding='utf8', newline='\n').write('\n'.join(sums) + '\n')
print('SHA256SUMS.txt regenerado:', len(sums), 'archivos')
