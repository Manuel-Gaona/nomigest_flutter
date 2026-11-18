# NomiGest (Flutter)

Aplicación móvil de gestión de nómina. Consume la API Flask de `../nomigest_back`.

## Ejecutar

1. Levante la API (ver `../nomigest_back/README.md`):
   ```powershell
   cd ..\nomigest_back
   .venv\Scripts\activate
   flask db upgrade; flask seed; flask demo
   python wsgi.py
   ```
2. Ejecute la app:
   ```powershell
   flutter pub get
   flutter run
   ```
3. Inicie sesión con `admin / admin12345`, `rh / rh123456` o un empleado
   (`lhernandez / empleado123`, PIN `1234`).

**Servidor:** por defecto la app usa `http://10.0.2.2:5000` en el emulador de Android y
`http://127.0.0.1:5000` en escritorio/web. En un teléfono físico toque el engrane de la
pantalla de inicio de sesión y escriba `http://<IP de su PC>:5000` (la PC y el teléfono en
la misma red, y el puerto 5000 permitido en el firewall).

> En Windows, compilar con plugins (`shared_preferences`) requiere activar el *Modo de
> desarrollador* (`start ms-settings:developers`).

## Estructura

```
lib/
  main.dart                 Arranque, idioma es_MX, sesión → login o menú
  core/
    api_client.dart         Cliente HTTP único (token, errores → ApiException)
    session.dart            Usuario en sesión, privilegios, login/logout
    app_config.dart         URL por defecto del servidor
    json.dart               Lectura segura del JSON (str, numero, entero, lista...)
    formatters.dart         Moneda, fechas
  services/                 Un archivo por módulo de la API
    crud_service.dart       CRUD genérico + instancias por catálogo
    catalogos_service.dart  Listas para formularios, periodos, festivos, tablero
    nomina_service.dart     Nómina por periodo, recibos, aclaraciones
    portal_service.dart     Portal del empleado, aprobación de solicitudes
    configuracion_service.dart, cuenta_service.dart
  widgets/
    nomi_widgets.dart       Componentes de diseño (NomiCard, NomiField, NomiSelect,
                            RecordTile, StatusBadge, KpiTile...)
    formulario.dart         FormularioScreen: alta/edición a partir de CampoDef
    feedback.dart           Mensajes, confirmaciones, Carga (loading/error/reintentar)
  screens/
    auth/                   Login, recuperar contraseña, servidor
    home/                   Menú lateral por privilegios e Inicio (pendientes)
    catalogos/              Lista genérica + definiciones: usuarios, empleados,
                            departamentos, horarios, periodos, conceptos, festivos
    roles/                  Roles y privilegios
    movimientos/            Percepciones, deducciones e Infonavit
    nomina/                 Nómina por periodo, recibo (RH), calculadora ISR, historial
    aclaraciones/           Dudas de empleados sobre recibos
    solicitudes/            Vacaciones y permisos (RH)
    incidencias/            Faltas e incapacidades
    portal/                 Mis recibos, firma con PIN, mis solicitudes
    configuracion/          Empresa, parámetros fiscales, tarifa ISR
    cuenta/                 Contraseña, PIN, cerrar sesión
theme/nomi_theme.dart       Paleta y tema oscuro
```

### Agregar un catálogo nuevo

1. Servicio: `const xService = CrudService('/x');` en `services/crud_service.dart`.
2. Definición: un `CatalogoDef` en `screens/catalogos/catalogos_defs.dart` con sus
   `CampoDef` (tipos: texto, entero, decimal, password, seleccion, fecha, hora, booleano,
   multilinea, diasSemana).
3. Opción de menú en `screens/home/home_shell.dart` con el privilegio que la habilita.

La lista (búsqueda, inactivos, alta con botón flotante) y el formulario (validación,
errores del servidor por campo, baja lógica y reactivación) se generan solos.

## Pantallas por rol

| Rol | Menú |
|---|---|
| Administrador | Todo |
| Recursos Humanos | Empleados, catálogos, percepciones, deducciones, nómina, recibos y aclaraciones, vacaciones, faltas |
| Contabilidad | Percepciones, deducciones, nómina, recibos, configuración fiscal |
| Empleado | Mi recibo (firma con PIN / tengo dudas), mis vacaciones y permisos, mi cuenta |

Los privilegios de cada rol se cambian en *Roles y Privilegios*; el menú se actualiza al
volver a iniciar sesión.

## Pruebas

```powershell
flutter analyze
flutter test
```

`test/pantallas_test.dart` recorre todas las pantallas en tamaño de teléfono con respuestas
reales de la API (`test/fixtures/api_respuestas.json`) y falla ante excepciones o
desbordes. Regenere el JSON cuando cambie la API (instrucciones en el archivo de prueba).
