import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_theme_scope.dart';

void main() {
  group('VitaThemeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('por defecto la app se ve en claro', () async {
      final controller = VitaThemeController();
      await controller.load();
      expect(controller.mode, ThemeMode.light);
    });

    test('recuerda la elección aunque se cierre la app', () async {
      final controller = VitaThemeController();
      await controller.load();
      await controller.setMode(ThemeMode.dark);

      final reopened = VitaThemeController();
      await reopened.load();
      expect(reopened.mode, ThemeMode.dark);
    });

    test('avisa a la pantalla solo cuando la elección cambia', () async {
      final controller = VitaThemeController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setMode(ThemeMode.dark);
      await controller.setMode(ThemeMode.dark);
      expect(notifications, 1);
    });

    test('el adulto mayor y las pantallas de ingreso siempre van en claro', () async {
      final controller = VitaThemeController();
      await controller.setMode(ThemeMode.dark);

      expect(controller.effectiveFor(UserRole.elderly), ThemeMode.light);
      expect(controller.effectiveFor(null), ThemeMode.light);
      expect(controller.effectiveFor(UserRole.volunteer), ThemeMode.dark);
      expect(controller.effectiveFor(UserRole.coordinator), ThemeMode.dark);
    });

    test('solo voluntarios y coordinación pueden elegir la apariencia', () {
      expect(VitaThemeController.canChooseTheme(UserRole.volunteer), isTrue);
      expect(VitaThemeController.canChooseTheme(UserRole.coordinator), isTrue);
      expect(VitaThemeController.canChooseTheme(UserRole.elderly), isFalse);
      expect(VitaThemeController.canChooseTheme(null), isFalse);
    });

    test('un valor guardado desconocido vuelve a claro', () async {
      SharedPreferences.setMockInitialValues({'vita_theme_mode': 'azul'});
      final controller = VitaThemeController();
      await controller.load();
      expect(controller.mode, ThemeMode.light);
    });
  });

  group('VitaPalette', () {
    test('la oscura se reconoce como oscura y la clara no', () {
      expect(VitaPalette.dark.isDark, isTrue);
      expect(VitaPalette.light.isDark, isFalse);
    });

    test('los dos temas llevan la paleta para que context.vita funcione', () {
      expect(VitaTheme.light.extension<VitaPalette>(), isNotNull);
      expect(VitaTheme.dark.extension<VitaPalette>(), isNotNull);
      expect(VitaTheme.dark.brightness, Brightness.dark);
    });

    test('cada tono tiene colores en claro y en oscuro', () {
      for (final tone in VitaTone.values) {
        expect(VitaPalette.light.toneColors(tone).fg, isNotNull);
        expect(VitaPalette.dark.toneColors(tone).bg, isNotNull);
      }
    });
  });
}
