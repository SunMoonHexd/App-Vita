import 'package:flutter/material.dart';

/// Paleta limpia de VITA: verde azulado (adulto mayor), azul (voluntario) y fondo suave.
class VitaColors {
  static const Color primary = Color(0xFF14877A); // verde azulado: acción principal
  static const Color primaryLight = Color(0xFF26AA9A);
  static const Color secondary = Color(0xFF3F6DB3); // azul: voluntarios
  static const Color secondaryLight = Color(0xFF5E8CD2);
  static const Color slate = Color(0xFF35506B); // azul grisáceo: acciones de registro
  static const Color alert = Color(0xFFC62828); // emergencia y reportes
  static const Color ink = Color(0xFF1F2D3D); // texto
  static const Color muted = Color(0xFF5F6F7E); // texto secundario
  static const Color bg = Color(0xFFF4F7F7); // fondo
  static const Color tint = Color(0xFFE0F2EF); // fondos suaves
  static const Color border = Color(0xFFDDE5E8); // bordes
}

class VitaTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: VitaColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: VitaColors.primary,
      onPrimary: Colors.white,
      primaryContainer: VitaColors.tint,
      onPrimaryContainer: VitaColors.ink,
      secondary: VitaColors.secondary,
      onSecondary: Colors.white,
      error: VitaColors.alert,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: VitaColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Nunito',
    );

    final textTheme = base.textTheme
        .merge(
          const TextTheme(
            headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
            titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            bodyLarge: TextStyle(fontSize: 18, height: 1.35),
            bodyMedium: TextStyle(fontSize: 18, height: 1.35),
            labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        )
        .apply(bodyColor: VitaColors.ink, displayColor: VitaColors.ink);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: VitaColors.border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: VitaColors.bg,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: VitaColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: VitaColors.ink,
        ),
        shape: Border(bottom: BorderSide(color: VitaColors.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(fontSize: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VitaColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VitaColors.primary,
          textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: VitaColors.border, thickness: 1),
    );
  }
}
