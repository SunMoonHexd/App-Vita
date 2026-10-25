import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/auth_widgets.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

/// Peso máximo de la foto ya reducida. Una foto de 400 px pesa unos 30-60 KB, así que este
/// límite deja mucho margen y mantiene lejos el tope de 1 MB por documento de Firestore.
const int _maxPhotoBytes = 220 * 1024;

enum _PhotoAction { camera, gallery, remove }

/// Avatar de la persona con una cámara pequeña y el texto "Cambiar foto". Al tocarlo se abre
/// el selector (cámara, galería o quitar).
class VitaPhotoAvatar extends StatelessWidget {
  const VitaPhotoAvatar({super.key, required this.user, this.size = 96});

  final VitaUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.vita;
    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => changeProfilePhoto(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                VitaAvatar(
                  name: user.displayName,
                  size: size,
                  photoBase64: user.photoBase64,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: size * 0.36,
                    height: size * 0.36,
                    decoration: BoxDecoration(
                      color: VitaColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 3),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: size * 0.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VitaSpace.sm),
            Text(
              user.photoBase64 == null ? 'Agregar foto' : 'Cambiar foto',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: p.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pregunta de dónde sacar la foto, la reduce y la guarda en el perfil.
Future<void> changeProfilePhoto(BuildContext context) async {
  final repo = VitaScope.of(context);
  final user = repo.currentUser;
  if (user == null) return;

  final action = await showModalBottomSheet<_PhotoAction>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Foto de perfil', style: VitaText.title),
            const SizedBox(height: 4),
            Text(
              'La ves tú y coordinación; durante una llamada también la verá la otra persona.',
              style: VitaText.caption.copyWith(color: sheetContext.vita.muted),
            ),
            const SizedBox(height: VitaSpace.md),
            _PhotoOption(
              icon: Icons.photo_camera_rounded,
              label: 'Tomar una foto',
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.camera),
            ),
            _PhotoOption(
              icon: Icons.photo_library_rounded,
              label: 'Elegir de la galería',
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.gallery),
            ),
            if (user.photoBase64 != null)
              _PhotoOption(
                icon: Icons.delete_outline_rounded,
                label: 'Quitar foto',
                danger: true,
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  if (action == _PhotoAction.remove) {
    await repo.setProfilePhoto(null);
    return;
  }

  try {
    // La librería reduce la imagen al elegirla: máximo 400 px de lado y calidad 75.
    final file = await ImagePicker().pickImage(
      source: action == _PhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return; // cerró el selector sin elegir nada
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      if (context.mounted)
        await showVitaMessage(
          context,
          'La foto es muy pesada. Prueba con otra.',
        );
      return;
    }
    await repo.setProfilePhoto(base64Encode(bytes));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto actualizada')));
    }
  } catch (e) {
    debugPrint('No se pudo cambiar la foto: $e');
    if (context.mounted) {
      await showVitaMessage(
        context,
        'No se pudo abrir la cámara o la galería. Revisa que VITA tenga permiso en los ajustes del celular.',
      );
    }
  }
}

class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.vita;
    final color = danger ? p.dangerTone.fg : p.ink;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: danger ? p.dangerTone.bg : p.tint,
        child: Icon(icon, size: 28, color: danger ? p.dangerTone.fg : p.accent),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
