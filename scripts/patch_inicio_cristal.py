"""Aplica el «Inicio de cristal» a deploy/ (después de build_deploy.py).

Uso:  python3 scripts/patch_inicio_cristal.py

Qué hace:
* agrega a deploy/index.html un <style> y un <script> nuevos (scripts/inicio_cristal/*.css y *.js), solo para la pantalla de entrada:
  tarjeta de cristal con luz en el borde, luz alrededor del campo del ID y del PIN, y el botón «Entrar» atado que escapa
  mientras falta el dato. La lógica del ID, del PIN, los bloqueos por intentos y los mensajes no cambian.
* suma la huella SHA-256 de ese <style> y de ese <script> a la regla de seguridad (CSP) en index.html y en las configuraciones
  de cada servidor web, sin quitar ni aflojar nada de lo que ya había.
* regenera SHA256SUMS.txt.
Se puede correr varias veces: si el parche ya está, lo reemplaza por la versión actual de los archivos."""
import base64, hashlib, os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
DEP = os.path.join(ROOT, 'deploy')
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'inicio_cristal')
CFG = ['index.html', 'vercel.json', '_headers', '.htaccess', 'nginx-headers.conf', 'staticwebapp.config.json', 'web.config']
STYLE_ID, SCRIPT_ID = 'lx-inicio-cristal', 'lx-inicio-cristal-js'

def h(text):
    return "'sha256-" + base64.b64encode(hashlib.sha256(text.encode('utf8')).digest()).decode() + "'"

css = open(os.path.join(SRC, 'inicio_cristal.css'), encoding='utf8').read()
js = open(os.path.join(SRC, 'inicio_cristal.js'), encoding='utf8').read()
hs, hj = h(css), h(js)

p = os.path.join(DEP, 'index.html')
t = open(p, encoding='utf8', newline='').read()
# quitar un parche anterior (y sus huellas) antes de poner el nuevo
old = re.findall(r'<style id="%s">(.*?)</style>' % STYLE_ID, t, re.S) + re.findall(r'<script id="%s">(.*?)</script>' % SCRIPT_ID, t, re.S)
olds = [h(x) for x in old]
t = re.sub(r'<style id="%s">.*?</style>' % STYLE_ID, '', t, flags=re.S)
t = re.sub(r'<script id="%s">.*?</script>' % SCRIPT_ID, '', t, flags=re.S)
assert t.count('</head>') >= 1 and t.count('</body>') >= 1
i = t.index('</head>')
t = t[:i] + '<style id="%s">%s</style>' % (STYLE_ID, css) + t[i:]
j = t.rindex('</body>')
t = t[:j] + '<script id="%s">%s</script>' % (SCRIPT_ID, js) + t[j:]
open(p, 'w', encoding='utf8', newline='').write(t)
print('index.html: estilo y script del inicio de cristal agregados')

for name in CFG:
    f = os.path.join(DEP, name)
    if not os.path.isfile(f):
        continue
    s = open(f, encoding='utf8', newline='').read()
    for o in olds:
        s = s.replace(' ' + o, '')
    n1 = len(re.findall(r"style-src-elem 'sha256-", s))
    n2 = len(re.findall(r"script-src 'sha256-", s))
    assert n1 == 1 and n2 == 1, (name, n1, n2)     # una sola CSP por archivo
    s = re.sub(r"(style-src-elem )('sha256-)", r"\1" + hs + r" \2", s)
    s = re.sub(r"(script-src )('sha256-)", r"\1" + hj + r" \2", s)
    open(f, 'w', encoding='utf8', newline='').write(s)
    print('CSP con las huellas nuevas en', name)

sums = []
for name in sorted(os.listdir(DEP)):
    if name == 'SHA256SUMS.txt' or not os.path.isfile(os.path.join(DEP, name)):
        continue
    sums.append(hashlib.sha256(open(os.path.join(DEP, name), 'rb').read()).hexdigest() + '  ' + name)
open(os.path.join(DEP, 'SHA256SUMS.txt'), 'w', encoding='utf8', newline='\n').write('\n'.join(sums) + '\n')
print('SHA256SUMS.txt regenerado:', len(sums), 'archivos')
