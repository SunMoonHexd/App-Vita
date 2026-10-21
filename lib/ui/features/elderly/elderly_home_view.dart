import 'package:flutter/material.dart';
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
    final hasVolunteers = repo.availableVolunteerCount > 0;

    return Scaffold(
      backgroundColor: VitaColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            VitaHeader(
              eyebrow: '${_greeting()},',
              title: '$firstName 👋',
              titleSize: 32,
              trailing: Semantics(
                button: true,
                label: 'Mi perfil',
                child: GestureDetector(
                  onTap: () => _open(context, const ElderlyProfileView()),
                  child: VitaAvatar(name: user.displayName, size: 54),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                children: [
                  const Center(child: VitaConnectionPill()),
                  const SizedBox(height: 22),
                  const Text(
                    '¿Quieres conversar con alguien?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasVolunteers
                        ? 'Hay voluntarios disponibles ahora mismo.'
                        : 'Ahora no hay voluntarios disponibles. Puedes intentarlo en un momento.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: VitaColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 30),
                  _TalkButton(onTap: () => _open(context, const ElderlySearchingView())),
                  const SizedBox(height: 30),
                  const _TipBox(),
                  const SizedBox(height: VitaSpace.lg),
                  // "Salir" ya no vive en la barra inferior, para no confundirlo con la navegación.
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
    );
  }
}

class _TalkButton extends StatelessWidget {
  const _TalkButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    return Semantics(
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
              onTap: onTap,
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
                      child: const Text('💬', style: TextStyle(fontSize: 36)),
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
          Text('💡', style: TextStyle(fontSize: 30)),
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
