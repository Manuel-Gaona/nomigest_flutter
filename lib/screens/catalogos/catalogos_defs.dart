import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/catalogos_service.dart';
import '../../services/crud_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/formulario.dart';
import '../../widgets/nomi_widgets.dart';
import 'catalogo_screen.dart';

/// Definición de cada catálogo: campos del formulario y presentación en la lista.

final _soloDigitos = [FilteringTextInputFormatter.digitsOnly];

String? _min8(String v) => v.length < 8 ? 'Mínimo 8 caracteres.' : null;

final usuariosDef = CatalogoDef(
  singular: 'usuario',
  servicio: usuariosService,
  buscar: 'Buscar por usuario, rol o empleado...',
  privilegio: 'usuarios',
  icono: Icons.people_outline,
  campos: [
    const CampoDef('nombre_usuario', 'Nombre de usuario', icono: Icons.person_outline, maxLength: 60),
    const CampoDef('password', 'Contraseña',
        icono: Icons.lock_outline, tipo: TipoCampo.password, soloAlCrear: true, validar: _min8),
    CampoDef('rol_id', 'Rol',
        icono: Icons.admin_panel_settings_outlined, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.roles),
    CampoDef('empleado_id', 'Empleado vinculado (portal del empleado)',
        icono: Icons.badge_outlined,
        tipo: TipoCampo.seleccion,
        requerido: false,
        cargarOpciones: CatalogosService.empleados),
  ],
  tituloDe: (r) => r.str('nombre_usuario'),
  subtituloDe: (r) => ['Rol: ${r.str('rol')}', if (r['empleado'] != null) r.str('empleado')].join(' · '),
  insigniaDe: (r) => r.flag('solicita_restablecer') && r['activo'] != false
      ? const StatusBadge('Restablecer contraseña', NomiColors.amber, NomiColors.amberBg)
      : null,
);

final empleadosDef = CatalogoDef(
  singular: 'empleado',
  servicio: empleadosService,
  buscar: 'Buscar por nombre, número, RFC o departamento...',
  privilegio: 'empleados',
  icono: Icons.badge_outlined,
  valoresPorDefecto: const {'periodicidad_pago': 'quincenal'},
  campos: [
    const CampoDef.seccion('Datos personales'),
    const CampoDef('numero_empleado', 'Número de empleado', icono: Icons.tag, editable: false, maxLength: 20),
    const CampoDef('nombre', 'Nombre(s)', icono: Icons.person_outline),
    const CampoDef('apellido_paterno', 'Apellido paterno'),
    const CampoDef('apellido_materno', 'Apellido materno', requerido: false),
    const CampoDef('rfc', 'RFC', icono: Icons.fingerprint, requerido: false, maxLength: 13),
    const CampoDef('curp', 'CURP', requerido: false, maxLength: 18),
    CampoDef('nss', 'NSS (IMSS)', requerido: false, maxLength: 11, formatos: _soloDigitos),
    const CampoDef('email', 'Correo electrónico', icono: Icons.alternate_email, requerido: false),
    CampoDef('telefono', 'Teléfono', icono: Icons.phone_outlined, requerido: false, formatos: _soloDigitos),
    const CampoDef.seccion('Datos laborales'),
    CampoDef('departamento_id', 'Departamento',
        icono: Icons.apartment_outlined, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.departamentos),
    CampoDef('horario_id', 'Horario',
        icono: Icons.schedule, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.horarios),
    const CampoDef('puesto', 'Puesto', icono: Icons.work_outline, requerido: false),
    const CampoDef('fecha_ingreso', 'Fecha de ingreso', tipo: TipoCampo.fecha),
    CampoDef('periodicidad_pago', 'Periodicidad de pago',
        icono: Icons.date_range_outlined,
        tipo: TipoCampo.seleccion,
        cargarOpciones: () => CatalogosService.opciones('periodicidades')),
    const CampoDef('salario_diario', 'Salario diario (\$)', icono: Icons.attach_money, tipo: TipoCampo.decimal),
    const CampoDef('sdi', 'Salario diario integrado (\$)',
        icono: Icons.functions,
        tipo: TipoCampo.decimal,
        requerido: false,
        ayuda: 'Opcional: si se deja vacío se calcula con aguinaldo y prima vacacional.'),
    const CampoDef.seccion('Firma de recibos'),
    CampoDef('pin', 'PIN de 4 dígitos',
        icono: Icons.pin_outlined,
        tipo: TipoCampo.password,
        requerido: false,
        maxLength: 4,
        formatos: _soloDigitos,
        ayuda: 'Opcional. El empleado también puede crearlo desde su cuenta.',
        validar: (v) => v.length != 4 ? 'El PIN debe tener 4 dígitos.' : null),
  ],
  tituloDe: (r) => r.str('nombre_completo'),
  subtituloDe: (r) => '${r.str('numero_empleado')} · ${r.str('departamento')} · ${r.str('horario')}',
  extraFormulario: (context, r) => _SaldoVacaciones(r.entero('id')!),
);

final departamentosDef = CatalogoDef(
  singular: 'departamento',
  servicio: departamentosService,
  buscar: 'Buscar departamento...',
  icono: Icons.apartment_outlined,
  campos: const [
    CampoDef('nombre', 'Nombre del departamento', icono: Icons.apartment_outlined),
    CampoDef('descripcion', 'Descripción', icono: Icons.notes, tipo: TipoCampo.multilinea, requerido: false),
  ],
  tituloDe: (r) => r.str('nombre'),
  subtituloDe: (r) => r['descripcion'] == null ? 'ID: ${r.str('id').padLeft(2, '0')}' : r.str('descripcion'),
);

const _diasCortos = ['', 'L', 'M', 'Mi', 'J', 'V', 'S', 'D'];

final horariosDef = CatalogoDef(
  singular: 'horario',
  servicio: horariosService,
  buscar: 'Buscar horario...',
  icono: Icons.schedule,
  valoresPorDefecto: const {'dias_laborales': '1,2,3,4,5', 'horas_jornada': 8},
  campos: const [
    CampoDef('nombre_turno', 'Nombre del turno', icono: Icons.schedule),
    CampoDef('hora_entrada', 'Hora de entrada', icono: Icons.login, tipo: TipoCampo.hora),
    CampoDef('hora_salida', 'Hora de salida', icono: Icons.logout, tipo: TipoCampo.hora),
    CampoDef('horas_jornada', 'Horas de la jornada', icono: Icons.timelapse, tipo: TipoCampo.decimal,
        ayuda: 'Se usa para calcular el pago de horas extra.'),
    CampoDef('dias_laborales', 'Días laborales', tipo: TipoCampo.diasSemana),
  ],
  tituloDe: (r) => r.str('nombre_turno'),
  subtituloDe: (r) {
    final dias = r.str('dias_laborales').split(',').map((d) => _diasCortos[int.tryParse(d) ?? 0]).join(' ');
    return '${r.str('hora_entrada')} - ${r.str('hora_salida')} · $dias';
  },
);

final periodosDef = CatalogoDef(
  singular: 'periodo',
  servicio: periodosService,
  buscar: 'Buscar por tipo o año...',
  icono: Icons.date_range_outlined,
  valoresPorDefecto: const {'tipo_periodo': 'quincenal'},
  campos: [
    CampoDef('tipo_periodo', 'Tipo de periodo',
        icono: Icons.date_range_outlined,
        tipo: TipoCampo.seleccion,
        cargarOpciones: () => CatalogosService.opciones('periodicidades')),
    const CampoDef('fecha_inicial', 'Fecha inicial', tipo: TipoCampo.fecha),
    const CampoDef('fecha_final', 'Fecha final', tipo: TipoCampo.fecha),
    const CampoDef('fecha_pago', 'Fecha de pago', tipo: TipoCampo.fecha, requerido: false,
        ayuda: 'Si se deja vacía se usa la fecha final.'),
    const CampoDef('dias_pago', 'Días de pago', icono: Icons.numbers, tipo: TipoCampo.entero, requerido: false,
        ayuda: 'Por defecto: semanal 7, catorcenal 14, quincenal 15, mensual 30.'),
  ],
  tituloDe: (r) => r.str('nombre'),
  subtituloDe: (r) => 'Pago: ${fecha(r.str('fecha_pago'))} · ${r.str('dias_pago')} días',
  insigniaDe: (r) => r['activo'] == false
      ? StatusBadge.inactivo()
      : (r.str('estado') == 'cerrado'
          ? const StatusBadge('Cerrado', NomiColors.text2, Color(0x33CBD5E1))
          : StatusBadge.activo()),
  acciones: [AccionCatalogo('Generar', Icons.auto_awesome_outlined, _generarPeriodos)],
);

final conceptosDef = CatalogoDef(
  singular: 'concepto',
  servicio: conceptosService,
  buscar: 'Buscar por clave o nombre...',
  icono: Icons.receipt_outlined,
  valoresPorDefecto: const {'tipo': 'percepcion', 'gravable': true, 'tipo_calculo': 'importe'},
  campos: [
    const CampoDef('clave', 'Clave', icono: Icons.tag, maxLength: 10),
    const CampoDef('nombre', 'Nombre', icono: Icons.edit_note),
    CampoDef('tipo', 'Tipo',
        icono: Icons.swap_vert, tipo: TipoCampo.seleccion, cargarOpciones: () => CatalogosService.opciones('tipos_concepto')),
    CampoDef('tipo_calculo', 'Forma de cálculo',
        icono: Icons.calculate_outlined,
        tipo: TipoCampo.seleccion,
        cargarOpciones: () => CatalogosService.opciones('tipos_calculo')),
    const CampoDef('clave_sat', 'Clave SAT', icono: Icons.account_balance_outlined, requerido: false, maxLength: 3),
    CampoDef('gravable', 'Grava ISR',
        tipo: TipoCampo.booleano, requerido: false, visibleSi: (v) => v['tipo'] == 'percepcion'),
    CampoDef('fraccion_art110', 'Caso del art. 110 LFT',
        icono: Icons.gavel_outlined,
        tipo: TipoCampo.seleccion,
        requerido: false,
        visibleSi: (v) => v['tipo'] == 'deduccion',
        ayuda: 'Las deducciones solo pueden aplicarse si corresponden a una fracción.',
        cargarOpciones: () => CatalogosService.opciones('fracciones_art110')),
  ],
  tituloDe: (r) => '${r.str('clave')} · ${r.str('nombre')}',
  subtituloDe: (r) => [
    r.str('tipo') == 'percepcion' ? 'Percepción' : 'Deducción',
    if (r.str('tipo') == 'percepcion') r.flag('gravable') ? 'Gravable' : 'Exenta',
    if (r['clave_sat'] != null) 'SAT ${r.str('clave_sat')}',
    if (r['fraccion_art110'] != null) 'Art. 110 fr. ${r.str('fraccion_art110')}',
  ].join(' · '),
  insigniaDe: (r) => r.flag('es_sistema')
      ? const StatusBadge('Sistema', NomiColors.blue, NomiColors.blueBg)
      : StatusBadge.estatus(r['activo'] != false),
);

final festivosDef = CatalogoDef(
  singular: 'día festivo',
  servicio: festivosService,
  buscar: 'Buscar...',
  bajaLogica: false,
  icono: Icons.celebration_outlined,
  campos: const [
    CampoDef('fecha', 'Fecha', tipo: TipoCampo.fecha),
    CampoDef('descripcion', 'Descripción', icono: Icons.notes),
  ],
  tituloDe: (r) => fechaCorta(r.str('fecha')),
  subtituloDe: (r) => r.str('descripcion'),
  acciones: [AccionCatalogo('Cargar LFT', Icons.download_outlined, _cargarFestivos)],
);

Future<bool> _generarPeriodos(BuildContext context) async {
  String tipo = 'quincenal';
  int ejercicio = DateTime.now().year;
  final tipos = await CatalogosService.opciones('periodicidades');
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: NomiColors.card,
        title: const Text('Generar periodos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: spaced([
            const Text('Se crearán todos los periodos del año que aún no existan.',
                style: TextStyle(color: NomiColors.text2, fontSize: 13)),
            NomiSelect<String>('Tipo de periodo', [for (final t in tipos) (t.valor, t.texto)],
                value: tipo, onChanged: (v) => setState(() => tipo = v ?? tipo)),
            NomiSelect<int>('Ejercicio', [for (int a = ejercicio - 1; a <= ejercicio + 1; a++) (a, '$a')],
                value: ejercicio, onChanged: (v) => setState(() => ejercicio = v ?? ejercicio)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generar')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  final mensaje = await ejecutar(context, () => CatalogosService.generarPeriodos(tipo, ejercicio));
  if (mensaje != null && context.mounted) mostrarMensaje(context, mensaje);
  return mensaje != null;
}

Future<bool> _cargarFestivos(BuildContext context) async {
  final anio = DateTime.now().year;
  final mensaje = await ejecutar(context, () => CatalogosService.cargarFestivosLft(anio));
  if (mensaje != null && context.mounted) mostrarMensaje(context, mensaje);
  return mensaje != null;
}

/// Saldo de vacaciones del empleado (se muestra al editarlo).
class _SaldoVacaciones extends StatelessWidget {
  final int empleadoId;
  const _SaldoVacaciones(this.empleadoId);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Vacaciones (LFT art. 76)'),
        Carga<Json>(
          cargar: () => CatalogosService.saldoVacaciones(empleadoId),
          builder: (context, s, _) => NomiCard(
            child: Column(
              children: spaced([
                KvRow('Antigüedad', '${s.str('anios_servicio')} año(s)'),
                KvRow('Días por derecho', s.str('dias_derecho')),
                KvRow('Tomados / pendientes', '${s.str('dias_tomados')} / ${s.str('dias_pendientes')}'),
                KvRow('Disponibles', s.str('dias_disponibles'), color: NomiColors.emerald, bold: true),
                KvRow('Próximo aniversario', fecha(s.str('proximo_aniversario'))),
              ], 8),
            ),
          ),
        ),
      ],
    );
  }
}
