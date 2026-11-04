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
    _notify();
    try {
      // Only short summaries of older events go into this prompt. The current
      // user message exists in memory only for the duration of this request.
      final memories = state.memories.reversed.take(6).toList().reversed
          .map((entry) => '- ${entry.text}').join('\n');
      final feelings = state.emotion.name;
      final system = '''
Sos El Habitante, criatura de una habitación enigmática. No sos un asistente.
Respondé en español natural y breve (1 a 3 frases). No ofrezcas servicios.
Tenés curiosidad ${state.personality.curiosity.toStringAsFixed(2)},
confianza ${state.personality.trust.toStringAsFixed(2)},
independencia ${state.personality.independence.toStringAsFixed(2)}.
Estado emocional: $feelings. Tu lugar tiene una marca misteriosa.
No inventes recuerdos. Dudá de afirmaciones sin pruebas.
El visitante afirmó haberte encerrado: ${state.visitorClaimedToEnclose ? 'sí, no confirmado' : 'no'}.
Recuerdos reales más recientes:
$memories
Si el visitante dijo haberte encerrado, recordá que es su afirmación,
no un hecho comprobado. Respondé a lo último que te pregunta.
''';
      final tokens = llama.generateChat(
        messages: [
          ChatMessage(role: 'system', content: system),
          ChatMessage(role: 'user', content: userMessage),
        ],
        template: 'chatml',
        maxTokens: 110,
        temperature: 0.65,
        topP: 0.9,
      );
      final reply = (await tokens.join().timeout(
        const Duration(seconds: 90),
      )).trim();
      return reply.isEmpty ? null : reply;
    } catch (e) {
      error = 'La IA no pudo responder. Se usó el modo básico: $e';
      _notify();
      try { await llama.stop(); } catch (_) {}
      return null;
    } finally {
      isResponding = false;
      _notify();
    }
  }

  Future<void> unload() async {
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
