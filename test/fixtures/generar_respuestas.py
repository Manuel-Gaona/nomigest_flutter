"""Genera respuestas reales de la API para la prueba de humo de Flutter (test/pantallas_test.dart).

Ejecutar desde la carpeta nomigest_back:
    .venv/Scripts/python ../nomigest_flutter/test/fixtures/generar_respuestas.py \
        ../nomigest_flutter/test/fixtures/api_respuestas.json
"""
import json, sys
from datetime import date
sys.path.insert(0, '.')
from app import create_app
from app.config import TestConfig
from app.extensions import db
from app.cli import cargar_demo
from app.models import Periodo

app = create_app(TestConfig)
with app.app_context():
    db.create_all(); cargar_demo()
    c = app.test_client()
    def login(u, p):
        r = c.post('/api/auth/login', json={'nombre_usuario': u, 'password': p}).get_json()
        return r, {'Authorization': 'Bearer ' + r['access_token']}
    la, a = login('admin', 'admin12345'); le, e = login('lhernandez', 'empleado123')
    hoy = date.today()
    per = Periodo.query.filter(Periodo.tipo_periodo=='quincenal', Periodo.fecha_inicial<=hoy, Periodo.fecha_final>=hoy).first()
    c.post('/api/movimientos', headers=a, json={'empleado_id':1,'concepto_id':13,'periodo_id':per.id,'monto':100})
    c.post('/api/infonavit', headers=a, json={'empleado_id':1,'numero_credito':'123','tipo_descuento':'cuota_fija','valor_descuento':500,'fecha_inicio':'2025-01-01'})
    c.post('/api/incidencias', headers=a, json={'empleado_id':1,'tipo':'falta','fecha_inicial':hoy.isoformat(),'dias':1})
    c.post('/api/portal/solicitudes', headers=e, json={'tipo':'permiso_con_goce','fecha_inicial':'2027-03-02','fecha_final':'2027-03-02','motivo':'Trámite'})
    calculo = c.post('/api/nomina/calcular', headers=a, json={'periodo_id': per.id}).get_json()
    c.post('/api/nomina/publicar', headers=a, json={'periodo_id': per.id})
    rid = c.get('/api/portal/recibos', headers=e).get_json()['items'][0]['id']
    c.post(f'/api/portal/recibos/{rid}/aclaraciones', headers=e, json={'mensaje':'No veo mi bono de asistencia en este periodo.'})

    gets_admin = ['/api/opciones','/api/tablero','/api/usuarios','/api/roles','/api/roles/privilegios','/api/empleados','/api/empleados/1',
        '/api/empleados/1/saldo-vacaciones','/api/departamentos','/api/horarios','/api/periodos','/api/conceptos','/api/festivos',
        '/api/movimientos','/api/infonavit','/api/solicitudes','/api/incidencias','/api/nomina','/api/nomina/historial',
        f'/api/recibos/{rid}','/api/aclaraciones','/api/configuracion','/api/configuracion/parametros','/api/configuracion/tarifa-isr']
    gets_emp = ['/api/opciones','/api/tablero','/api/portal/perfil','/api/portal/recibos',f'/api/portal/recibos/{rid}','/api/portal/solicitudes']
    def capturar(headers, rutas, extra):
        datos = {}
        for ruta in rutas:
            q = '?tipo=deduccion' if ruta == '/api/movimientos' else (f'?periodo_id={per.id}' if ruta == '/api/nomina' else '')
            r = c.get(ruta + q, headers=headers); assert r.status_code == 200, ruta
            datos[ruta] = r.get_json()
        datos.update(extra)
        return datos
    fixture = {
        'admin': capturar(a, gets_admin, {'POST /api/auth/login': la, 'POST /api/nomina/calcular': calculo}),
        'empleado': capturar(e, gets_emp, {'POST /api/auth/login': le}),
    }
    json.dump(fixture, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('ok', len(fixture['admin']), len(fixture['empleado']))
