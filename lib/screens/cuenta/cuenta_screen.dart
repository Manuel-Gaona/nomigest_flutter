import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/cuenta_service.dart';
import '../../services/portal_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import '../portal/pin_sheet.dart';

/// Datos de la sesión, cambio de contraseña y de PIN, y cierre de sesión.
class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  Future<void> _cambiarPassword(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (ok == true && context.mounted) mostrarMensaje(context, 'Contraseña actualizada.');
  }

  Future<void> _cambiarPin(BuildContext context) async {
    final perfil = await ejecutar(context, PortalService.perfil);
    if (perfil == null || !context.mounted) return;
    String? actual;
    if (perfil['tiene_pin'] == true) {
      actual = await PinSheet.mostrar(context,
          titulo: 'PIN actual', descripcion: 'Escribe tu PIN actual.', boton: 'Continuar');
      if (actual == null || !context.mounted) return;
    }
    final nuevo = await PinSheet.mostrar(context, titulo: 'Nuevo PIN', descripcion: 'Elige 4 dígitos.', boton: 'Guardar');
    if (nuevo == null || !context.mounted) return;
    await ejecutar(context, () => PortalService.guardarPin(nuevo, actual: actual), exito: 'PIN actualizado.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NomiCard(
          child: Column(
            children: spaced([
              KvRow('Usuario', session.nombreUsuario, bold: true),
              KvRow('Rol', session.rol),
              if (session.usuario?['empleado'] != null) KvRow('Empleado', '${session.usuario!['empleado']}'),
              KvRow('Servidor', api.baseUrl),
            ], 10),
          ),
        ),
        const SectionLabel('Seguridad'),
        RecordTile(
          title: 'Cambiar contraseña',
          subtitle: 'Mínimo 8 caracteres',
          leading: const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.lock_outline)),
          trailing: const Icon(Icons.chevron_right, color: NomiColors.text3),
          onTap: () => _cambiarPassword(context),
        ),
        if (session.puede('portal') && session.empleadoId != null)
          RecordTile(
            title: 'Cambiar PIN de firma',
            subtitle: 'PIN de 4 dígitos para firmar tus recibos',
            leading: const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.pin_outlined)),
            trailing: const Icon(Icons.chevron_right, color: NomiColors.text3),
            onTap: () => _cambiarPin(context),
          ),
        const SizedBox(height: 24),
        NomiButton('Cerrar sesión', color: NomiColors.red, outlined: true, icon: Icons.logout, onPressed: () async {
          if (await confirmar(context, titulo: 'Cerrar sesión', mensaje: '¿Deseas salir de NomiGest?', aceptar: 'Salir')) {
            await session.cerrar();
          }
        }),
      ],
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nuevo = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nuevo.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await CuentaService.cambiarPassword(_actual.text, _nuevo.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errores.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cambiar contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            ...spaced([
              NomiField('Contraseña actual', icon: Icons.lock_outline, obscure: true, controller: _actual,
                  validator: (v) => (v ?? '').isEmpty ? 'Campo obligatorio.' : null),
              NomiField('Nueva contraseña', icon: Icons.lock_reset, obscure: true, controller: _nuevo,
                  validator: (v) => (v ?? '').length < 8 ? 'Mínimo 8 caracteres.' : null),
              NomiField('Confirmar nueva contraseña', icon: Icons.lock_reset, obscure: true, controller: _confirmacion,
                  errorText: _error,
                  validator: (v) => v != _nuevo.text ? 'Las contraseñas no coinciden.' : null),
            ]),
            const SizedBox(height: 18),
            NomiButton('Guardar', color: NomiColors.darkGreen, height: 52, loading: _guardando, onPressed: _guardar),
          ],
        ),
      ),
    );
  }
}
