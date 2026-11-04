import 'package:flutter/foundation.dart';

import '../ai/local_brain.dart';
import '../data/habitat_repository.dart';
import '../domain/behavior_engine.dart';
import '../domain/habitant.dart';

class HabitatController extends ChangeNotifier {
  HabitatController({
    required this.repositoryFactory,
    DateTime Function()? clock,
    this.engine = const BehaviorEngine(),
    this.brain,
  }) : clock = clock ?? (() => DateTime.now().toUtc());

  final Future<HabitatRepository> Function() repositoryFactory;
  final DateTime Function() clock;
  final BehaviorEngine engine;
  final LocalBrain? brain;
  HabitatRepository? _repository;
  Habitant? state;
  bool loading = true;
  bool isReplying = false;
  bool _disposed = false;
  String? error;
  Future<void> _writes = Future.value();

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      final repository = await repositoryFactory();
      final saved = await repository.load();
      if (_disposed) return;
      _repository = repository;
      state = engine.advance(saved ?? Habitant.discover(clock()), clock());
      await save();
    } catch (_) {
      error = 'No pudimos leer los recuerdos. Tus archivos no se modificaron. '
          'Probá volver a cargar.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> interact(Interaction action) async {
    if (loading || state == null) return;
    final next = engine.interact(state!, action, clock());
    if (identical(next, state)) return;
    state = next;
    _notify();
    await save();
  }

  Future<void> converse(String message) async {
    if (loading || state == null || isReplying) return;
    final next = engine.converse(state!, message, clock());
    if (identical(next, state)) return;
    state = next;
    _notify();
    await save();

    final generator = brain;
    if (generator?.isActive != true) return;
    isReplying = true;
    _notify();
    try {
      final reply = await generator!.reply(state: next, userMessage: message);
      // Never overwrite a newer interaction if one occurred during inference.
      if (!_disposed && identical(state, next) && reply != null) {
        state = next.copyWith(lastReply: reply);
        _notify();
        await save();
      }
    } finally {
      isReplying = false;
      _notify();
    }
  }

  Future<void> reconcile() async {
    if (loading || state == null) return;
    final next = engine.advance(state!, clock());
    if (identical(next, state)) return;
    state = next;
    _notify();
    await save();
  }

  Future<void> save() async {
    final snapshot = state;
    final repository = _repository;
    if (snapshot == null || repository == null) return;
    // Serializa las escrituras de toques, temporizador y ciclo de vida.
    final write = _writes.then((_) => repository.save(snapshot));
    _writes = write.catchError((Object _) {});
    try {
      await write;
      error = null;
    } catch (_) {
      error = 'No pudimos guardar los últimos cambios. '
          'Mantené la aplicación abierta y volvé a intentar.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
