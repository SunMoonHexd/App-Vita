import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
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
                  VitaAvatar(name: user.displayName, size: 96),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      user.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: (active ? VitaColors.tint : const Color(0xFFFFF0D6)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? VitaColors.primaryLight : const Color(0xFFE0A93B)),
                    ),
                    child: Text(
                      active ? '✓ Cuenta activa' : 'Cuenta ${user.status.name}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: active ? VitaColors.primary : const Color(0xFF8A5300),
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
                        padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
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
                      _DataRow(emoji: '📱', label: 'Teléfono', value: (user.phone ?? '').isEmpty ? 'Sin registrar' : user.phone!),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _DataRow(
                        emoji: '👤',
                        label: 'Familiar responsable',
                        value: _contact(user.familyName, user.familyPhone),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _DataRow(
                        emoji: '👤',
                        label: 'Contacto alternativo',
                        value: _contact(user.alternateName, user.alternatePhone),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    children: [
                      _MenuRow(
                        emoji: '✏️',
                        label: 'Editar mis datos',
                        onTap: () => _open(context, const ElderlyEditProfileView()),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        emoji: '🔑',
                        label: 'Cambiar PIN',
                        onTap: () => _open(context, const ElderlyChangePinView()),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        emoji: '📄',
                        label: 'Política de privacidad',
                        onTap: () => _open(
                          context,
                          const LegalTextView(title: 'Política de privacidad', sections: privacySections),
                        ),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        emoji: '📋',
                        label: 'Términos de uso',
                        onTap: () => _open(
                          context,
                          const LegalTextView(title: 'Términos de uso', sections: termsSections),
                        ),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        emoji: '🗑️',
                        label: 'Solicitar eliminación de mis datos',
                        danger: true,
                        onTap: () => confirmDeletion(context),
                      ),
                      const Divider(height: 1),
                      _MenuRow(
                        emoji: '🚪',
                        label: 'Cerrar sesión',
                        danger: true,
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.emoji, required this.label, required this.value});

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: VitaColors.muted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.emoji, required this.label, required this.onTap, this.danger = false});

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: danger ? VitaColors.alert : VitaColors.ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: VitaColors.muted),
          ],
        ),
      ),
    );
  }
}
