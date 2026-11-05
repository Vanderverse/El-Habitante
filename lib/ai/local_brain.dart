import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../domain/habitant.dart';
import 'model_store.dart';

enum BrainStatus { unavailable, readyToDownload, downloading, readyToLoad, loading, active, failed }

/// Local text generation. No conversation history is ever posted to a server.
class LocalBrain extends ChangeNotifier {
  LocalBrain({ModelStore? modelStore}) : store = modelStore ?? ModelStore();

  final ModelStore store;
  LlamaController? _llama;
  BrainStatus status = BrainStatus.unavailable;
  double progress = 0;
  String? error;
  bool isResponding = false;
  String partialReply = '';
  Duration? lastGenerationDuration;
  Duration? lastFirstTokenDuration;
  // Hasta dos intercambios temporales; las frases literales no se guardan.
  final List<ChatMessage> _recentTurns = [];
  bool _disposed = false;

  bool get isActive => status == BrainStatus.active;

  Future<void> initialize() async {
    try {
      status = await store.isAvailable()
          ? BrainStatus.readyToLoad : BrainStatus.readyToDownload;
    } catch (e) {
      status = BrainStatus.unavailable;
      error = 'No se pudo comprobar el almacenamiento: $e';
    }
    _notify();
  }

  Future<void> download() async {
    if (status == BrainStatus.downloading || status == BrainStatus.loading) {
      return;
    }
    status = BrainStatus.downloading;
    progress = 0;
    error = null;
    _notify();
    try {
      await store.download(onProgress: (value) {
        progress = value;
        _notify();
      });
      status = BrainStatus.readyToLoad;
      progress = 1;
    } catch (e) {
      error = e.toString();
      status = BrainStatus.failed;
    }
    _notify();
  }

  void cancelDownload() => store.cancel();

  Future<void> load() async {
    if (status == BrainStatus.loading || isActive) return;
    if (!await store.isAvailable()) {
      status = BrainStatus.readyToDownload;
      _notify();
      return;
    }
    status = BrainStatus.loading;
    error = null;
    _notify();
    try {
      final controller = LlamaController();
      await controller.loadModel(
        modelPath: (await store.modelFile()).path,
        threads: 3,
        contextSize: 1024,
        gpuLayers: 0, // CPU-first baseline for a 4 GB Galaxy A07.
      );
      _llama = controller;
      status = BrainStatus.active;
    } catch (e) {
      status = BrainStatus.failed;
      error = 'No se pudo cargar la IA en memoria: $e';
    }
    _notify();
  }

  Future<String?> reply({
    required Habitant state,
    required String userMessage,
  }) async {
    final llama = _llama;
    if (llama == null || !isActive || isResponding) return null;
    isResponding = true;
    partialReply = '';
    error = null;
    _notify();
    final watch = Stopwatch()..start();
    try {
      // Un contexto acotado evita arrastrar conversaciones y consumir la
      // memoria KV del teléfono. Los recuerdos se reconstruyen en el prompt.
      await llama.clearContext();
      final tokens = llama.generateChat(
        messages: [
          ChatMessage(role: 'system', content: buildHabitantPrompt(state)),
          ..._recentTurns,
          ChatMessage(role: 'user', content: userMessage),
        ],
        template: 'chatml',
        // El límite anterior, 110, podía interrumpir frases inconclusas.
        maxTokens: 160,
        temperature: 0.65,
        topP: 0.9,
      );
      Future<String> collect() async {
        final output = StringBuffer();
        var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
        var reportedLength = 0;
        var first = true;
        await for (final chunk in tokens) {
          if (first) {
            first = false;
            lastFirstTokenDuration = watch.elapsed;
          }
          output.write(chunk);
          final now = DateTime.now();
          if (output.length - reportedLength >= 12 ||
              now.difference(lastUpdate) >=
                  const Duration(milliseconds: 280)) {
            partialReply = output.toString();
            reportedLength = output.length;
            lastUpdate = now;
            _notify();
          }
        }
        return output.toString().trim();
      }

      final result = await collect().timeout(const Duration(seconds: 105));
      if (result.isEmpty) return null;
      _recentTurns.add(ChatMessage(role: 'user', content: userMessage));
      _recentTurns.add(ChatMessage(role: 'assistant', content: result));
      while (_recentTurns.length > 4) {
        _recentTurns.removeRange(0, 2);
      }
      return result;
    } catch (e) {
      error = 'La IA no pudo terminar la respuesta; modo básico: $e';
      _notify();
      try {
        await llama.stop();
      } catch (_) {}
      return null;
    } finally {
      watch.stop();
      lastGenerationDuration = watch.elapsed;
      partialReply = '';
      isResponding = false;
      _notify();
    }
  }

  Future<void> unload() async {
    _recentTurns.clear();
    partialReply = '';
    final llama = _llama;
    _llama = null;
    if (llama != null) await llama.dispose();
    status = await store.isAvailable()
        ? BrainStatus.readyToLoad : BrainStatus.readyToDownload;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    store.cancel();
    // UI owners call unload before disposal whenever possible.
    _llama?.stop();
    _llama?.dispose();
    super.dispose();
  }
}

/// Prompt corto para reducir el procesamiento inicial en CPUs modestos.
@visibleForTesting
String buildHabitantPrompt(Habitant state) {
  final recentMemories = state.memories.reversed
      .take(3)
      .map((memory) => memory.text)
      .join(' | ');
  final mood = switch (state.emotion) {
    Emotion.curious => 'curioso',
    Emotion.calm => 'sereno',
    Emotion.cautious => 'cauteloso',
    Emotion.reserved => 'reservado',
  };
  final claim = state.visitorClaimedToEnclose
      ? 'El visitante dijo haberte encerrado. Es una afirmación sin pruebas.'
      : 'Desconocés el origen de la habitación.';
  final trust = state.personality.trust.toStringAsFixed(1);
  return '''
Sos El Habitante, una criatura viva que habita una habitación misteriosa.
Hablá en español natural, en primera persona y desde tus propias experiencias.
Respondé directamente y en una o dos frases cortas y completas.
Mostrá emociones, opiniones y dudas. Evitá explicaciones sobre tu identidad artificial.
Si te preguntan quién sos, contá qué hacés y sentís en tu habitación.
Ánimo: $mood. Confianza en el visitante (de 0 a 1): $trust.
$claim
Recuerdos: $recentMemories
''';
}
