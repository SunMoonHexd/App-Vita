import 'package:flutter/material.dart';

/// Paleta limpia de VITA: verde azulado (adulto mayor), azul (voluntario) y fondo suave.
///
/// Regla del proyecto: no escribir `Color(0x...)` en las pantallas. Si falta un color,
/// se agrega aquí con un nombre que diga para qué sirve.
class VitaColors {
  // --- Marca ---
  static const Color primary = Color(0xFF14877A); // verde azulado: acción principal
  static const Color primaryLight = Color(0xFF26AA9A);
  static const Color primaryBright = Color(0xFF1FA596); // extremo claro del degradado principal
  static const Color primaryDark = Color(0xFF0E6B60); // "relieve" del botón principal
  static const Color secondary = Color(0xFF3F6DB3); // azul: voluntarios
  static const Color secondaryLight = Color(0xFF5E8CD2);
  static const Color secondaryDark = Color(0xFF2E5496); // extremo oscuro del degradado azul
  static const Color slate = Color(0xFF35506B); // azul grisáceo: acciones de registro

  // --- Texto y superficies ---
  static const Color ink = Color(0xFF1F2D3D); // texto
  static const Color muted = Color(0xFF5F6F7E); // texto secundario
  static const Color bg = Color(0xFFF4F7F7); // fondo
  static const Color tint = Color(0xFFE0F2EF); // fondos suaves
  static const Color tintBorder = Color(0xFF9ED8CD);
  static const Color border = Color(0xFFDDE5E8); // bordes
  static const Color neutralBg = Color(0xFFEEF1F3);

  // --- Estados (semánticos) ---
  static const Color alert = Color(0xFFC62828); // emergencia y reportes
  static const Color alertBg = Color(0xFFFDECEA);
  static const Color alertBorder = Color(0xFFF2B8B5);
  static const Color success = Color(0xFF1E6B3F);
  static const Color successBg = Color(0xFFE3F5EA);
  static const Color successBorder = Color(0xFF8BCFA3);
  static const Color warning = Color(0xFF8A5300);
  static const Color warningBg = Color(0xFFFFF0D6);
  static const Color warningBorder = Color(0xFFF0CF8E);
  static const Color infoBg = Color(0xFFE9F0FB);
  static const Color infoBorder = Color(0xFFC6D8F3);
}

/// Degradados de la marca.
class VitaGradients {
  /// Colores del perfil adulto mayor (verde azulado) y voluntario (azul), claro al final.
  static const List<Color> tealColors = [VitaColors.primary, VitaColors.primaryLight];
  static const List<Color> blueColors = [VitaColors.secondary, VitaColors.secondaryLight];

  /// Degradados de las cabeceras grandes. Terminan en tonos oscuros para que el texto blanco
  /// se lea bien (contraste suficiente) de punta a punta.
  static const List<Color> heroTeal = [VitaColors.primary, VitaColors.primaryDark];
  static const List<Color> heroBlue = [VitaColors.secondary, VitaColors.secondaryDark];

  /// Degradado principal de los botones y tarjetas de acción.
  static LinearGradient primary({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [VitaColors.primaryBright, VitaColors.primary],
    );
  }

  /// Verde → azul: avatar y logo.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [VitaColors.primaryLight, VitaColors.secondaryLight],
  );
}

/// Escala de espaciados. Úsala en lugar de números sueltos.
class VitaSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Escala de esquinas redondeadas. Uso: `BorderRadius.circular(VitaRadius.lg)`.
class VitaRadius {
  static const double sm = 14; // campos, avisos pequeños
  static const double md = 18; // botones
  static const double lg = 24; // tarjetas
  static const double xl = 28; // tarjetas protagonistas
  static const double pill = 999; // píldoras
}

/// Estilos de texto con nombre. El tamaño mínimo en la app es 14.
class VitaText {
  static const TextStyle display = TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.15);
  static const TextStyle title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2);
  static const TextStyle heading = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);
  static const TextStyle body = TextStyle(fontSize: 18, height: 1.35);
  static const TextStyle bodyMuted = TextStyle(fontSize: 17, height: 1.35, color: VitaColors.muted);
  static const TextStyle label = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
  static const TextStyle caption = TextStyle(fontSize: 14, height: 1.3, color: VitaColors.muted);
  static const TextStyle overline = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
    color: VitaColors.muted,
  );
}

/// Tonos para píldoras, tarjetas y métricas: cada uno trae texto, fondo y borde que combinan.
enum VitaTone { primary, info, success, warning, danger, neutral }

class VitaToneColors {
  const VitaToneColors({required this.fg, required this.bg, required this.border});

  final Color fg;
  final Color bg;
  final Color border;
}

extension VitaToneX on VitaTone {
  VitaToneColors get colors {
    switch (this) {
      case VitaTone.primary:
        return const VitaToneColors(fg: VitaColors.primary, bg: VitaColors.tint, border: VitaColors.tintBorder);
      case VitaTone.info:
        return const VitaToneColors(fg: VitaColors.secondary, bg: VitaColors.infoBg, border: VitaColors.infoBorder);
      case VitaTone.success:
        return const VitaToneColors(fg: VitaColors.success, bg: VitaColors.successBg, border: VitaColors.successBorder);
      case VitaTone.warning:
        return const VitaToneColors(fg: VitaColors.warning, bg: VitaColors.warningBg, border: VitaColors.warningBorder);
      case VitaTone.danger:
        return const VitaToneColors(fg: VitaColors.alert, bg: VitaColors.alertBg, border: VitaColors.alertBorder);
      case VitaTone.neutral:
        return const VitaToneColors(fg: VitaColors.muted, bg: VitaColors.neutralBg, border: VitaColors.border);
    }
  }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VitaRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VitaColors.primary,
          textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: VitaColors.border, thickness: 1),
      // Los `Card` y los diálogos de la app heredan el mismo estilo sin repetirlo en cada pantalla.
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: VitaColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VitaRadius.lg)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: VitaColors.ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          height: 1.35,
          color: VitaColors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: VitaColors.tint,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? VitaColors.primary : VitaColors.ink,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 28, color: selected ? VitaColors.primary : VitaColors.ink);
        }),
      ),
    );
  }
}
