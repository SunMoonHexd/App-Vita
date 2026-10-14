import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';
import 'package:vita_app/ui/features/shared/report_view.dart';

class SurveyView extends StatefulWidget {
  const SurveyView({super.key, required this.request, required this.askAccompanied});

  final CallRequest request;
  final bool askAccompanied;

  @override
  State<SurveyView> createState() => _SurveyViewState();
}

class _SurveyViewState extends State<SurveyView> {
  /// Persona que se puede reportar desde esta encuesta (la otra parte de la llamada).
  String? get _reportedId => widget.askAccompanied ? widget.request.volunteerId : widget.request.elderlyId;

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
          // RF35: solo el adulto mayor, y solo si la llamada se cortó.
          ListenableBuilder(
            listenable: VitaScope.of(context),
            builder: (context, _) {
              final current = VitaScope.of(context).requests.cast<CallRequest?>().firstWhere(
                    (r) => r?.id == widget.request.id,
                    orElse: () => null,
                  );
              final cut = current?.status == CallRequestStatus.interrupted;
              if (!cut) return const SizedBox.shrink();
              return Column(
                children: [
                  const Text(
                    'La llamada se cortó.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (widget.askAccompanied)
                    // Solo el adulto mayor puede pedir la llamada de nuevo (RF35).
                    VitaPrimaryButton(label: 'Llamar de nuevo', onPressed: () => Navigator.pop(context, true))
                  else
                    const Text(
                      'Gracias por acompañar. Si la persona vuelve a llamar, es posible que te llegue una nueva solicitud.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 28),
                ],
              );
            },
          ),
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
          // Reportar a la otra persona de la llamada: el adulto mayor reporta al voluntario y al revés.
          if (_reportedId != null)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportView(request: widget.request, reportedId: _reportedId!)),
              ),
              child: Text(widget.askAccompanied ? 'Reportar al voluntario' : 'Reportar al adulto mayor'),
            ),
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
                Icon(face.$2, size: 56, color: value == face.$1 ? VitaColors.secondary : Colors.grey),
                Text(face.$3),
              ],
            ),
          ),
      ],
    );
  }
}
