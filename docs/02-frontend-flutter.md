# Spec: Flutter — Kitchen Display System (KDS)

**Repo:** app Flutter POS
**Tujuan:** layar dapur yang menampilkan pesanan terbayar secara realtime.

Baca `README.md` untuk prinsip umum. Kontrak API ada di `01-backend-golang.md`.

---

## 1. Dependency

```yaml
dependencies:
  http: ^1.2.0
  provider: ^6.1.2
  wakelock_plus: ^1.2.5   # layar dapur tidak boleh mati
```

---

## 2. File baru: `lib/features/kds/kds_realtime.dart`

Berisi model, SSE client, dan controller. Buat apa adanya.

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ------------------------------------------------------------ Models

class KdsOrderItem {
  final String id;
  final String name;
  final int qty;
  final List<String> variants;
  final String note;

  KdsOrderItem({
    required this.id,
    required this.name,
    required this.qty,
    this.variants = const [],
    this.note = '',
  });

  factory KdsOrderItem.fromJson(Map<String, dynamic> json) => KdsOrderItem(
        id: json['id'] as String,
        name: json['name'] as String,
        qty: json['qty'] as int,
        variants: (json['variants'] as List?)?.cast<String>() ?? const [],
        note: json['note'] as String? ?? '',
      );
}

class KdsOrder {
  final String id;
  final String orderNumber;
  final String tableOrTag;
  final String orderType;
  final String status;
  final List<KdsOrderItem> items;
  final DateTime paidAt;
  final String cashierName;

  KdsOrder({
    required this.id,
    required this.orderNumber,
    required this.tableOrTag,
    required this.orderType,
    required this.status,
    required this.items,
    required this.paidAt,
    required this.cashierName,
  });

  factory KdsOrder.fromJson(Map<String, dynamic> json) => KdsOrder(
        id: json['id'] as String,
        orderNumber: json['order_number'] as String,
        tableOrTag: json['table_or_tag'] as String? ?? '',
        orderType: json['order_type'] as String? ?? 'dine_in',
        status: json['status'] as String? ?? 'queued',
        items: (json['items'] as List? ?? [])
            .map((e) => KdsOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        paidAt: DateTime.parse(json['paid_at'] as String).toLocal(),
        cashierName: json['cashier_name'] as String? ?? '',
      );

  Duration get waiting => DateTime.now().difference(paidAt);
}

// ------------------------------------------------------------ SSE client

class SseEvent {
  final String name;
  final String data;
  const SseEvent(this.name, this.data);
}

class SseClient {
  SseClient({
    required this.endpoint,
    required this.headersBuilder,
    this.onStateChanged,
  });

  final Uri endpoint;
  final Future<Map<String, String>> Function() headersBuilder;
  final void Function(bool connected)? onStateChanged;

  final _controller = StreamController<SseEvent>.broadcast();
  Stream<SseEvent> get events => _controller.stream;

  http.Client? _http;
  StreamSubscription<String>? _sub;
  Timer? _retryTimer;
  bool _stopped = false;
  int _attempt = 0;

  Future<void> connect() async {
    _stopped = false;
    await _openStream();
  }

  Future<void> _openStream() async {
    if (_stopped) return;
    await _cleanupSocket();
    _http = http.Client();

    try {
      final request = http.Request('GET', endpoint)
        ..headers.addAll(await headersBuilder())
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await _http!.send(request);
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}');
      }

      _attempt = 0;
      onStateChanged?.call(true);

      var eventName = 'message';
      final dataLines = <String>[];

      _sub = response.stream
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
          debugPrint('[SSE] error: $e');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[SSE] gagal connect: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    onStateChanged?.call(false);
    _attempt = (_attempt + 1).clamp(1, 6);
    final delay = Duration(seconds: [1, 2, 3, 5, 8, 13][_attempt - 1]);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _openStream);
  }

  Future<void> _cleanupSocket() async {
    _retryTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    _http?.close();
    _http = null;
  }

  Future<void> dispose() async {
    _stopped = true;
    await _cleanupSocket();
    await _controller.close();
  }
}

// ------------------------------------------------------------ Controller

class KdsController extends ChangeNotifier {
  KdsController({
    required this.baseUrl,
    required this.tenantId,
    required this.outletId,
    required this.tokenProvider,
  });

  final String baseUrl;
  final String tenantId;
  final String outletId;
  final Future<String> Function() tokenProvider;

  final List<KdsOrder> _orders = [];
  List<KdsOrder> get orders => List.unmodifiable(_orders);

  bool _connected = false;
  bool get connected => _connected;

  bool _loading = true;
  bool get loading => _loading;

  SseClient? _sse;

  Future<Map<String, String>> _headers() async => {
        'Authorization': 'Bearer ${await tokenProvider()}',
      };

  Future<void> start() async {
    _sse = SseClient(
      endpoint: Uri.parse(
        '$baseUrl/api/v1/kds/stream?tenant_id=$tenantId&outlet_id=$outletId',
      ),
      headersBuilder: _headers,
      onStateChanged: (isConnected) {
        _connected = isConnected;
        notifyListeners();
        if (isConnected) unawaited(_loadSnapshot()); // resync wajib
      },
    );

    _sse!.events.listen(_onEvent);
    await _loadSnapshot();
    await _sse!.connect();
  }

  Future<void> _loadSnapshot() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/kds/orders'
            '?tenant_id=$tenantId&outlet_id=$outletId'
            '&status=queued,preparing,ready'),
        headers: await _headers(),
      );
      if (res.statusCode != 200) return;

      final list = (jsonDecode(res.body)['data'] as List)
          .map((e) => KdsOrder.fromJson(e as Map<String, dynamic>))
          .toList();

      _orders
        ..clear()
        ..addAll(list);
      _sort();
    } catch (e) {
      debugPrint('[KDS] snapshot gagal: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onEvent(SseEvent event) {
    late final KdsOrder order;
    try {
      order = KdsOrder.fromJson(jsonDecode(event.data) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[KDS] payload tidak valid: $e');
      return;
    }

    switch (event.name) {
      case 'order.paid':
        _upsert(order);
        // TODO: buzzer + haptic
        break;
      case 'order.status_changed':
        if (order.status == 'served') {
          _orders.removeWhere((o) => o.id == order.id);
        } else {
          _upsert(order);
        }
        break;
      case 'order.voided':
        _orders.removeWhere((o) => o.id == order.id);
        break;
    }
    _sort();
    notifyListeners();
  }

  void _upsert(KdsOrder order) {
    final i = _orders.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      _orders[i] = order;
    } else {
      _orders.add(order);
    }
  }

  void _sort() => _orders.sort((a, b) => a.paidAt.compareTo(b.paidAt));

  Future<void> updateStatus(String orderId, String status) async {
    await http.patch(
      Uri.parse('$baseUrl/api/v1/kds/orders/$orderId/status'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
  }

  @override
  void dispose() {
    _sse?.dispose();
    super.dispose();
  }
}
```

---

## 3. Halaman `lib/features/kds/kds_screen.dart`

Buat `StatefulWidget` dengan `WidgetsBindingObserver`.

**Wajib ada:**

1. `WakelockPlus.enable()` di `initState`, `disable()` di `dispose`.
2. `didChangeAppLifecycleState`: saat `resumed`, panggil `controller.start()`
   ulang — di Android/iOS koneksi socket mati saat app di background.
3. `Timer.periodic(Duration(seconds: 1))` hanya untuk me-refresh label durasi
   tunggu; jangan dipakai untuk fetch data.
4. Badge status koneksi: hijau bila `controller.connected`, merah + teks
   "Terputus, mencoba menyambung..." bila tidak.

**Layout kartu (GridView, `crossAxisCount` 3 untuk tablet landscape):**

- Header: `orderNumber` besar + `tableOrTag` + badge `orderType`.
- Body: daftar item `2× Es Teh Manis`, varian sebagai chip kecil, `note`
  ditonjolkan (misal latar kuning) karena paling sering terlewat.
- Footer: timer `MM:SS` + tombol aksi.

**Warna border berdasarkan `order.waiting`:**

| Durasi | Warna |
|---|---|
| < 3 menit | hijau |
| 3–6 menit | kuning |
| > 6 menit | merah + animasi pulse |

**Tombol aksi berdasarkan status:**

- `queued` → tombol "Mulai" → `updateStatus(id, 'preparing')`
- `preparing` → tombol "Siap" → `updateStatus(id, 'ready')`
- `ready` → tombol "Diantar" → `updateStatus(id, 'served')` (kartu hilang)

Terapkan optimistic UI: ubah status lokal langsung, biarkan event SSE yang
mengonfirmasi. Jika request gagal, rollback + tampilkan snackbar.

---

## 4. Wiring

```dart
ChangeNotifierProvider(
  create: (_) => KdsController(
    baseUrl: Env.apiBaseUrl,
    tenantId: session.tenantId,
    outletId: session.outletId,
    tokenProvider: () async => session.accessToken,
  )..start(),
  child: const KdsScreen(),
)
```

---

## Acceptance criteria

- [ ] Pembayaran di device kasir → kartu muncul di dapur < 1 detik.
- [ ] Matikan wifi tablet 30 detik lalu nyalakan → badge merah lalu hijau, dan
      semua pesanan yang masuk selama offline tetap muncul (via snapshot).
- [ ] Kill app lalu buka lagi → daftar pesanan utuh.
- [ ] Tekan "Siap" di satu tablet → tablet dapur lain ikut berubah tanpa refresh.
- [ ] Layar tidak pernah mati sendiri selama halaman KDS terbuka.
- [ ] Tidak ada `setState` setelah `dispose` (cek log saat pindah halaman).
