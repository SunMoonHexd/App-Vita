import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/auth/onboarding_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_help_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_profile_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_searching_view.dart';

class ElderlyHomeView extends StatefulWidget {
  const ElderlyHomeView({super.key});

  @override
  State<ElderlyHomeView> createState() => _ElderlyHomeViewState();
}

class _ElderlyHomeViewState extends State<ElderlyHomeView> {
  final SpeechToText _speech = SpeechToText();
  bool _safetyNoticeScheduled = false;
  bool _showCallOptions = false;
  bool _voiceListening = false;
  bool _voiceCommandHandled = false;
  String? _voiceMessage;

  @override
  void dispose() {
    unawaited(_speech.cancel());
    super.dispose();
  }

  Future<void> _toggleVoiceCommand() async {
    if (_voiceListening) {
      await _speech.cancel();
      if (mounted) {
        setState(() {
          _voiceListening = false;
          _voiceMessage = 'Escucha cancelada.';
        });
      }
      return;
    }

    setState(() {
      _voiceMessage = null;
      _voiceCommandHandled = false;
    });

    final available = await _speech.initialize(
      onError: (_) {
        if (!mounted || _voiceCommandHandled) return;
        setState(() {
          _voiceListening = false;
          _voiceMessage = 'No se pudo escuchar. Inténtalo de nuevo.';
        });
      },
      onStatus: (status) {
        if (status == 'notListening' &&
            mounted &&
            _voiceListening &&
            !_voiceCommandHandled) {
          setState(() {
            _voiceListening = false;
            _voiceMessage =
                'No te escuché. Toca el micrófono e inténtalo otra vez.';
          });
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      setState(() {
        _voiceMessage =
            'El reconocimiento de voz no está disponible en este dispositivo.';
      });
      return;
    }

    final locales = await _speech.locales();
    String? localeId;
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().replaceAll('_', '-') == 'es-co') {
        localeId = locale.localeId;
        break;
      }
    }
    if (localeId == null) {
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('es')) {
          localeId = locale.localeId;
          break;
        }
      }
    }

    setState(() {
      _voiceListening = true;
      _voiceMessage = 'Te escucho. Di: “Quiero hablar ahora”.';
    });
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          partialResults: true,
        ),
        onResult: (result) {
          if (_voiceCommandHandled) return;
          final words = _normalizeVoiceText(result.recognizedWords);
          final startsVoiceCall =
              words.contains('quiero hablar ahora') ||
              words.contains('llamada de voz') ||
              words.contains('llamada por voz');
          if (result.finalResult && startsVoiceCall) {
            _startVoiceCall();
          } else if (result.finalResult && mounted) {
            setState(() {
              _voiceListening = false;
              _voiceMessage =
                  'Di “Quiero hablar ahora” para iniciar una llamada.';
            });
            unawaited(_speech.stop());
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _voiceListening = false;
          _voiceMessage =
              'No se pudo iniciar el micrófono. Revisa sus permisos.';
        });
      }
    }
  }

  String _normalizeVoiceText(String text) => text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[^a-zñ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _startVoiceCall() {
    if (!mounted || _voiceCommandHandled) return;
    _voiceCommandHandled = true;
    setState(() {
      _voiceListening = false;
      _voiceMessage = 'De acuerdo, buscando a alguien para conversar.';
    });
    unawaited(_speech.stop());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ElderlySearchingView(audioOnly: true),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _showSafetyNotice() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: SizedBox(
          width: 220,
          height: 145,
          child: Image.asset(
            'assets/images/safety_privacy_notice.png',
            fit: BoxFit.contain,
          ),
        ),
        title: const Text(
          'Un recordatorio para cuidarte',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'No compartas datos personales, contraseñas ni dinero durante las llamadas. '
          'Si algo te incomoda, puedes colgar y pedir ayuda.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido', style: TextStyle(fontSize: 19)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) {
      return const VitaPage(title: 'VITA', child: Text('Sesión cerrada'));
    }
    if (!user.onboardingDone) {
      return OnboardingView(onDone: () => setState(() {}));
    }

    if (!_safetyNoticeScheduled) {
      _safetyNoticeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSafetyNotice());
    }

    final firstName = user.displayName.trim().split(' ').first;
    final volunteers = repo.availableVolunteerCount;
    final hasVolunteers = volunteers > 0;

    // La cabecera con degradado llega hasta arriba de la pantalla: iconos de la barra en blanco.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: VitaColors.bg,
        body: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                final reduceMotion = MediaQuery.of(context).disableAnimations;
                return Opacity(
                  opacity: reduceMotion ? 1 : progress,
                  child: Transform.translate(
                    offset: reduceMotion
                        ? Offset.zero
                        : Offset(0, 14 * (1 - progress)),
                    child: child,
                  ),
                );
              },
              child: VitaHeroHeader(
                eyebrow: '${_greeting()}, qué gusto verte',
                title: firstName,
                trailing: Semantics(
                  button: true,
                  label: 'Mi perfil',
                  child: GestureDetector(
                    onTap: () => _open(context, const ElderlyProfileView()),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: VitaAvatar(
                        name: user.displayName,
                        size: 68,
                        photoBase64: user.photoBase64,
                      ),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/icon/logo.png',
                              fit: BoxFit.cover,
                              cacheWidth: 180,
                            ),
                          ),
                        ),
                        const SizedBox(width: VitaSpace.md),
                        Expanded(
                          child: Wrap(
                            spacing: VitaSpace.sm,
                            runSpacing: VitaSpace.sm,
                            children: [
                              const VitaConnectionPill(),
                              _AvailabilityChip(count: volunteers),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: VitaSpace.md),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                children: [
                  if (_showCallOptions) ...[
                    Text(
                      '¿Cómo prefieres conversar?',
                      textAlign: TextAlign.center,
                      style: VitaText.title.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: VitaSpace.sm),
                  ],
                  Text(
                    _showCallOptions
                        ? 'Elige una opción y te conectaremos con un voluntario.'
                        : hasVolunteers
                        ? 'Toca el botón para elegir cómo conversar.'
                        : 'No hay voluntarios disponibles por ahora. Puedes intentarlo más tarde.',
                    textAlign: TextAlign.center,
                    style: VitaText.bodyMuted.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 28),
                  if (_showCallOptions) ...[
                    _CallOptions(
                      onVoice: () => _open(
                        context,
                        const ElderlySearchingView(audioOnly: true),
                      ),
                      onVideo: () =>
                          _open(context, const ElderlySearchingView()),
                    ),
                    const SizedBox(height: VitaSpace.md),
                    VitaSecondaryButton(
                      label: 'Volver',
                      icon: Icons.arrow_back_rounded,
                      height: 62,
                      onPressed: () => setState(() => _showCallOptions = false),
                    ),
                  ] else
                    _TalkNowButton(
                      onPressed: () => setState(() => _showCallOptions = true),
                    ),
                  if (!_showCallOptions) ...[
                    const SizedBox(height: VitaSpace.md),
                    _VoiceCommandButton(
                      listening: _voiceListening,
                      message: _voiceMessage,
                      onPressed: _toggleVoiceCommand,
                    ),
                    const SizedBox(height: VitaSpace.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _ElderlyQuickAction(
                            icon: Icons.person_rounded,
                            title: 'Mi perfil',
                            gradient: const [
                              VitaColors.infoBorder,
                              VitaColors.infoBg,
                            ],
                            foreground: VitaColors.secondaryDark,
                            onTap: () =>
                                _open(context, const ElderlyProfileView()),
                          ),
                        ),
                        const SizedBox(width: VitaSpace.md),
                        Expanded(
                          child: _ElderlyQuickAction(
                            icon: Icons.help_rounded,
                            title: 'Ayuda',
                            gradient: const [
                              VitaColors.lavenderBorder,
                              VitaColors.lavenderBg,
                            ],
                            foreground: VitaColors.lavender,
                            onTap: () =>
                                _open(context, const ElderlyHelpView()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCommandButton extends StatelessWidget {
  const _VoiceCommandButton({
    required this.listening,
    required this.message,
    required this.onPressed,
  });

  final bool listening;
  final String? message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = listening ? VitaColors.lavender : VitaColors.secondaryDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: listening
              ? 'Detener reconocimiento de voz'
              : 'Iniciar una llamada diciendo “Quiero hablar ahora”',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: listening ? VitaColors.lavenderBg : VitaColors.infoBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: listening
                        ? VitaColors.lavenderBorder
                        : VitaColors.infoBorder,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        listening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        color: color,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        listening ? 'Te escucho…' : 'Llamar usando mi voz',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      listening
                          ? Icons.stop_circle_outlined
                          : Icons.chevron_right_rounded,
                      color: color,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: VitaText.bodyMuted.copyWith(fontSize: 15),
          ),
        ],
      ],
    );
  }
}

class _TalkNowButton extends StatefulWidget {
  const _TalkNowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_TalkNowButton> createState() => _TalkNowButtonState();
}

class _TalkNowButtonState extends State<_TalkNowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _pulse.stop();
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(32);
    final button = Semantics(
      button: true,
      label: 'Quiero hablar ahora. Toca para elegir llamada de voz o videollamada.',
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: VitaGradients.tealColors,
            ),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: VitaColors.primaryDark.withValues(alpha: 0.24),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Quiero hablar',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                color: Colors.white,
                                fontSize: 27,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          Text(
                            'ahora',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Toca aquí para elegir cómo conversar',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (_reduceMotion) return button;
    return AnimatedBuilder(
      animation: _pulse,
      child: button,
      builder: (context, child) =>
          Transform.scale(scale: 1 + (_pulse.value * 0.015), child: child),
    );
  }
}

class _ElderlyQuickAction extends StatelessWidget {
  const _ElderlyQuickAction({
    required this.icon,
    required this.title,
    required this.gradient,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<Color> gradient;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: foreground.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 210),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(icon, color: foreground, size: 70),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuántos voluntarios hay disponibles, sobre la cabecera con degradado.
class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final available = count > 0;
    final label = available
        ? (count == 1
              ? '1 voluntario disponible'
              : '$count voluntarios disponibles')
        : 'Sin voluntarios por ahora';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(VitaRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: available
                  ? VitaColors.successBorder
                  : VitaColors.warningBorder,
            ),
          ),
          const SizedBox(width: VitaSpace.sm),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallOptions extends StatelessWidget {
  const _CallOptions({required this.onVoice, required this.onVideo});

  final VoidCallback onVoice;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CallOption(
          title: 'Llamada de voz',
          subtitle: 'Conversar sin encender la cámara',
          icon: Icons.call_rounded,
          background: VitaGradients.tealColors,
          foreground: Colors.white,
          onTap: onVoice,
        ),
        const SizedBox(height: 14),
        _CallOption(
          title: 'Videollamada',
          subtitle: 'Conversar viéndonos',
          icon: Icons.videocam_rounded,
          background: VitaGradients.blueColors,
          foreground: Colors.white,
          onTap: onVideo,
        ),
      ],
    );
  }
}

class _CallOption extends StatelessWidget {
  const _CallOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: background,
            ),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: foreground.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 146),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: foreground, size: 42),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 25,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: foreground,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
