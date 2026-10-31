import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vita_app/domain/models/vita_models.dart';

/// Guarda en este celular si la persona prefiere el tema claro, el oscuro o el del sistema.
///
/// Solo voluntarios y coordinación pueden elegir (ver [canChooseTheme]); el adulto mayor y las
/// pantallas de ingreso siempre se ven en claro, para que no cambie nada para ellos.
class VitaThemeController extends ChangeNotifier {
  VitaThemeController({SharedPreferences? preferences}) : _preferences = preferences;

  static const _key = 'vita_theme_mode';

  SharedPreferences? _preferences;
  ThemeMode _mode = ThemeMode.light;

  /// Lo que eligió la persona (por defecto, claro).
  ThemeMode get mode => _mode;

  /// Quién puede cambiar la apariencia.
  static bool canChooseTheme(UserRole? role) => role == UserRole.volunteer || role == UserRole.coordinator || role == UserRole.psychologist;

  /// Tema que se debe usar ahora según quién tiene la sesión abierta.
  ThemeMode effectiveFor(UserRole? role) => canChooseTheme(role) ? _mode : ThemeMode.light;

  Future<void> load() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final raw = _preferences?.getString(_key);
      _mode = ThemeMode.values.firstWhere((m) => m.name == raw, orElse: () => ThemeMode.light);
    } catch (e) {
      debugPrint('No se pudo leer la apariencia guardada: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences?.setString(_key, mode.name);
    } catch (e) {
      debugPrint('No se pudo guardar la apariencia: $e');
    }
  }
}

class VitaThemeScope extends InheritedNotifier<VitaThemeController> {
  const VitaThemeScope({
    super.key,
    required VitaThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static VitaThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VitaThemeScope>();
    assert(scope != null, 'VitaThemeScope no encontrado');
    return scope!.notifier!;
  }
}
