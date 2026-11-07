import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import '../aclaraciones/aclaraciones_screen.dart';
import '../catalogos/catalogo_screen.dart';
import '../catalogos/catalogos_defs.dart';
import '../configuracion/configuracion_screen.dart';
import '../cuenta/cuenta_screen.dart';
import '../incidencias/incidencias_screen.dart';
import '../movimientos/movimientos_screen.dart';
import '../nomina/calculadora_isr_screen.dart';
import '../nomina/historial_nominas_screen.dart';
import '../nomina/nomina_screen.dart';
import '../portal/mis_recibos_screen.dart';
import '../portal/mis_solicitudes_screen.dart';
import '../roles/roles_screen.dart';
import '../solicitudes/solicitudes_screen.dart';
import 'inicio_screen.dart';

/// Opción del menú lateral. Solo se muestra si el usuario tiene alguno de
/// los [privilegios] (lista vacía = visible para todos).
class _NavItem {
  final String id;
  final String section;
  final String title;
  final IconData icon;
  final List<String> privilegios;
  final Widget Function() build;
  const _NavItem(this.id, this.section, this.title, this.icon, this.privilegios, this.build);
}

/// Estructura principal: barra superior + menú lateral según el rol (RDF0103).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _actual = 'inicio';

  late final List<_NavItem> _todos = [
    _NavItem('inicio', 'General', 'Inicio', Icons.dashboard_outlined, const [],
        () => InicioScreen(onNavegar: _irA)),
    _NavItem('usuarios', 'Administración', 'Catálogo de Usuarios', Icons.people_outline, const ['usuarios'],
        () => CatalogoScreen(def: usuariosDef)),
    _NavItem('roles', 'Administración', 'Roles y Privilegios', Icons.admin_panel_settings_outlined,
        const ['usuarios'], () => const RolesScreen()),
    _NavItem('configuracion', 'Administración', 'Configuración Fiscal', Icons.tune, const ['configuracion'],
        () => const ConfiguracionScreen()),
    _NavItem('empleados', 'Catálogos', 'Catálogo de Empleados', Icons.badge_outlined, const ['empleados'],
        () => CatalogoScreen(def: empleadosDef)),
    _NavItem('departamentos', 'Catálogos', 'Catálogo de Departamentos', Icons.apartment_outlined,
        const ['catalogos'], () => CatalogoScreen(def: departamentosDef)),
    _NavItem('horarios', 'Catálogos', 'Catálogo de Horarios', Icons.schedule, const ['catalogos'],
        () => CatalogoScreen(def: horariosDef)),
    _NavItem('periodos', 'Catálogos', 'Catálogo de Periodos', Icons.date_range_outlined, const ['catalogos'],
        () => CatalogoScreen(def: periodosDef)),
    _NavItem('conceptos', 'Catálogos', 'Conceptos de Nómina', Icons.receipt_outlined, const ['catalogos'],
        () => CatalogoScreen(def: conceptosDef)),
    _NavItem('festivos', 'Catálogos', 'Días Festivos', Icons.celebration_outlined, const ['catalogos'],
        () => CatalogoScreen(def: festivosDef)),
    _NavItem('nomina', 'Nómina', 'Nómina por Periodo', Icons.payments_outlined, const ['nomina', 'recibos'],
        () => const NominaScreen()),
    _NavItem('percepciones', 'Nómina', 'Percepciones', Icons.add_circle_outline, const ['percepciones'],
        () => const MovimientosScreen(inicial: 'percepcion')),
    _NavItem('deducciones', 'Nómina', 'Deducciones y Préstamos', Icons.remove_circle_outline,
        const ['deducciones'], () => const MovimientosScreen(inicial: 'deduccion')),
    _NavItem('calculadora', 'Nómina', 'Calculadora de ISR', Icons.calculate_outlined, const ['nomina'],
        () => const CalculadoraIsrScreen()),
    _NavItem('historial', 'Nómina', 'Historial de Nóminas', Icons.history, const ['nomina', 'recibos'],
        () => const HistorialNominasScreen()),
    _NavItem('aclaraciones', 'Nómina', 'Aclaraciones de Recibos', Icons.question_answer_outlined,
        const ['recibos'], () => const AclaracionesScreen()),
    _NavItem('vacaciones', 'Personal', 'Vacaciones y Permisos', Icons.beach_access_outlined,
        const ['vacaciones'], () => const SolicitudesScreen()),
    _NavItem('incidencias', 'Personal', 'Faltas e Incapacidades', Icons.event_busy_outlined,
        const ['incidencias'], () => const IncidenciasScreen()),
    _NavItem('mis_recibos', 'Mi espacio', 'Mi Recibo de Nómina', Icons.receipt_long_outlined, const ['portal'],
        () => const MisRecibosScreen()),
    _NavItem('mis_solicitudes', 'Mi espacio', 'Mis Vacaciones y Permisos', Icons.event_available_outlined,
        const ['portal'], () => const MisSolicitudesScreen()),
    _NavItem('cuenta', 'Mi espacio', 'Mi Cuenta', Icons.manage_accounts_outlined, const [],
        () => const CuentaScreen()),
  ];

  List<_NavItem> get _items =>
      [for (final i in _todos) if (i.privilegios.isEmpty || session.puedeAlguno(i.privilegios)) i];

  void _irA(String id) {
    if (_items.any((i) => i.id == id)) setState(() => _actual = id);
  }

  Future<void> _cerrarSesion() async {
    final ok = await confirmar(context,
        titulo: 'Cerrar sesión', mensaje: '¿Deseas salir de NomiGest?', aceptar: 'Cerrar sesión');
    if (ok) await session.cerrar();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final current = items.firstWhere((i) => i.id == _actual, orElse: () => items.first);
    return Scaffold(
      appBar: AppBar(title: Text(current.title)),
      drawer: _buildDrawer(context, items, current),
      body: KeyedSubtree(key: ValueKey(current.id), child: current.build()),
    );
  }

  Widget _buildDrawer(BuildContext context, List<_NavItem> items, _NavItem current) {
    final tiles = <Widget>[];
    String? lastSection;
    for (final item in items) {
      if (item.section != lastSection) {
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 16, 4),
          child: Text(item.section.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: NomiColors.text3)),
        ));
        lastSection = item.section;
      }
      final selected = item.id == current.id;
      tiles.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ListTile(
          selected: selected,
          selectedTileColor: NomiColors.blueBg,
          shape: const StadiumBorder(),
          dense: true,
          leading: Icon(item.icon, color: NomiColors.blue, size: 22),
          title: Text(item.title,
              style: TextStyle(
                  fontSize: 14,
                  color: NomiColors.text1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          onTap: () {
            setState(() => _actual = item.id);
            Navigator.of(context).pop();
          },
        ),
      ));
    }

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
                colors: [NomiColors.navy, NomiColors.blue],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NomiLogo(size: 60),
                const SizedBox(height: 12),
                Text(session.nombreUsuario, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('Rol: ${session.rol}', style: const TextStyle(fontSize: 13, color: NomiColors.text2)),
              ],
            ),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 8), children: tiles)),
          const Divider(height: 1, color: NomiColors.stroke),
          ListTile(
            leading: const Icon(Icons.logout, color: NomiColors.text3),
            title: const Text('Cerrar sesión', style: TextStyle(color: NomiColors.text2, fontSize: 14)),
            onTap: () {
              Navigator.of(context).pop();
              _cerrarSesion();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
