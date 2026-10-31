import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/auth/onboarding_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_actions.dart';
import 'package:vita_app/ui/features/elderly/elderly_help_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_profile_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_searching_view.dart';

class ElderlyHomeView extends StatefulWidget {
  const ElderlyHomeView({super.key});

  @override
  State<ElderlyHomeView> createState() => _ElderlyHomeViewState();
}

class _ElderlyHomeViewState extends State<ElderlyHomeView> {
  bool _safetyNoticeScheduled = false;
  bool _showCallOptions = false;

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
            VitaHeroHeader(
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
                      size: 58,
                      photoBase64: user.photoBase64,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        fit: BoxFit.cover,
                        cacheWidth: 144,
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
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                children: [
                  Text(
                    _showCallOptions
                        ? '¿Cómo prefieres conversar?'
                        : '¿Quieres conversar con alguien?',
                    textAlign: TextAlign.center,
                    style: VitaText.title.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: VitaSpace.sm),
                  Text(
                    _showCallOptions
                        ? 'Elige una opción y te conectaremos con un voluntario.'
                        : hasVolunteers
                        ? 'Pulsa el botón cuando quieras hablar con un voluntario.'
                        : 'Ahora no hay voluntarios disponibles. Puedes intentarlo en un momento.',
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
                  const SizedBox(height: VitaSpace.lg),
                  // "Salir" no vive en la barra inferior, para no confundirlo con la navegación.
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: VitaColors.muted,
                      ),
                      onPressed: () => confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesión'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: VitaNavBar(
          items: const [
            VitaNavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Inicio',
            ),
            VitaNavItem(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Mi perfil',
            ),
            VitaNavItem(
              icon: Icons.help_outline_rounded,
              selectedIcon: Icons.help_rounded,
              label: 'Ayuda',
            ),
          ],
          onSelected: (index) {
            if (index == 1) _open(context, const ElderlyProfileView());
            if (index == 2) _open(context, const ElderlyHelpView());
          },
        ),
      ),
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
              constraints: const BoxConstraints(minHeight: 184),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Quiero hablar\n',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontSize: 27,
                                    height: 1.05,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                                TextSpan(
                                  text: 'ahora',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontSize: 35,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.25,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.start,
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Toca aquí para elegir cómo conversar',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: Colors.white,
                              fontSize: 19,
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
                      size: 34,
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
              constraints: const BoxConstraints(minHeight: 116),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: foreground, size: 38),
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
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 17,
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
