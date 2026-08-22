import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Satu event Server-Sent Events yang sudah terurai dari stream.
class SseEvent {
  final String name;
  final String data;
  const SseEvent(this.name, this.data);
}

/// Klien SSE di atas Dio milik [ApiService], lengkap dengan reconnect backoff.
///
/// Dua jebakan saat memakai `ApiService.dio` untuk stream panjang, keduanya
/// sudah ditangani di sini:
///
/// 1. `receiveTimeout` bawaan 15 detik akan memutus koneksi, karena heartbeat
///    dari BE baru datang tiap 20 detik. Karena itu di-nol-kan (= tanpa batas)
///    khusus request ini.
/// 2. Interceptor 401 milik ApiService me-retry request dengan `Options` baru
///    yang kehilangan `responseType: stream` — hasil retry-nya jadi tidak bisa
///    dibaca sebagai stream. Retry itu dimatikan lewat `extra['__retried']`,
///    dan 401 diteruskan ke [onUnauthorized] supaya pemanggil memicu refresh
///    token lewat request biasa sebelum stream disambung ulang.
///
/// Stream BUKAN sumber kebenaran: frame yang jatuh saat offline hilang selamanya.
/// Pemanggil wajib menarik snapshot REST setiap kali [onStateChanged] bernilai
/// `true`.
class SseClient {
  SseClient({
    required this.dio,
    required this.path,
    this.queryParameters,
    this.onStateChanged,
    this.onUnauthorized,
  });

  final Dio dio;
  final String path;
  final Map<String, dynamic>? queryParameters;

  /// Dipanggil tiap koneksi tersambung (`true`) atau terputus (`false`).
  final void Function(bool connected)? onStateChanged;

  /// Dipanggil saat stream ditolak 401, sebelum percobaan sambung ulang.
  final Future<void> Function()? onUnauthorized;

  final _controller = StreamController<SseEvent>.broadcast();
  Stream<SseEvent> get events => _controller.stream;

  /// Jeda sambung ulang (detik) — naik bertahap, mentok di 13 detik.
  static const _backoff = [1, 2, 3, 5, 8, 13];

  CancelToken? _cancelToken;
  StreamSubscription<String>? _sub;
  Timer? _retryTimer;
  bool _stopped = false;
  int _attempt = 0;

  Future<void> connect() async {
    _stopped = false;
    await _open();
  }

  Future<void> _open() async {
    if (_stopped) return;
    await _closeSocket();

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      final res = await dio.get<ResponseBody>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero, // tanpa batas — lihat catatan di atas
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
          extra: {'__retried': true}, // jangan disentuh retry interceptor
        ),
      );

      if (_stopped || res.data == null) {
        cancelToken.cancel();
        return;
      }

      _attempt = 0;
      onStateChanged?.call(true);
      _listen(res.data!);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      debugPrint(
          '[SSE] gagal connect $path: ${e.response?.statusCode ?? e.message}');
      if (e.response?.statusCode == 401 && onUnauthorized != null) {
        await onUnauthorized!();
      }
      _scheduleReconnect();
    } catch (e) {
      debugPrint('[SSE] gagal connect $path: $e');
      _scheduleReconnect();
    }
  }

  void _listen(ResponseBody body) {
    // Parser SSE: kumpulkan baris `event:` & `data:` sampai ketemu baris kosong
    // yang menandai akhir satu frame. Baris `id:` dan `retry:` diabaikan —
    // sambung ulang selalu lewat snapshot, bukan Last-Event-ID.
    var eventName = 'message';
    final dataLines = <String>[];

    _sub = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            _controller.add(SseEvent(eventName, dataLines.join('\n')));
          }
          eventName = 'message';
          dataLines.clear();
          return;
        }
        if (line.startsWith(':')) return; // heartbeat
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      },
      onDone: _scheduleReconnect,
      onError: (Object e, StackTrace _) {
        debugPrint('[SSE] stream error: $e');
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    onStateChanged?.call(false);
    _attempt = (_attempt + 1).clamp(1, _backoff.length);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _backoff[_attempt - 1]), _open);
  }

  Future<void> _closeSocket() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _sub?.cancel();
    _sub = null;
    final token = _cancelToken;
    _cancelToken = null;
    if (token != null && !token.isCancelled) token.cancel();
  }

  Future<void> dispose() async {
    _stopped = true;
    await _closeSocket();
    await _controller.close();
  }
}
