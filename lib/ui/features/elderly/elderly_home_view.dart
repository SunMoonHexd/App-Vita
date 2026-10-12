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
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()},', style: const TextStyle(fontSize: 17, color: VitaColors.muted)),
                        Text(
                          '$firstName 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _open(context, const ElderlyProfileView()),
                    child: VitaAvatar(name: user.displayName, size: 54),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        onProfile: () => _open(context, const ElderlyProfileView()),
        onHelp: () => _open(context, const ElderlyHelpView()),
        onLogout: () => confirmLogout(context),
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
            const BoxShadow(color: Color(0xFF0E6B60), offset: Offset(0, 7)),
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1FA596), Color(0xFF14877A)],
              ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EEFA),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onProfile, required this.onHelp, required this.onLogout});

  final VoidCallback onProfile;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: VitaColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(emoji: '🏠', label: 'Inicio', selected: true, onTap: () {}),
            _NavItem(emoji: '👤', label: 'Mi perfil', onTap: onProfile),
            _NavItem(emoji: '❓', label: 'Ayuda', onTap: onHelp),
            _NavItem(emoji: '🚪', label: 'Salir', onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.emoji, required this.label, required this.onTap, this.selected = false});

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? VitaColors.primary : VitaColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
