import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colores de marca de VITA: verde azulado (adulto mayor), azul (voluntario) y los tonos de estado.
///
/// Son los mismos en claro y en oscuro (rellenos de botones, degradados, logo). Los colores
/// que cambian con el tema (fondo, tarjetas, texto, bordes) viven en [VitaPalette] y se leen
/// con `context.vita`.
///
/// Regla del proyecto: no escribir `Color(0x...)` en las pantallas. Si falta un color,
/// se agrega aquí o en la paleta, con un nombre que diga para qué sirve.
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

  // --- Texto y superficies (tema CLARO). Para que cambien con el tema usa `context.vita`. ---
  static const Color ink = Color(0xFF1F2D3D); // texto
  static const Color muted = Color(0xFF5F6F7E); // texto secundario
  static const Color bg = Color(0xFFF4F7F7); // fondo
  static const Color tint = Color(0xFFE0F2EF); // fondos suaves
  static const Color tintBorder = Color(0xFF9ED8CD);
  static const Color border = Color(0xFFDDE5E8); // bordes
  static const Color neutralBg = Color(0xFFEEF1F3);

  // --- Estados (semánticos, tema CLARO) ---
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
///
/// No llevan color de texto (lo toman del tema) salvo los "atenuados", que usan el gris del tema
/// claro; en pantallas con modo oscuro usa `context.vita.muted` con `copyWith`.
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
  /// Colores del tema claro.
  VitaToneColors get colors => VitaPalette.light.toneColors(this);

  /// Colores del tema que está activo (claro u oscuro).
  VitaToneColors resolve(BuildContext context) => context.vita.toneColors(this);
}

/// Colores que cambian entre el tema claro y el oscuro. Se leen con `context.vita`.
///
/// El adulto mayor siempre usa el claro; voluntarios y coordinación pueden elegir.
@immutable
class VitaPalette extends ThemeExtension<VitaPalette> {
  const VitaPalette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.tint,
    required this.tintBorder,
    required this.neutralBg,
    required this.accent,
    required this.accentBlue,
    required this.primaryTone,
    required this.infoTone,
    required this.successTone,
    required this.warningTone,
    required this.dangerTone,
    required this.neutralTone,
  });

  final Color bg; // fondo de la pantalla
  final Color surface; // tarjetas, cabeceras, diálogos
  final Color ink; // texto principal
  final Color muted; // texto secundario
  final Color border;
  final Color tint; // fondo suave de la marca
  final Color tintBorder;
  final Color neutralBg;

  /// Verde azulado para textos e iconos de acento (más claro en oscuro para que se lea).
  final Color accent;

  /// Azul para textos e iconos de acento.
  final Color accentBlue;

  final VitaToneColors primaryTone;
  final VitaToneColors infoTone;
  final VitaToneColors successTone;
  final VitaToneColors warningTone;
  final VitaToneColors dangerTone;
  final VitaToneColors neutralTone;

  bool get isDark => bg.computeLuminance() < 0.2;

  VitaToneColors toneColors(VitaTone tone) {
    switch (tone) {
      case VitaTone.primary:
        return primaryTone;
      case VitaTone.info:
        return infoTone;
      case VitaTone.success:
        return successTone;
      case VitaTone.warning:
        return warningTone;
      case VitaTone.danger:
        return dangerTone;
      case VitaTone.neutral:
        return neutralTone;
    }
  }

  static const VitaPalette light = VitaPalette(
    bg: VitaColors.bg,
    surface: Colors.white,
    ink: VitaColors.ink,
    muted: VitaColors.muted,
    border: VitaColors.border,
    tint: VitaColors.tint,
    tintBorder: VitaColors.tintBorder,
    neutralBg: VitaColors.neutralBg,
    accent: VitaColors.primary,
    accentBlue: VitaColors.secondary,
    primaryTone: VitaToneColors(fg: VitaColors.primary, bg: VitaColors.tint, border: VitaColors.tintBorder),
    infoTone: VitaToneColors(fg: VitaColors.secondary, bg: VitaColors.infoBg, border: VitaColors.infoBorder),
    successTone: VitaToneColors(fg: VitaColors.success, bg: VitaColors.successBg, border: VitaColors.successBorder),
    warningTone: VitaToneColors(fg: VitaColors.warning, bg: VitaColors.warningBg, border: VitaColors.warningBorder),
    dangerTone: VitaToneColors(fg: VitaColors.alert, bg: VitaColors.alertBg, border: VitaColors.alertBorder),
    neutralTone: VitaToneColors(fg: VitaColors.muted, bg: VitaColors.neutralBg, border: VitaColors.border),
  );

  /// Oscuro azulado (no negro puro): menos cansado para la vista y combina con el verde azulado.
  static const VitaPalette dark = VitaPalette(
    bg: Color(0xFF0E1519),
    surface: Color(0xFF17212A),
    ink: Color(0xFFE8EEF2),
    muted: Color(0xFF9DAEBB),
    border: Color(0xFF2B3A45),
    tint: Color(0xFF12393A),
    tintBorder: Color(0xFF1F5C58),
    neutralBg: Color(0xFF1F2A33),
    accent: Color(0xFF4FD1C0),
    accentBlue: Color(0xFF8DB4F2),
    primaryTone: VitaToneColors(fg: Color(0xFF4FD1C0), bg: Color(0xFF12393A), border: Color(0xFF1F5C58)),
    infoTone: VitaToneColors(fg: Color(0xFF8DB4F2), bg: Color(0xFF172A44), border: Color(0xFF2D4A75)),
    successTone: VitaToneColors(fg: Color(0xFF7FD9A0), bg: Color(0xFF12301F), border: Color(0xFF245C3A)),
    warningTone: VitaToneColors(fg: Color(0xFFF2C36B), bg: Color(0xFF33280E), border: Color(0xFF6B531F)),
    dangerTone: VitaToneColors(fg: Color(0xFFFF8A80), bg: Color(0xFF3A1618), border: Color(0xFF7A2E2E)),
    neutralTone: VitaToneColors(fg: Color(0xFF9DAEBB), bg: Color(0xFF1F2A33), border: Color(0xFF2B3A45)),
  );

  @override
  VitaPalette copyWith() => this;

  // Al cambiar de tema se salta de una paleta a la otra (sin mezclar colores a medias).
  @override
  VitaPalette lerp(ThemeExtension<VitaPalette>? other, double t) {
    if (other is! VitaPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension VitaContext on BuildContext {
  /// Colores del tema activo. Si por algún motivo no hay paleta, usa la clara.
  VitaPalette get vita => Theme.of(this).extension<VitaPalette>() ?? VitaPalette.light;
}

class VitaTheme {
  // Se construyen una sola vez: así cambiar de pantalla no recrea el tema cada vez.
  static final ThemeData light = _build(Brightness.light, VitaPalette.light);

  static final ThemeData dark = _build(Brightness.dark, VitaPalette.dark);

  static ThemeData _build(Brightness brightness, VitaPalette p) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: VitaColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: p.accent,
      onPrimary: isDark ? const Color(0xFF00332D) : Colors.white,
      primaryContainer: p.tint,
      onPrimaryContainer: p.ink,
      secondary: p.accentBlue,
      onSecondary: isDark ? const Color(0xFF0B2547) : Colors.white,
      error: isDark ? const Color(0xFFFF8A80) : VitaColors.alert,
      onError: isDark ? const Color(0xFF410002) : Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.border,
      outlineVariant: p.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Nunito',
      extensions: [p],
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
        .apply(bodyColor: p.ink, displayColor: p.ink);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: p.border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        // Iconos de la barra de estado: claros sobre fondo oscuro y al revés.
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        shape: Border(bottom: BorderSide(color: p.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(fontSize: 18, color: p.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.accent, width: 2),
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
          foregroundColor: p.accent,
          textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      // Los `Card` y los diálogos de la app heredan el mismo estilo sin repetirlo en cada pantalla.
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VitaRadius.lg)),
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          height: 1.35,
          color: p.ink,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(VitaRadius.xl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: p.tint,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? p.accent : p.ink,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 28, color: selected ? p.accent : p.ink);
        }),
      ),
    );
  }
}
