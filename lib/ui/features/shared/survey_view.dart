import 'package:flutter/material.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class SurveyView extends StatefulWidget {
  const SurveyView({super.key, required this.request, required this.askAccompanied});

  final CallRequest request;
  final bool askAccompanied;

  @override
  State<SurveyView> createState() => _SurveyViewState();
}

class _SurveyViewState extends State<SurveyView> {
  int? _experience;
  int? _accompanied;

  Future<void> _send() async {
    final user = VitaScope.of(context).currentUser;
    if (user == null || _experience == null) return;
    await VitaScope.of(context).saveSurvey(
      CallSurvey(
        callId: widget.request.id,
        userId: user.id,
        experience: _experience!,
        feltAccompanied: _accompanied,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: '¿Cómo te fue?',
      child: ListView(
        children: [
          const Text('¿Cómo fue la experiencia?'),
          const SizedBox(height: 8),
          _Faces(value: _experience, onChanged: (v) => setState(() => _experience = v)),
          if (widget.askAccompanied) ...[
            const SizedBox(height: 24),
            const Text('¿Te sentiste acompañado?'),
            const SizedBox(height: 8),
            _Faces(value: _accompanied, onChanged: (v) => setState(() => _accompanied = v)),
          ],
          const SizedBox(height: 28),
          VitaPrimaryButton(label: 'Enviar', onPressed: _experience == null ? null : _send),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ahora no')),
        ],
      ),
    );
  }
}

class _Faces extends StatelessWidget {
  const _Faces({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const faces = [
      (1, Icons.sentiment_very_dissatisfied, 'Mal'),
      (2, Icons.sentiment_neutral, 'Regular'),
      (3, Icons.sentiment_very_satisfied, 'Bien'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final face in faces)
          InkWell(
            onTap: () => onChanged(face.$1),
            child: Column(
              children: [
                Icon(face.$2, size: 56, color: value == face.$1 ? Colors.green : Colors.grey),
                Text(face.$3),
              ],
            ),
          ),
      ],
    );
  }
}
