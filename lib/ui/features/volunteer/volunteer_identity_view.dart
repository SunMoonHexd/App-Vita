import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class VolunteerIdentityView extends StatefulWidget {
  const VolunteerIdentityView({super.key});

  @override
  State<VolunteerIdentityView> createState() => _VolunteerIdentityViewState();
}

class _VolunteerIdentityViewState extends State<VolunteerIdentityView> {
  String? _front;
  String? _back;
  bool _consent = false;
  bool _busy = false;

  Future<String?> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Tomar foto'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de galería'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])),
    );
    if (source == null) return null;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 65);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 220 * 1024) throw Exception('La imagen pesa demasiado. Intenta de nuevo con más luz y enfocando solo la cédula.');
    return base64Encode(bytes);
  }

  Future<void> _save() async {
    if (!_consent) {
      await showVitaMessage(context, 'Autoriza el uso de la cédula para verificar tu identidad.');
      return;
    }
    if (_front == null || _back == null) {
      await showVitaMessage(context, 'Carga el frente y el reverso de la cédula.');
      return;
    }
    setState(() => _busy = true);
    try {
      await VitaScope.of(context).saveVolunteerIdentityDocuments(front: _front!, back: _back!);
      if (!mounted) return;
      await showVitaMessage(context, 'Documentos guardados en forma privada. Coordinación debe verificarlos; mientras tanto no recibirás nuevas asignaciones.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) await showVitaMessage(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirar autorización'),
        content: const Text('Se borrarán las imágenes de tu cédula. Coordinación dejará de considerar tu identidad verificada y no recibirás nuevas asignaciones hasta que vuelvas a cargarla y sea revisada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Retirar y borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await VitaScope.of(context).withdrawVolunteerIdentityConsent();
    if (!mounted) return;
    await showVitaMessage(context, 'Autorización retirada y documentos eliminados del perfil.');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => VitaPage(
        title: 'Verificar mi identidad',
        child: ListView(children: [
          const Text('Sube el frente y el reverso de tu cédula. Solo tú y coordinación podrán ver las imágenes. No se mostrarán a los adultos mayores.'),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: () async { try { final image = await _pick(); if (image != null) setState(() => _front = image); } catch (e) { if (mounted) await showVitaMessage(context, e.toString().replaceFirst('Exception: ', '')); } }, icon: const Icon(Icons.badge_outlined), label: Text(_front == null ? 'Cargar frente' : 'Cambiar frente')),
          if (_front != null) Image.memory(base64Decode(_front!), height: 140, fit: BoxFit.contain),
          OutlinedButton.icon(onPressed: () async { try { final image = await _pick(); if (image != null) setState(() => _back = image); } catch (e) { if (mounted) await showVitaMessage(context, e.toString().replaceFirst('Exception: ', '')); } }, icon: const Icon(Icons.badge_outlined), label: Text(_back == null ? 'Cargar reverso' : 'Cambiar reverso')),
          if (_back != null) Image.memory(base64Decode(_back!), height: 140, fit: BoxFit.contain),
          CheckboxListTile(
            value: _consent,
            onChanged: (value) => setState(() => _consent = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Autorizo a VITA y a coordinación a tratar las imágenes de mi cédula exclusivamente para verificar mi identidad y decidir mi vinculación como voluntario.'),
          ),
          const SizedBox(height: 12),
          VitaPrimaryButton(label: _busy ? 'Guardando…' : 'Guardar y solicitar verificación', onPressed: _busy ? null : _save),
          const SizedBox(height: 10),
          TextButton(onPressed: _busy ? null : _withdraw, child: const Text('Retirar autorización y borrar mi cédula')),
        ]),
      );
}
