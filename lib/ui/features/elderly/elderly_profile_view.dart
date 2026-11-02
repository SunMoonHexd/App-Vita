import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/photo_widgets.dart';
import 'package:vita_app/ui/features/elderly/elderly_actions.dart';
import 'package:vita_app/ui/features/elderly/elderly_change_pin_view.dart';
import 'package:vita_app/ui/features/elderly/elderly_edit_profile_view.dart';
import 'package:vita_app/ui/features/shared/legal_text_view.dart';

class ElderlyProfileView extends StatelessWidget {
  const ElderlyProfileView({super.key});

  String _contact(String? name, String? phone) {
    final n = (name ?? '').trim();
    final p = (phone ?? '').trim();
    if (n.isEmpty && p.isEmpty) return 'Sin registrar';
    if (n.isEmpty) return p;
    if (p.isEmpty) return n;
    return '$n · $p';
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final user = VitaScope.of(context).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sesión cerrada')));
    }
    final active = user.status == AccountStatus.active;

    return Scaffold(
      backgroundColor: VitaColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Volver',
                      iconSize: 36,
                      color: VitaColors.primary,
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  VitaPhotoAvatar(user: user),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      user.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (active
                          ? VitaColors.tint
                          : const Color(0xFFFFF0D6)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? VitaColors.primaryLight
                            : const Color(0xFFE0A93B),
                      ),
                    ),
                    child: Text(
                      active ? '✓ Cuenta activa' : 'Cuenta ${user.status.name}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: active
                            ? VitaColors.primary
                            : const Color(0xFF8A5300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                children: [
                  _Card(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'MIS DATOS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: VitaColors.muted,
                            ),
                          ),
                        ),
                      ),
                      _DataRow(
                        icon: Icons.phone_iphone_rounded,
                        label: 'Teléfono',
                        value: (user.phone ?? '').isEmpty
                            ? 'Sin registrar'
                            : user.phone!,
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _DataRow(
                        icon: Icons.person_rounded,
                        label: 'Familiar responsable',
                        value: _contact(user.familyName, user.familyPhone),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _DataRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Contacto alternativo',
                        value: _contact(
                          user.alternateName,
                          user.alternatePhone,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(title: 'MI CUENTA'),
                  const SizedBox(height: 10),
                  _Card(
                    children: [
                      _MenuRow(
                        icon: Icons.edit_rounded,
                        label: 'Editar mis datos',
                        description: 'Teléfono y contactos',
                        onTap: () =>
                            _open(context, const ElderlyEditProfileView()),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        icon: Icons.password_rounded,
                        label: 'Cambiar PIN',
                        description: 'Actualiza tu clave de acceso',
                        onTap: () =>
                            _open(context, const ElderlyChangePinView()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(title: 'PRIVACIDAD Y SEGURIDAD'),
                  const SizedBox(height: 10),
                  _Card(
                    children: [
                      _MenuRow(
                        icon: Icons.privacy_tip_rounded,
                        label: 'Política de privacidad',
                        description: 'Conoce cómo se usan tus datos',
                        onTap: () => _open(
                          context,
                          const LegalTextView(
                            title: 'Política de privacidad',
                            sections: privacySections,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        icon: Icons.description_rounded,
                        label: 'Términos de uso',
                        description: 'Reglas para usar VITA',
                        onTap: () => _open(
                          context,
                          const LegalTextView(
                            title: 'Términos de uso',
                            sections: termsSections,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(title: 'OTRAS ACCIONES'),
                  const SizedBox(height: 10),
                  _Card(
                    children: [
                      _MenuRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Solicitar eliminación de mis datos',
                        description: 'Pide borrar tu cuenta y tu información',
                        danger: true,
                        onTap: () => confirmDeletion(context),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        icon: Icons.logout_rounded,
                        label: 'Cerrar sesión',
                        description: 'Salir de tu cuenta en este dispositivo',
                        onTap: () => confirmLogout(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VitaColors.secondary, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: VitaColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: VitaText.overline.copyWith(color: VitaColors.muted),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.vita;
    return Semantics(
      button: true,
      label: '$label. $description',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 86),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: danger ? VitaColors.alertBg : VitaColors.tint,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    icon,
                    size: 29,
                    color: danger ? VitaColors.alert : VitaColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: danger ? VitaColors.alert : palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: VitaText.caption.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.muted,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
