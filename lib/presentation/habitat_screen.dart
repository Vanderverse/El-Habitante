import 'dart:async';

import 'package:flutter/material.dart';

import '../application/habitat_controller.dart';
import '../data/habitat_repository.dart';
import '../domain/habitant.dart';
import 'room_view.dart';

class HabitatScreen extends StatefulWidget {
  const HabitatScreen({super.key, required this.repositoryFactory});

  final Future<HabitatRepository> Function() repositoryFactory;

  @override
  State<HabitatScreen> createState() => _HabitatScreenState();
}

class _HabitatScreenState extends State<HabitatScreen>
    with WidgetsBindingObserver {
  late final HabitatController controller;
  late final Timer timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = HabitatController(repositoryFactory: widget.repositoryFactory);
    unawaited(controller.load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(controller.reconcile());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.reconcile());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(controller.save());
    }
  }

  @override
  void dispose() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('El Habitante'),
        actions: [
          IconButton(
            tooltip: 'Recuerdos y personalidad',
            onPressed: controller.state == null
                ? null
                : () => _showMemories(context),
            icon: const Icon(Icons.auto_stories_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _body(context)),
    ),
  );

  Widget _body(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final state = controller.state;
    if (state == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(controller.error ?? 'No se pudo abrir la habitación.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.load,
                child: const Text('Volver a cargar'),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hay alguien del otro lado.',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text('${_emotion(state.emotion)} · ${_activity(state.activity)}'),
              const SizedBox(height: 18),
              RoomView(
                state: state,
                onCreatureTap: () => controller.interact(Interaction.greet),
                onMarkTap: () => controller.interact(Interaction.examineMark),
              ),
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      controller.engine.dialogue(state),
                      style: const TextStyle(fontSize: 18, height: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => controller.interact(Interaction.greet),
                    icon: const Icon(Icons.waving_hand_outlined),
                    label: const Text('Saludar'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => controller.interact(Interaction.offerObject),
                    icon: const Icon(Icons.landscape_outlined),
                    label: const Text('Dejar una piedra'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => controller.interact(Interaction.giveSpace),
                    icon: const Icon(Icons.nightlight_outlined),
                    label: const Text('Darle espacio'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tocá a la criatura o dejale algo. Dale unos segundos entre '
                'gestos para responder. También hace cosas cuando no estás.',
                textAlign: TextAlign.center,
              ),
              if (state.mystery == MysteryStage.appeared) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => controller.interact(Interaction.examineMark),
                  icon: const Icon(Icons.search),
                  label: const Text('Examinar la marca de la pared'),
                ),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: controller.save,
                  child: const Text('Reintentar guardado'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMemories(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state!;
          final p = state.personality;
          return FractionallySizedBox(
            heightFactor: 0.85,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Su mundo interior',
                          style: TextStyle(fontSize: 23)),
                    ),
                    IconButton(
                      tooltip: 'Cerrar recuerdos',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Los rasgos evolucionan por separado. No hay una puntuación '
                  'que debas maximizar.',
                ),
                const SizedBox(height: 16),
                Text('Curiosidad: ${_trait(p.curiosity)}'),
                Text('Confianza: ${_trait(p.trust)}'),
                Text('Independencia: ${_trait(p.independence)}'),
                Text('Sensibilidad: ${_trait(p.sensitivity)}'),
                const Divider(height: 32),
                const Text('Recuerdos', style: TextStyle(fontSize: 20)),
                for (final memory in state.memories.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(memory.kind == MemoryKind.mystery
                        ? Icons.auto_awesome_outlined
                        : Icons.circle_outlined),
                    title: Text(memory.text),
                    subtitle: Text(_date(memory.at.toLocal())),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Todo queda en este dispositivo, sin cuentas ni servicios '
                  'externos. Desinstalar o borrar los datos elimina los recuerdos.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _trait(double value) => value < 0.4
      ? 'en desarrollo'
      : value > 0.65
      ? 'marcada'
      : 'moderada';

  String _date(DateTime at) =>
      '${at.day}/${at.month}/${at.year} '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  String _emotion(Emotion emotion) => switch (emotion) {
    Emotion.curious => 'Siente curiosidad',
    Emotion.calm => 'Está en calma',
    Emotion.cautious => 'Está cauteloso',
    Emotion.reserved => 'Está reservado',
  };

  String _activity(Activity activity) => switch (activity) {
    Activity.observing => 'Observa',
    Activity.exploring => 'Explora',
    Activity.resting => 'Descansa',
  };
}
