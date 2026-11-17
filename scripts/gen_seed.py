"""Genera supabase/seed.sql: datos de ejemplo INVENTADOS para StayDesk Demo Inn.
Usa la distribución real de habitaciones del hotel de ejemplo (número, piso, tipo); los huéspedes, estados,
tickets y llegadas son inventados. Determinista: siempre produce el mismo archivo."""
import json, os
LAYOUT = ("110:1:KXTD,111:1:KXTY,112:1:KXTD,113:1:KXTY,114:1:KXTD,115:1:KXTY,119:1:NKRQE,121:1:KXTY,123:1:SXBL,125:1:SXBL,127:1:SXBL,129:1:NDRQE,"
"200:2:SXBL,202:2:SXBL,203:2:SXBL,204:2:SXBL,205:2:SXBL,206:2:SXBL,207:2:SXBL,208:2:SXBL,209:2:SXBL,210:2:SXBL,211:2:SXBL,212:2:SXBL,213:2:SXBL,214:2:SXBL,215:2:SXBL,216:2:SXBL,217:2:SXBL,218:2:SXBL,219:2:NDRQD,220:2:SXBL,221:2:SXBL,222:2:SXBL,223:2:SXBL,224:2:SXBL,225:2:SXBL,227:2:SXBL,229:2:SXBL,"
"300:3:KXTD,302:3:KXTD,303:3:KXTY,304:3:KXTD,305:3:KXTY,306:3:KXTD,307:3:KXTY,308:3:KXTD,309:3:KXTY,310:3:KXTD,311:3:KXTY,312:3:SXBL,313:3:KXTY,314:3:KXTD,315:3:KXTY,316:3:KXTD,317:3:KXTD,318:3:KXTY,319:3:NKRQD,320:3:KXTD,321:3:SXBL,322:3:KXTD,323:3:KXTY,324:3:KXTD,325:3:SXBL,327:3:KXTY,329:3:SXBL,"
"400:4:SXBL,402:4:SXBL,403:4:SXBL,404:4:SXBL,405:4:SXBL,406:4:SXBL,407:4:SXBL,408:4:SXBL,409:4:SXBL,410:4:SXBL,411:4:SXBL,412:4:SXBL,413:4:SXBL,414:4:SXBL,415:4:SXBL,416:4:SXBL,417:4:SXBL,418:4:SXBL,419:4:NDRQD,420:4:SXBL,421:4:SXBL,422:4:KXTD,423:4:SXBL,424:4:SXBL,425:4:SXBL,427:4:SXBL,429:4:SXBL,"
"500:5:SXBL,502:5:SXBL,503:5:KXTY,504:5:KXTY,505:5:KXTY,506:5:SXBL,507:5:KXTY,508:5:SXBL,509:5:KXTY,510:5:KXTY,511:5:KXTY,512:5:SXBL,513:5:KXTY,514:5:KXTD,515:5:SXBL,516:5:SXBL,517:5:SXBL,518:5:SXBL,519:5:NKRQD,520:5:SXBL,521:5:SXBL,522:5:SXBL,523:5:SXBL,524:5:SXBL,525:5:KXTY,527:5:SXBL,529:5:KXTY,"
"600:6:SXBL,602:6:SXBL,603:6:SXBL,604:6:SXBL,605:6:SXBL,606:6:SXBL,607:6:SXBL,608:6:SXBL,609:6:SXBL,610:6:SXBL,611:6:SXBL,612:6:SXBL,613:6:SXBL,614:6:SXBL,615:6:SXBL,616:6:SXBL,617:6:SXBL,618:6:SXBL,619:6:NDRQD,620:6:SXBL,621:6:SXBL,622:6:SXBL,623:6:SXBL,624:6:SXBL,625:6:SXBL,627:6:SXBL,629:6:SXBL,"
"700:7:SXBL,702:7:SXBL,703:7:KXTY,704:7:SXBL,705:7:KXTY,706:7:SXBL,707:7:KXTY,708:7:SXBL,709:7:KXTY,710:7:SXBL,711:7:KXTY,712:7:KXTD,713:7:KXTY,715:7:KXTY,716:7:SXBL,717:7:KXTY,718:7:SXBL,719:7:NKRQD,720:7:SXBL,721:7:SXBL,722:7:SXBL,723:7:KXTD,724:7:SXBL,725:7:SXBL,727:7:KXTD,729:7:SXBL")
FIRST = ["Ana","Bruno","Camila","Diego","Elena","Felipe","Gabriela","Héctor","Irene","Jorge","Karla","Leonardo","Mariana","Nicolás","Olivia",
         "Pablo","Raquel","Samuel","Teresa","Ulises","Valeria","Walter","Ximena","Yago","Zoe","Grace","Henry","Chloe","Ethan","Mia"]
LAST = ["Alarcón","Benítez","Cárdenas","Duarte","Espinoza","Figueroa","Galindo","Herrera","Ibarra","Jaramillo","Lozano","Medina","Navarro",
        "Ochoa","Paredes","Quiroga","Rosales","Salazar","Tovar","Urrutia","Valdez","Zamora","Brennan","Caldwell","Donovan","Fletcher"]
ISS = ['Aire acondicionado','Plomería / fuga','Cerradura / llave','TV / WiFi','Luz / eléctrico','Otro']
DET = ['El equipo no enfría; el técnico revisa el compresor.','Fuga bajo el lavabo del baño.','La cerradura no lee la llave digital.',
       'Sin señal en la TV ni en el WiFi.','Falla en el circuito de luz del baño.','Cortina del baño rota.']
rooms, tickets, arrivals = [], [], []
name = lambda i: f"{FIRST[(i*7) % len(FIRST)]} {LAST[(i*11) % len(LAST)]}"
for i, it in enumerate(LAYOUT.split(',')):
    n, f, t = it.split(':'); n, f = int(n), int(f)
    k = (n * 3 + f * 5) % 23
    st = 'limpia' if k < 9 else 'ocupada' if k < 15 else 'sucia' if k < 19 else 'inspeccion' if k < 21 else 'mant'
    rooms.append({"id": n, "f": f, "type": t, "status": st, "guest": name(i) if st == 'ocupada' else '', "prio": k == 15, "dep": st == 'ocupada' and k == 14})
tid = 1
for r in rooms:
    if r['status'] == 'mant':
        j = tid - 1
        tickets.append({"id": tid, "room": r['id'], "issue": ISS[j % 5], "oos": True, "state": 'curso' if j % 3 == 0 else 'abierto',
                        "det": DET[j % 5], "due": 600 + (j * 47) % 600}); tid += 1
for r in [x for x in rooms if x['status'] == 'ocupada'][::6]:
    j = tid - 1
    tickets.append({"id": tid, "room": r['id'], "issue": ISS[(j + 3) % 6], "oos": False, "state": 'resuelto' if j % 2 else 'abierto',
                    "det": DET[(j + 3) % 6], "due": 700 + (j * 31) % 500}); tid += 1
types = [r['type'] for r in rooms]
for a in range(1, 41):
    fn, ln = FIRST[(a * 13) % len(FIRST)], LAST[(a * 5) % len(LAST)]
    m = 14 * 60 + (a * 15) % (8 * 60)
    arrivals.append({"id": a, "n": f"{fn} {ln}", "first": fn, "last": ln, "noches": 1 + a % 5, "adults": 1 + a % 3,
                     "hora": f"{m // 60:02d}:{m % 60:02d}", "type": types[(a * 17) % len(types)], "room": None, "pre": None,
                     "done": False, "conf": str(90000000 + a * 7919), "co": "", "rate": "BAR", "notes": "", "msg": "", "prepaid": 0, "warned": False})
ent = [("rm:%d" % r['id'], r) for r in rooms] + [("tk:%d" % t['id'], t) for t in tickets] + [("ar:%d" % a['id'], a) for a in arrivals]
q = lambda s: "'" + s.replace("'", "''") + "'"
rows = ",\n".join(f"  ({q(k)}, {q(json.dumps(d, ensure_ascii=False, separators=(',', ':')))}::jsonb)" for k, d in ent)
sql = f"""-- StayDesk · datos de ejemplo INVENTADOS (ningún huésped real). Generado por scripts/gen_seed.py.
-- {len(rooms)} habitaciones · {len(tickets)} tickets de mantenimiento · {len(arrivals)} llegadas = {len(ent)} registros.
-- Se puede volver a correr: borra y vuelve a llenar el hotel de ejemplo. Cada ficha pasa por las mismas reglas
-- de validación que los cambios de la app (trigger sd_project), así que si un dato no cumple, el script falla.

begin;

insert into public.sd_hotels (id, name) values ('5d5d0000-0000-4000-8000-000000000001', 'StayDesk Demo Inn · Orlando Int''l Dr.')
on conflict (id) do update set name = excluded.name;

delete from public.arrivals            where hotel_id = '5d5d0000-0000-4000-8000-000000000001';
delete from public.maintenance_tickets where hotel_id = '5d5d0000-0000-4000-8000-000000000001';
delete from public.rooms               where hotel_id = '5d5d0000-0000-4000-8000-000000000001';
delete from public.room_types          where hotel_id = '5d5d0000-0000-4000-8000-000000000001';
delete from public.sd_entities         where hotel_id = '5d5d0000-0000-4000-8000-000000000001';

insert into public.sd_entities (hotel_id, key, version, data, deleted, seq, staff)
select '5d5d0000-0000-4000-8000-000000000001', v.key, 1, v.data, false, nextval('public.sd_seq'), 'seed'
from (values
{rows}
) as v(key, data);

commit;

select (select count(*) from public.rooms) habitaciones, (select count(*) from public.room_types) tipos,
       (select count(*) from public.maintenance_tickets) tickets, (select count(*) from public.arrivals) llegadas;
"""
open(os.path.join(os.path.dirname(__file__), '..', 'supabase', 'seed.sql'), 'w', encoding='utf8').write(sql)
print(len(ent), 'registros;', len(rooms), 'hab', len(tickets), 'tk', len(arrivals), 'ar', len(sql), 'bytes')
