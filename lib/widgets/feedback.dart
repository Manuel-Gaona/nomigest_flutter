import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme/nomi_theme.dart';
import 'nomi_widgets.dart';

/// Muestra un mensaje en la parte inferior.
void mostrarMensaje(BuildContext context, String mensaje, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(mensaje),
    backgroundColor: error ? NomiColors.red : NomiColors.darkGreen,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Ejecuta una acción contra la API mostrando el error si falla.
/// Devuelve el resultado o null si hubo error.
Future<T?> ejecutar<T>(BuildContext context, Future<T> Function() accion, {String? exito}) async {
  try {
    final resultado = await accion();
    if (exito != null && context.mounted) mostrarMensaje(context, exito);
    return resultado;
  } on ApiException catch (e) {
    if (context.mounted) mostrarMensaje(context, e.message, error: true);
    return null;
  }
}

/// Diálogo de confirmación. Devuelve true si el usuario acepta.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String aceptar = 'Aceptar',
  bool destructivo = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NomiColors.card,
      title: Text(titulo),
      content: Text(mensaje, style: const TextStyle(color: NomiColors.text2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: destructivo ? NomiColors.red : NomiColors.blue),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pide un texto en una hoja inferior (comentarios, respuestas, motivos).
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  String? descripcion,
  String etiqueta = 'Comentario',
  String boton = 'Enviar',
  bool requerido = true,
  int lineas = 4,
  Color color = NomiColors.blue,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (descripcion != null) ...[
              const SizedBox(height: 4),
              Text(descripcion, style: const TextStyle(fontSize: 12.5, color: NomiColors.text3)),
            ],
            const SizedBox(height: 18),
            NomiField(
              etiqueta,
              controller: controller,
              maxLines: lineas,
              validator: (v) => requerido && (v == null || v.trim().isEmpty) ? 'Campo obligatorio.' : null,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: NomiButton(boton, color: color, height: 52, onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Indicador de carga centrado.
class CargandoView extends StatelessWidget {
  const CargandoView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

/// Mensaje de error con botón para reintentar.
class ErrorView extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const ErrorView(this.mensaje, {super.key, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: NomiColors.text3),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: NomiColors.text2)),
            const SizedBox(height: 16),
            NomiButton('Reintentar', icon: Icons.refresh, outlined: true, onPressed: onReintentar),
          ],
        ),
      ),
    );
  }
}

/// Lista vacía.
class VacioView extends StatelessWidget {
  final String mensaje;
  final IconData icon;
  const VacioView(this.mensaje, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: NomiColors.text3),
          const SizedBox(height: 10),
          Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: NomiColors.text3)),
        ],
      ),
    );
  }
}

/// Carga datos con un Future y muestra carga / error / contenido.
/// Llame a [CargaState.recargar] (vía GlobalKey) o use [onRefresh] para refrescar.
class Carga<T> extends StatefulWidget {
  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos, Future<void> Function() recargar) builder;

  const Carga({super.key, required this.cargar, required this.builder});

  @override
  State<Carga<T>> createState() => CargaState<T>();
}

class CargaState<T> extends State<Carga<T>> {
  late Future<T> _futuro = widget.cargar();

  Future<void> recargar() async {
    final futuro = widget.cargar();
    setState(() {
      _futuro = futuro;
    });
    try {
      await futuro;
    } catch (_) {
      // El error se muestra en el builder
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const CargandoView();
        if (snap.hasError) {
          final e = snap.error;
          return ErrorView(e is ApiException ? e.message : 'Ocurrió un error: $e', onReintentar: recargar);
        }
        return widget.builder(context, snap.data as T, recargar);
      },
    );
  }
}
