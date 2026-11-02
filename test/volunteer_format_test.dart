import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/ui/features/volunteer/volunteer_format.dart';

void main() {
  group('formato de datos para voluntariado', () {
    test('formatea duraciones en minutos y en horas con minutos', () {
      expect(formatDuration(const Duration(minutes: 45)), '45 min');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 30)),
        '1 h 30 min',
      );
      expect(formatDuration(const Duration(hours: 2)), '2 h 0 min');
    });

    test('muestra fecha, hora de 12 horas y periodo del día', () {
      expect(
        formatDateTime(DateTime(2026, 10, 7, 15, 4)),
        '07/10/2026 · 3:04 p. m.',
      );
      expect(
        formatDateTime(DateTime(2026, 1, 2, 0, 9)),
        '02/01/2026 · 12:09 a. m.',
      );
    });

    test('reduce nombres y conserva los casos especiales', () {
      expect(shortName('  Ana María Pérez  '), 'Ana');
      expect(shortName(''), 'Adulto mayor');
      expect(shortName('   ', fallback: 'Persona'), 'Persona');
      expect(shortName('Cuenta eliminada'), 'Cuenta eliminada');
    });
  });
}
