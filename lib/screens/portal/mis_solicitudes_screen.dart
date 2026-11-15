import 'package:flutter/material.dart';

import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/portal_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import '../solicitudes/solicitud_form.dart';

/// Solicitudes de vacaciones y permisos del empleado en sesión, con su saldo.
class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  final _carga = GlobalKey<CargaState<(Json, List<Json>)>>();

  Future<(Json, List<Json>)> _cargar() async => (await PortalService.perfil(), await PortalService.solicitudes());

  Future<void> _nueva() async {
    final r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => formularioSolicitud(conEmpleado: false, guardar: PortalService.solicitar),
    ));
    if (r != null && mounted) {
      mostrarMensaje(context, 'Solicitud enviada. Recursos Humanos la revisará.');
      _carga.currentState?.recargar();
    }
  }

  Future<void> _cancelar(Json s) async {
    final ok = await confirmar(context,
        titulo: 'Cancelar solicitud',
        mensaje: '¿Cancelar tu solicitud de ${s.str('tipo_nombre').toLowerCase()}?',
        aceptar: 'Cancelar solicitud',
        destructivo: true);
    if (!ok || !mounted) return;
    await ejecutar(context, () => PortalService.cancelarSolicitud(s.entero('id')!), exito: 'Solicitud cancelada.');
    _carga.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    if (session.empleadoId == null) {
      return const VacioView('Tu usuario no está vinculado a un empleado.', icon: Icons.link_off);
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        backgroundColor: NomiColors.darkGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva solicitud'),
      ),
      body: Carga<(Json, List<Json>)>(
        key: _carga,
        cargar: _cargar,
        builder: (context, datos, recargar) {
          final (perfil, solicitudes) = datos;
          final saldo = perfil.obj('saldo_vacaciones') ?? {};
          return RefreshIndicator(
            onRefresh: recargar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Row(children: [
                  Expanded(
                      child: KpiTile('Disponibles', saldo.str('dias_disponibles'),
                          color: NomiColors.emerald, icon: Icons.beach_access_outlined)),
                  const SizedBox(width: 8),
                  Expanded(child: KpiTile('Tomados', saldo.str('dias_tomados'))),
                  const SizedBox(width: 8),
                  Expanded(child: KpiTile('Por aprobar', saldo.str('dias_pendientes'), color: NomiColors.amber)),
                ]),
                const SizedBox(height: 6),
                Text(
                  '${saldo.str('dias_derecho')} días por ${saldo.str('anios_servicio')} año(s) de antigüedad (LFT art. 76).',
                  style: const TextStyle(fontSize: 11.5, color: NomiColors.text3),
                ),
                const SectionLabel('Mis solicitudes'),
                if (solicitudes.isEmpty)
                  const VacioView('Aún no tienes solicitudes.', icon: Icons.event_available_outlined)
                else
                  for (final s in solicitudes)
                    filaSolicitud(s,
                        mostrarEmpleado: false,
                        onTap: s.str('estado') == 'pendiente' ? () => _cancelar(s) : null),
              ],
            ),
          );
        },
      ),
    );
  }
}
