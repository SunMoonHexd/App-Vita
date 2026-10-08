import 'package:flutter/material.dart';
import 'package:vita_app/data/repositories/vita_repository.dart';

class VitaScope extends InheritedNotifier<VitaRepository> {
  const VitaScope({
    super.key,
    required VitaRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static VitaRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VitaScope>();
    assert(scope != null, 'VitaScope no encontrado');
    return scope!.notifier!;
  }
}
