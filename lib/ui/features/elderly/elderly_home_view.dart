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

class ElderlyHomeView extends StatelessWidget {
  const ElderlyHomeView({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final repo = VitaScope.of(context);
    final user = repo.currentUser;
    if (user == null) {
      return const VitaPage(title: 'VITA', child: Text('Sesión cerrada'));
    }
    if (!user.onboardingDone) {
      return OnboardingView(onDone: () {});
    }

    final firstName = user.displayName.trim().split(' ').first;
    final volunteers = repo.availableVolunteerCount;
    final hasVolunteers = volunteers > 0;

    // La cabecera con degradado llega hasta arriba de la pantalla: iconos de la barra en blanco.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: VitaColors.bg,
        body: Column(
          children: [
            VitaHeroHeader(
              eyebrow: '${_greeting()},',
              title: '$firstName 👋',
              trailing: Semantics(
                button: true,
                label: 'Mi perfil',
                child: GestureDetector(
                  onTap: () => _open(context, const ElderlyProfileView()),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: VitaAvatar(name: user.displayName, size: 54),
                  ),
                ),
              ),
              child: Wrap(
                spacing: VitaSpace.sm,
                runSpacing: VitaSpace.sm,
                children: [
                  const VitaConnectionPill(),
                  _AvailabilityChip(count: volunteers),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
                children: [
                  const Text(
                    '¿Quieres conversar con alguien?',
                    textAlign: TextAlign.center,
                    style: VitaText.title,
                  ),
                  const SizedBox(height: VitaSpace.sm),
                  Text(
                    hasVolunteers
                        ? 'Toca el botón y te conectamos con un voluntario.'
                        : 'Ahora no hay voluntarios disponibles. Puedes intentarlo en un momento.',
                    textAlign: TextAlign.center,
                    style: VitaText.bodyMuted,
                  ),
                  const SizedBox(height: 34),
                  _TalkButton(onTap: () => _open(context, const ElderlySearchingView())),
                  const SizedBox(height: 34),
                  const _TipBox(),
                  const SizedBox(height: VitaSpace.lg),
                  // "Salir" no vive en la barra inferior, para no confundirlo con la navegación.
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: VitaColors.muted),
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
            VitaNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio'),
            VitaNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Mi perfil'),
            VitaNavItem(icon: Icons.help_outline_rounded, selectedIcon: Icons.help_rounded, label: 'Ayuda'),
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

/// Cuántos voluntarios hay disponibles, sobre la cabecera con degradado.
class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final available = count > 0;
    final label = available
        ? (count == 1 ? '1 voluntario disponible' : '$count voluntarios disponibles')
        : 'Sin voluntarios por ahora';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
              color: available ? VitaColors.successBorder : VitaColors.warningBorder,
            ),
          ),
          const SizedBox(width: VitaSpace.sm),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón principal. Un halo suave se expande a su alrededor para invitar a tocarlo; si la
/// persona tiene desactivadas las animaciones en el celular, el halo no se dibuja.
class _TalkButton extends StatefulWidget {
  const _TalkButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TalkButton> createState() => _TalkButtonState();
}

class _TalkButtonState extends State<_TalkButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final button = Semantics(
      button: true,
      label: 'Quiero hablar. Buscar compañía ahora',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            const BoxShadow(color: VitaColors.primaryDark, offset: Offset(0, 7)),
            BoxShadow(
              color: VitaColors.primaryLight.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: VitaGradients.primary(begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, size: 38, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'QUIERO HABLAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buscar compañía ahora',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (reduceMotion) return button;

    return AnimatedBuilder(
      animation: _pulse,
      child: button,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_pulse.value);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 1 + 0.09 * t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      color: VitaColors.primaryLight.withValues(alpha: 0.30 * (1 - t)),
                    ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox();

  @override
  Widget build(BuildContext context) {
    return const VitaCard(
      tone: VitaTone.info,
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.lightbulb_rounded, size: 32, color: VitaColors.secondary),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Recuerda: no compartas datos personales, dinero ni claves durante las llamadas.',
              style: TextStyle(fontSize: 17, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
