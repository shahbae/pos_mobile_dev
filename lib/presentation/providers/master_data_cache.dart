import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Berapa lama data master (plastik, sedotan, dll) boleh dipakai dari cache
/// sebelum diambil ulang. Cukup pendek supaya master baru yang ditambah admin
/// muncul di kasir tanpa restart app, cukup panjang supaya tidak menembak
/// request tiap kali halaman checkout dibuka.
const masterDataTtl = Duration(minutes: 10);

/// Tahan hasil provider `autoDispose` selama [ttl], lalu lepaskan supaya
/// pemakaian berikutnya memuat data baru.
///
/// Dipakai untuk data master yang jarang berubah tapi tidak boleh basi
/// seumur hidup app: tanpa ini provider biasa (non-autoDispose) memegang
/// hasil pertama sampai app di-kill.
void cacheFor(Ref ref, [Duration ttl = masterDataTtl]) {
  final link = ref.keepAlive();
  final timer = Timer(ttl, link.close);
  ref.onDispose(timer.cancel);
}
