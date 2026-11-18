import 'package:flutter_test/flutter_test.dart';
import 'package:nomigest_flutter/core/formatters.dart';
import 'package:nomigest_flutter/core/json.dart';
import 'package:nomigest_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('formato de moneda y fechas', () {
    expect(moneda(12450), '\$12,450.00');
    expect(fecha('2026-10-15'), '15/10/2026');
    expect(isoFecha(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('lectura segura del JSON de la API', () {
    final Json datos = {'id': 3, 'neto': 1500.5, 'items': [{'a': 1}], 'activo': true};
    expect(datos.entero('id'), 3);
    expect(datos.numero('neto'), 1500.5);
    expect(datos.numero('falta'), 0);
    expect(datos.lista('items').first['a'], 1);
    expect(datos.flag('activo'), isTrue);
  });

  testWidgets('sin sesión guardada muestra el inicio de sesión', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NomiGestApp());
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });
}
