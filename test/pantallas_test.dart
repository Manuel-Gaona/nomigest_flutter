// Prueba de humo de las pantallas con respuestas reales de la API.
//
// test/fixtures/api_respuestas.json se genera con la API de Flask y los datos de
// demostración. Para regenerarlo tras cambiar la API (desde nomigest_back):
//   .venv/Scripts/python ../nomigest_flutter/test/fixtures/generar_respuestas.py
//       ../nomigest_flutter/test/fixtures/api_respuestas.json
//
// Recorre cada opción del menú en tamaño de teléfono y falla si alguna pantalla
// lanza una excepción o se desborda.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nomigest_flutter/core/api_client.dart';
import 'package:nomigest_flutter/core/session.dart';
import 'package:nomigest_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Map<String, dynamic> respuestas;

MockClient servidor(String usuario) => MockClient((request) async {
      final datos = respuestas[usuario] as Map<String, dynamic>;
      final ruta = request.url.path;
      final cuerpo = request.method == 'GET' ? datos[ruta] : (datos['${request.method} $ruta'] ?? {'mensaje': 'ok'});
      if (cuerpo == null) {
        return http.Response(jsonEncode({'error': 'Sin respuesta de prueba para $ruta'}), 404);
      }
      return http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> entrar(WidgetTester tester, String perfil, String usuario, String password) async {
  final original = FlutterError.onError;
  FlutterError.onError = (detalles) {
    debugPrint(detalles.toString());
    original?.call(detalles);
  };
  addTearDown(() => FlutterError.onError = original);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625; // ≈ 411 x 891, teléfono Android típico
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  api.cliente = servidor(perfil);
  if (session.activa) await session.cerrar();

  await tester.pumpWidget(const NomiGestApp());
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), usuario);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
  if (find.text('Hola, $usuario').evaluate().isEmpty) {
    debugPrint([for (final t in find.byType(Text).evaluate()) (t.widget as Text).data].join(' | '));
  }
  expect(find.text('Hola, $usuario'), findsOneWidget);
}

Future<void> abrir(WidgetTester tester, String titulo) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  final opcion = find.descendant(of: find.byType(Drawer), matching: find.text(titulo));
  await tester.scrollUntilVisible(opcion, 120,
      scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
  await tester.ensureVisible(opcion);
  await tester.pumpAndSettle();
  await tester.tap(opcion);
  await tester.pumpAndSettle();
  final error = tester.takeException();
  if (error is FlutterError) debugPrint(error.toStringDeep());
  expect(error, isNull, reason: titulo);
  expect(find.textContaining('Sin respuesta de prueba'), findsNothing, reason: titulo);
}

/// Lista principal de la pantalla visible (la última ruta en el árbol).
Finder listaActual() => find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;

Future<void> regresar(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'es_MX';
    await initializeDateFormatting('es_MX');
    respuestas = jsonDecode(File('test/fixtures/api_respuestas.json').readAsStringSync()) as Map<String, dynamic>;
  });

  testWidgets('administrador: todas las pantallas del menú', (tester) async {
    await entrar(tester, 'admin', 'admin', 'admin12345');

    const pantallas = [
      'Catálogo de Usuarios',
      'Roles y Privilegios',
      'Configuración Fiscal',
      'Catálogo de Empleados',
      'Catálogo de Departamentos',
      'Catálogo de Horarios',
      'Catálogo de Periodos',
      'Conceptos de Nómina',
      'Días Festivos',
      'Percepciones',
      'Deducciones y Préstamos',
      'Calculadora de ISR',
      'Historial de Nóminas',
      'Aclaraciones de Recibos',
      'Vacaciones y Permisos',
      'Faltas e Incapacidades',
      'Mi Cuenta',
      'Nómina por Periodo',
    ];
    for (final p in pantallas) {
      await abrir(tester, p);
    }

    // Nómina → recibo de un empleado
    await tester.tap(find.text('Laura Hernández Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('Neto a pagar'), findsOneWidget);
    expect(find.text('PERCEPCIONES'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await regresar(tester);

    // Catálogo → formulario de alta y de edición
    await abrir(tester, 'Catálogo de Empleados');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo empleado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Guardar'), 300, scrollable: listaActual());
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obligatorio.'), findsWidgets);
    await regresar(tester);
    await tester.tap(find.text('Laura Hernández Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('Editar empleado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Disponibles'), 200, scrollable: listaActual());
    expect(tester.takeException(), isNull);
    await regresar(tester);

    // Deducciones → formulario
    await abrir(tester, 'Deducciones y Préstamos');
    await tester.tap(find.text('Registrar Deducción'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar deducción'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await regresar(tester);
  });

  testWidgets('empleado: recibo, aclaración pendiente y solicitudes', (tester) async {
    await entrar(tester, 'empleado', 'lhernandez', 'empleado123');
    expect(find.text('Catálogo de Usuarios'), findsNothing);

    await abrir(tester, 'Mi Recibo de Nómina');
    expect(find.text('ÚLTIMO SUELDO NETO'), findsOneWidget);
    await tester.tap(find.text('ÚLTIMO SUELDO NETO'));
    await tester.pumpAndSettle();
    expect(find.text('SUELDO NETO'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('De Acuerdo'), 200, scrollable: listaActual());
    expect(find.text('Podrás firmar cuando Recursos Humanos responda tu duda.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await regresar(tester);

    await abrir(tester, 'Mis Vacaciones y Permisos');
    expect(find.text('Permiso con goce'), findsOneWidget);
    await abrir(tester, 'Mi Cuenta');
  });
}
