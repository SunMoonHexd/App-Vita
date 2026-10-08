import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class ElderlyProfileView extends StatefulWidget {
  const ElderlyProfileView({super.key});

  @override
  State<ElderlyProfileView> createState() => _ElderlyProfileViewState();
}

class _ElderlyProfileViewState extends State<ElderlyProfileView> {
  late final TextEditingController _phone;
  late final TextEditingController _familyName;
  late final TextEditingController _familyPhone;
  late final TextEditingController _altName;
  late final TextEditingController _altPhone;

  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final user = VitaScope.of(context).currentUser;
    _phone = TextEditingController(text: user?.phone);
    _familyName = TextEditingController(text: user?.familyName);
    _familyPhone = TextEditingController(text: user?.familyPhone);
    _altName = TextEditingController(text: user?.alternateName);
    _altPhone = TextEditingController(text: user?.alternatePhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _familyName.dispose();
    _familyPhone.dispose();
    _altName.dispose();
    _altPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Mi perfil',
      child: ListView(
        children: [
          const Text(termsText),
          const SizedBox(height: 16),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: 12),
          TextField(controller: _familyName, decoration: const InputDecoration(labelText: 'Familiar')),
          const SizedBox(height: 12),
          TextField(controller: _familyPhone, decoration: const InputDecoration(labelText: 'Teléfono familiar')),
          const SizedBox(height: 12),
          TextField(controller: _altName, decoration: const InputDecoration(labelText: 'Contacto alternativo')),
          const SizedBox(height: 12),
          TextField(controller: _altPhone, decoration: const InputDecoration(labelText: 'Teléfono alternativo')),
          const SizedBox(height: 16),
          VitaPrimaryButton(
            label: 'Guardar cambios',
            onPressed: () async {
              await VitaScope.of(context).updateProfile(
                phone: _phone.text.trim(),
                familyName: _familyName.text.trim(),
                familyPhone: _familyPhone.text.trim(),
                alternateName: _altName.text.trim(),
                alternatePhone: _altPhone.text.trim(),
              );
              if (context.mounted) await showVitaMessage(context, 'Perfil actualizado.');
            },
          ),
          const SizedBox(height: 12),
          VitaPrimaryButton(
            label: 'Cerrar sesión',
            color: Colors.blueGrey,
            onPressed: () async {
              await VitaScope.of(context).logout();
              if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar cuenta'),
                  content: const Text('Se eliminarán tus datos personales de este prototipo.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await VitaScope.of(context).requestAccountDeletion();
                if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: const Text('Eliminar mi cuenta y datos'),
          ),
        ],
      ),
    );
  }
}
