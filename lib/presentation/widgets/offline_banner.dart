import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/presentation/pages/offline/offline_queue_page.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';

/// Katalog yang lebih tua dari ini dianggap terlalu lama untuk dipercaya
/// harganya, dan spanduknya berubah jadi peringatan.
const staleCatalogAfter = Duration(hours: 24);

/// Spanduk mode offline. Tampil selama server tak terjangkau, selama masih ada
/// penjualan yang belum terkirim, atau ada yang ditolak server — dan hilang
/// sendiri begitu semuanya beres. Diketuk membuka halaman "Belum terkirim".
class OfflineBanner extends ConsumerWidget {
  /// Kapan menu di layar terakhir diunduh. Bila diisi, ikut ditampilkan selama
  /// offline: harga yang dipakai menjual adalah harga pada jam itu.
  final DateTime? catalogFetchedAt;

  const OfflineBanner({super.key, this.catalogFetchedAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(offlineProvider);
    if (!s.active && s.failed == 0) return const SizedBox.shrink();

    final String text;
    final Color color;
    final IconData icon;
    if (!s.reachable) {
      icon = Icons.cloud_off_outlined;
      color = const Color(0xFFB45309);
      text = s.pending > 0
          ? 'Mode offline · ${s.pending} penjualan belum terkirim'
          : 'Mode offline · hanya tunai';
    } else if (s.pending > 0) {
      icon = Icons.cloud_upload_outlined;
      color = const Color(0xFF1D4ED8);
      text = 'Mengirim ${s.pending} penjualan…';
    } else {
      icon = Icons.error_outline;
      color = const Color(0xFFB91C1C);
      text = '${s.failed} penjualan offline perlu ditangani';
    }

    final fetched = catalogFetchedAt;
    final stale = fetched != null && DateTime.now().difference(fetched) > staleCatalogAfter;
    final detail = (!s.reachable && fetched != null)
        ? (stale
            ? 'Menu terakhir diperbarui ${DateFormat('d MMM HH:mm', 'id_ID').format(fetched)} — sudah lebih dari sehari, harga bisa berbeda'
            : 'Menu per ${DateFormat('HH:mm', 'id_ID').format(fetched)}')
        : null;

    return Material(
      color: color,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfflineQueuePage()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (detail != null)
                      Text(detail, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
