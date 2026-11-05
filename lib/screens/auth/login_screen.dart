import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/cuenta_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (session.expiro) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => mostrarMensaje(context, 'Tu sesión terminó. Inicia sesión de nuevo.', error: true));
    }
  }

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await session.iniciar(_usuario.text, _password.text);
      // La app cambia sola al menú principal al detectar la sesión
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _recuperar() async {
    final usuario = await pedirTexto(
      context,
      titulo: 'Recuperar contraseña',
      descripcion: 'Escribe tu nombre de usuario. El administrador recibirá la solicitud '
          'y te asignará una contraseña nueva.',
      etiqueta: 'Nombre de usuario',
      lineas: 1,
    );
    if (usuario == null || !mounted) return;
    final mensaje = await ejecutar(context, () => CuentaService.recuperar(usuario));
    if (mensaje != null && mounted) mostrarMensaje(context, mensaje);
  }

  Future<void> _servidor() async {
    final controller = TextEditingController(text: api.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NomiColors.card,
        title: const Text('Servidor de la API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Emulador Android: http://10.0.2.2:5000\n'
              'Teléfono físico: http://<IP de tu PC>:5000',
              style: TextStyle(color: NomiColors.text3, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            NomiField('URL', icon: Icons.dns_outlined, controller: controller, keyboard: TextInputType.url),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    await session.cambiarServidor(url);
    if (!mounted) return;
    final ok = await ejecutar(context, () => api.get('/salud'));
    if (ok != null && mounted) mostrarMensaje(context, 'Conexión correcta con ${api.baseUrl}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NomiLogo(size: 112),
                    const SizedBox(height: 14),
                    const Text('NomiGest', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Gestión de nómina, simple y precisa',
                        style: TextStyle(fontSize: 12, color: NomiColors.text3)),
                    const SizedBox(height: 28),
                    NomiCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Iniciar sesión',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 20),
                            NomiField(
                              'Usuario',
                              icon: Icons.person_outline,
                              controller: _usuario,
                              action: TextInputAction.next,
                              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe tu usuario.' : null,
                            ),
                            const SizedBox(height: 14),
                            NomiField(
                              'Contraseña',
                              icon: Icons.lock_outline,
                              obscure: true,
                              controller: _password,
                              action: TextInputAction.done,
                              onSubmitted: (_) => _ingresar(),
                              validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña.' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: NomiColors.redBg, borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const Icon(Icons.error_outline, color: NomiColors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: NomiButton('Ingresar',
                                  color: NomiColors.emerald, height: 56, loading: _cargando, onPressed: _ingresar),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _recuperar,
                                child: const Text('¿Olvidaste tu contraseña?',
                                    style: TextStyle(color: NomiColors.blue)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Servidor',
                icon: const Icon(Icons.settings_outlined, color: NomiColors.text3),
                onPressed: _servidor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
