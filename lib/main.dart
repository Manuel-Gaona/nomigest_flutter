import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'theme/nomi_theme.dart';
import 'widgets/nomi_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX');
  runApp(const NomiGestApp());
}

class NomiGestApp extends StatefulWidget {
  const NomiGestApp({super.key});

  @override
  State<NomiGestApp> createState() => _NomiGestAppState();
}

class _NomiGestAppState extends State<NomiGestApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<void> _restaurando = session.restaurar();

  @override
  void initState() {
    super.initState();
    // Al cerrar o perder la sesión se regresa a la pantalla raíz (login)
    session.addListener(() {
      if (!session.activa) _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NomiGest',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildNomiTheme(),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: FutureBuilder<void>(
        future: _restaurando,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const _Bienvenida();
          return ListenableBuilder(
            listenable: session,
            builder: (context, _) => session.activa ? const HomeShell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: NomiLogo(size: 96)));
}
