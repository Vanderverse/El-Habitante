import 'dart:async';

import 'package:flutter/material.dart';

import '../ai/local_brain.dart';
import '../application/habitat_controller.dart';
import '../data/habitat_repository.dart';
import '../domain/behavior_engine.dart';
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
  late final LocalBrain brain;
  late final HabitatController controller;
  late final Timer timer;
  final messageInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    brain = LocalBrain();
    controller = HabitatController(repositoryFactory: widget.repositoryFactory, brain: brain);
    unawaited(brain.initialize());
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
    messageInput.dispose();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    brain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, brain]),
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
                onCreatureTap: () => _interact(Interaction.greet),
                onMarkTap: () => _interact(Interaction.examineMark),
              ),
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      brain.isResponding
                          ? (brain.partialReply.trim().isEmpty
                              ? 'Está pensando…'
                              : brain.partialReply.trim())
                          : controller.engine.dialogue(state),
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
                    onPressed: () => _interact(Interaction.greet),
                    icon: const Icon(Icons.waving_hand_outlined),
                    label: const Text('Saludar'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _interact(Interaction.offerObject),
                    icon: const Icon(Icons.landscape_outlined),
                    label: const Text('Dejar una piedra'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _interact(Interaction.giveSpace),
                    icon: const Icon(Icons.nightlight_outlined),
                    label: const Text('Darle espacio'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _brainPanel(),
              const SizedBox(height: 18),
              const Text('Hablar con él',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(brain.isActive
                  ? 'Su mente local está activa. Puede conversar libremente; las respuestas pueden tardar unos segundos.'
                  : 'Sin modelo cargado, conversa mediante reglas sencillas. Activá su mente local para probar respuestas libres.'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: messageInput,
                    enabled: !controller.isReplying,
                    maxLength: 240,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '¿Qué le querés contar?',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar mensaje local',
                  onPressed: controller.isReplying ? null : _sendMessage,
                  icon: const Icon(Icons.send_outlined),
                ),
              ]),
              if (controller.isReplying) ...[
                const SizedBox(height: 8),
                const Row(children: [
                  SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Está escribiendo su respuesta...')),
                ]),
              ],
              if (state.interests.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_topicSummary(state),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              const Text(
                'Tocá a la criatura o dejale algo. Dale unos segundos entre '
                'gestos para responder. También hace cosas cuando no estás.',
                textAlign: TextAlign.center,
              ),
              if (state.mystery == MysteryStage.appeared) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _interact(Interaction.examineMark),
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


  Widget _brainPanel() {
    final state = brain.status;
    final busy = state == BrainStatus.downloading ||
        state == BrainStatus.loading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.psychology_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('Su mente local',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17))),
          ]),
          const SizedBox(height: 8),
          Text(switch (state) {
            BrainStatus.unavailable => 'Comprobando almacenamiento...',
            BrainStatus.readyToDownload =>
              'IA opcional Qwen2.5 1.5B (1,12 GB). Descarga única con Internet y Wi-Fi recomendado.',
            BrainStatus.downloading => brain.progress < 0
              ? 'Descargando modelo...'
              : 'Descargando: ${(brain.progress * 100).toStringAsFixed(0)} %',
            BrainStatus.readyToLoad =>
              'El modelo ya está descargado. Podés cargarlo en memoria.',
            BrainStatus.loading => 'Cargando el modelo. Puede tardar...',
            BrainStatus.active =>
              'IA funcionando en este dispositivo, sin enviar tus mensajes a Internet.',
            BrainStatus.failed => 'Hubo un problema con la IA local.',
          }),
          if (state == BrainStatus.downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: brain.progress < 0 ? null : brain.progress),
          ],
          if (brain.error != null) ...[
            const SizedBox(height: 8),
            Text(brain.error!, style: const TextStyle(color: Colors.deepOrange)),
          ],
          const SizedBox(height: 10),
          if (state == BrainStatus.readyToDownload)
            FilledButton.icon(
              onPressed: () => unawaited(brain.download()),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Descargar IA (aprox. 1,12 GB)'),
            ),
          if (state == BrainStatus.downloading)
            OutlinedButton.icon(
              onPressed: brain.cancelDownload,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Detener descarga'),
            ),
          if (state == BrainStatus.readyToLoad)
            FilledButton.icon(
              onPressed: () => unawaited(brain.load()),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Activar IA local'),
            ),
          if (state == BrainStatus.active)
            OutlinedButton(
              onPressed: brain.isResponding
                  ? null : () => unawaited(brain.unload()),
              child: const Text('Liberar memoria del teléfono'),
            ),
          if (state == BrainStatus.failed)
            OutlinedButton(
              onPressed: busy ? null : () => unawaited(_retryBrain()),
              child: const Text('Reintentar'),
            ),
          if (brain.lastGenerationDuration != null) ...[
            const SizedBox(height: 8),
            Text(
              'Última respuesta: ' +
                  brain.lastGenerationDuration!.inSeconds.toString() +
                  ' s · primer texto: ' +
                  (brain.lastFirstTokenDuration?.inSeconds.toString() ?? '?') +
                  ' s',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const Text('El modo básico continúa disponible. Descargá solo con '
              'espacio suficiente (recomendado: 2 GB libres).',
              style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  Future<void> _retryBrain() async {
    await brain.initialize();
    if (brain.status == BrainStatus.readyToLoad) {
      await brain.load();
    }
  }

  String _topicSummary(Habitant state) {
    final entries = state.interests.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topic = entries.first.key;
    return 'Recuerda que hablaron varias veces sobre ${BehaviorEngine.topicNames[topic] ?? 'otras cosas'}.';
  }

  void _sendMessage() {
    final text = messageInput.text.trim();
    if (text.isEmpty || controller.state == null || controller.loading || controller.isReplying) return;
    final last = controller.state!.lastInteractionAt;
    if (last != null &&
        DateTime.now().toUtc().difference(last) <
            BehaviorEngine.interactionCooldown) {
      _showInteractionFeedback('Dale un instante antes de volver a hablarle.');
      return;
    }
    messageInput.clear();
    FocusScope.of(context).unfocus();
    unawaited(controller.converse(text));
  }

  void _interact(Interaction action) {
    final state = controller.state;
    if (state == null || controller.loading || controller.isReplying) return;
    final last = state.lastInteractionAt;
    if (last != null) {
      final remaining = BehaviorEngine.interactionCooldown -
          DateTime.now().toUtc().difference(last);
      if (remaining > Duration.zero) {
        _showInteractionFeedback(
          'Dale un instante para responder antes del próximo gesto.',
        );
        return;
      }
    }

    // Los botones reaccionan a un toque breve, no requieren pulsación larga.
    unawaited(controller.interact(action));
    _showInteractionFeedback(switch (action) {
      Interaction.greet => 'Te acercaste a saludarlo.',
      Interaction.offerObject => 'Dejaste una piedra en su habitación.',
      Interaction.giveSpace => 'Le diste espacio para estar a su manera.',
      Interaction.examineMark => 'Examinaste la marca misteriosa.',
    });
  }

  void _showInteractionFeedback(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
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
                if (state.interests.isNotEmpty) ...[
                  const Text('Intereses que está descubriendo',
                      style: TextStyle(fontSize: 18)),
                  for (final entry in (state.interests.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value))))
                    Text('${BehaviorEngine.topicNames[entry.key] ?? entry.key}: ${entry.value} conversaciones'),
                  const Divider(height: 32),
                ],
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
