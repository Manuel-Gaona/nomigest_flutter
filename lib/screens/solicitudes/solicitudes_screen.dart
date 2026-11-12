import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/crud_service.dart';
import '../../services/portal_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import 'solicitud_form.dart';

/// Vacaciones y permisos (RF09): registro, consulta y aprobación por RH.
class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  String? _estado = 'pendiente';
  final _carga = GlobalKey<CargaState<List<Json>>>();

  static const _filtros = [
    ('pendiente', 'Pendientes'),
    ('aprobado', 'Aprobadas'),
    ('rechazado', 'Rechazadas'),
    (null, 'Todas'),
  ];

  Future<void> _nueva() async {
    final r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => formularioSolicitud(conEmpleado: true, guardar: solicitudesService.crear),
    ));
    if (r != null && mounted) {
      mostrarMensaje(context, 'Solicitud registrada como Pendiente.');
      _carga.currentState?.recargar();
    }
  }

  Future<void> _resolver(Json s) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.str('empleado'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...spaced([
              KvRow('Tipo', s.str('tipo_nombre')),
              KvRow('Del', fecha(s.str('fecha_inicial'))),
              KvRow('Al', fecha(s.str('fecha_final'))),
              KvRow('Días hábiles', s.str('dias')),
              if (s['motivo'] != null) KvRow('Motivo', s.str('motivo')),
            ], 8),
            const SizedBox(height: 20),
            ButtonRow([
              NomiButton('Rechazar', color: NomiColors.red, outlined: true, onPressed: () => Navigator.pop(ctx, 'rechazar')),
              NomiButton('Aprobar', color: NomiColors.emerald, onPressed: () => Navigator.pop(ctx, 'aprobar')),
            ]),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancelar'),
                child: const Text('Cancelar solicitud', style: TextStyle(color: NomiColors.text3)),
              ),
            ),
          ],
        ),
      ),
    );
    if (accion == null || !mounted) return;
    final id = s.entero('id')!;
    if (accion == 'cancelar') {
      final ok = await confirmar(context,
          titulo: 'Cancelar solicitud', mensaje: 'La solicitud se eliminará.', aceptar: 'Cancelar solicitud',
          destructivo: true);
      if (!ok || !mounted) return;
      await ejecutar(context, () => solicitudesService.eliminar(id), exito: 'Solicitud cancelada.');
    } else {
      final aprobar = accion == 'aprobar';
      final comentario = await pedirTexto(context,
          titulo: aprobar ? 'Aprobar solicitud' : 'Rechazar solicitud',
          etiqueta: 'Comentario (opcional)',
          boton: aprobar ? 'Aprobar' : 'Rechazar',
          requerido: false,
          lineas: 2,
          color: aprobar ? NomiColors.emerald : NomiColors.red);
      if (comentario == null || !mounted) return;
      final valor = comentario.isEmpty ? null : comentario;
      await ejecutar(
        context,
        () => aprobar
            ? SolicitudesService.aprobar(id, comentario: valor)
            : SolicitudesService.rechazar(id, comentario: valor),
        exito: aprobar ? 'Solicitud aprobada.' : 'Solicitud rechazada.',
      );
    }
    _carga.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        backgroundColor: NomiColors.darkGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Registrar solicitud'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              for (final f in _filtros)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: _estado == f.$1,
                    selectedColor: NomiColors.blueBg,
                    side: const BorderSide(color: NomiColors.stroke),
                    onSelected: (_) {
                      setState(() => _estado = f.$1);
                      _carga.currentState?.recargar();
                    },
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Carga<List<Json>>(
              key: _carga,
              cargar: () => solicitudesService.listar(filtros: {'estado': _estado}),
              builder: (context, solicitudes, recargar) => RefreshIndicator(
                onRefresh: recargar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    const SectionLabel('Solicitudes recientes', top: 8),
                    if (solicitudes.isEmpty)
                      const VacioView('No hay solicitudes.', icon: Icons.beach_access_outlined)
                    else
                      for (final s in solicitudes)
                        filaSolicitud(s, onTap: s.str('estado') == 'pendiente' ? () => _resolver(s) : null),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
