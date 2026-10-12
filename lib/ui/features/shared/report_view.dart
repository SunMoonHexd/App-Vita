import 'package:flutter/material.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/domain/models/vita_models.dart';
import 'package:vita_app/ui/core/vita_scope.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key, required this.request, required this.reportedId});

  final CallRequest request;
  final String reportedId;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  static const reasons = [
    'Comportamiento inapropiado',
    'Lenguaje ofensivo',
    'Solicitud de dinero o datos',
    'Otro',
  ];

  String? _reason;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) {
      await showVitaMessage(context, 'Selecciona un motivo.');
      return;
    }
    await VitaScope.of(context).addReport(
      callId: widget.request.id,
      reportedId: widget.reportedId,
      reason: _reason!,
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
    );
    if (!mounted) return;
    await showVitaMessage(context, 'Reporte enviado. Coordinación lo revisará.');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return VitaPage(
      title: 'Reportar',
      child: ListView(
        children: [
          for (final reason in reasons)
            RadioListTile<String>(
              value: reason,
              groupValue: _reason,
              title: Text(reason),
              onChanged: (v) => setState(() => _reason = v),
            ),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
          ),
          const SizedBox(height: 16),
          VitaPrimaryButton(label: 'Enviar reporte', color: VitaColors.alert, onPressed: _send),
        ],
      ),
    );
  }
}
