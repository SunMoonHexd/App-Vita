import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';

/// Botón circular para volver a la pantalla anterior.
class VitaBackButton extends StatelessWidget {
  const VitaBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.arrow_back_rounded, color: VitaColors.ink, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Logo de VITA con su nombre.
class VitaLogoHeader extends StatelessWidget {
  const VitaLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VitaColors.primaryLight, VitaColors.secondaryLight],
            ),
            boxShadow: [
              BoxShadow(
                color: VitaColors.primaryLight.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 8),
        const Text(
          'VITA',
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 1, color: VitaColors.ink),
        ),
      ],
    );
  }
}

/// Indica si hay internet de verdad (se revisa cada 10 segundos).
class VitaConnectionPill extends StatefulWidget {
  const VitaConnectionPill({super.key});

  @override
  State<VitaConnectionPill> createState() => _VitaConnectionPillState();
}

class _VitaConnectionPillState extends State<VitaConnectionPill> {
  bool? _online;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _check() async {
    bool ok;
    try {
      final result = await InternetAddress.lookup('firebase.google.com').timeout(const Duration(seconds: 3));
      ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
    }
    if (mounted && ok != _online) setState(() => _online = ok);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;
    if (_online == null) {
      bg = const Color(0xFFEEF1F3);
      fg = VitaColors.muted;
      text = 'Comprobando conexión…';
    } else if (_online!) {
      bg = const Color(0xFFDDF3E6);
      fg = const Color(0xFF1E6B3F);
      text = 'Conexión activa';
    } else {
      bg = const Color(0xFFFFF0D6);
      fg = const Color(0xFF8A5300);
      text = 'Sin conexión a internet';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Texto pequeño que va encima de un campo.
class VitaFieldLabel extends StatelessWidget {
  const VitaFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Círculo con la inicial del nombre.
class VitaAvatar extends StatelessWidget {
  const VitaAvatar({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VitaColors.primaryLight, VitaColors.secondaryLight],
        ),
        boxShadow: [
          BoxShadow(
            color: VitaColors.primaryLight.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.44, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}

/// Cuatro círculos que se llenan al escribir el PIN.
class VitaPinDots extends StatelessWidget {
  const VitaPinDots({super.key, required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dígitos del PIN escritos: $length de 4',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? VitaColors.primary : Colors.transparent,
              border: Border.all(color: VitaColors.primary, width: 2),
            ),
          );
        }),
      ),
    );
  }
}

/// Teclado numérico grande para escribir el PIN.
class VitaKeypad extends StatelessWidget {
  const VitaKeypad({super.key, required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  Widget _key({required Widget child, required VoidCallback onTap, required Color color, String? label}) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 66,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _digitKey(String d) {
    return _key(
      color: const Color(0xFFE0F3EF),
      label: d,
      onTap: () => onDigit(d),
      child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 12);
    Widget row(List<Widget> cells) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) gap,
                Expanded(child: cells[i]),
              ],
            ],
          ),
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        children: [
          row([_digitKey('1'), _digitKey('2'), _digitKey('3')]),
          row([_digitKey('4'), _digitKey('5'), _digitKey('6')]),
          row([_digitKey('7'), _digitKey('8'), _digitKey('9')]),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              gap,
              Expanded(child: _digitKey('0')),
              gap,
              Expanded(
                child: _key(
                  color: const Color(0xFFFFE1E1),
                  label: 'Borrar',
                  onTap: onBackspace,
                  child: const Icon(Icons.backspace_rounded, color: VitaColors.alert, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
