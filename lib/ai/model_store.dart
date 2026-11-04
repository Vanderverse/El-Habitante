import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// A model is downloaded only on explicit user request. Conversation data
/// never reaches this HTTP client; it issues GET requests for GGUF bytes only.
class ModelStore {
  static const fileName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const sourceUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/'
      'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const expectedSha256 =
      '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e';

  HttpClient? _client;
  bool _cancelled = false;

  Future<File> modelFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$fileName');
  }

  Future<bool> isAvailable() async => (await modelFile()).exists();

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<File> download({required void Function(double) onProgress}) async {
    _cancelled = false;
    final destination = await modelFile();
    final partial = File('${destination.path}.partial');
    if (await destination.exists()) return destination;

    var existing = await partial.exists() ? await partial.length() : 0;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
    _client = client;
    try {
      final request = await client.getUrl(Uri.parse(sourceUrl));
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'El servidor respondió ${response.statusCode}.',
          uri: Uri.parse(sourceUrl),
        );
      }
      final isResume = existing > 0 &&
          response.statusCode == HttpStatus.partialContent &&
          response.headers.value(HttpHeaders.contentRangeHeader)
              ?.startsWith('bytes $existing-') == true;
      if (!isResume) existing = 0;
      final sink = partial.openWrite(
        mode: isResume ? FileMode.append : FileMode.write,
      );
      final total = response.contentLength > 0
          ? existing + response.contentLength
          : 0;
      var received = existing;
      var previousUpdate = -1;
      try {
        await for (final chunk in response) {
          if (_cancelled) throw const _Cancelled();
          sink.add(chunk);
          received += chunk.length;
          final percent = total > 0 ? (received * 100 ~/ total) : -1;
          if (percent != previousUpdate) {
            previousUpdate = percent;
            onProgress(total > 0 ? received / total : -1);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (_cancelled) throw const _Cancelled();
      // Verify a streaming digest instead of loading >1GB into memory.
      onProgress(1);
      final actual = (await sha256.bind(partial.openRead()).first).toString();
      if (actual != expectedSha256) {
        await partial.delete();
        throw const FormatException(
            'La descarga no pasó el control de integridad. Intentá otra vez.');
      }
      return partial.rename(destination.path);
    } on _Cancelled {
      throw const FileSystemException(
          'Descarga detenida. Podés reanudarla más adelante.');
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
