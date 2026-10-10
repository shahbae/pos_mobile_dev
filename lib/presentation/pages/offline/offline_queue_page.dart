import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/presentation/pages/transactions/receipt_page.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Penjualan offline cabang aktif, terbaru dulu. Dimuat ulang tiap keadaan
/// antrean berubah (ada yang baru tersimpan, terkirim, atau ditolak).
final offlineEntriesProvider = FutureProvider.autoDispose<List<OutboxEntry>>((ref) async {
  ref.watch(offlineProvider);
  return ref.watch(offlineProvider.notifier).entries();
});

/// Halaman "Belum terkirim": semua penjualan yang dibuat saat offline, dengan
/// statusnya, tombol kirim, dan cetak ulang nota dari salinan di HP.
class OfflineQueuePage extends ConsumerWidget {
  const OfflineQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineProvider);
    final entries = ref.watch(offlineEntriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Penjualan Offline'), centerTitle: true),
      body: Column(
        children: [
          _Summary(state: state),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Gagal membaca penyimpanan di HP:\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Belum ada penjualan offline di HP ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _EntryCard(entry: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  final OfflineState state;
  const _Summary({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String line;
    if (state.pending == 0 && state.failed == 0) {
      line = 'Semua penjualan offline sudah terkirim.';
    } else if (state.pending > 0) {
      line = state.reachable
          ? '${state.pending} penjualan sedang dikirim.'
          : '${state.pending} penjualan menunggu jaringan. Akan terkirim sendiri begitu tersambung.';
    } else {
      line = '${state.failed} penjualan ditolak server dan perlu ditangani.';
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          if (state.pending > 0) ...[
            const SizedBox(height: 4),
            const Text(
              'Selama belum terkirim, penjualan ini hanya ada di HP ini. Jangan hapus aplikasi atau datanya.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.sending ? null : () => ref.read(offlineProvider.notifier).probe(),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(state.sending ? 'Mengirim…' : 'Kirim sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  final OutboxEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String label, Color color) = switch (entry.status) {
      OutboxStatus.sent => ('Terkirim', const Color(0xFF15803D)),
      OutboxStatus.failed => ('Ditolak', const Color(0xFFB91C1C)),
      _ => ('Menunggu', const Color(0xFFB45309)),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.clientRef,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('d MMM yyyy HH:mm', 'id_ID').format(entry.occurredAt)} · ${formatRupiah(entry.total)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (entry.isSent && (entry.invoiceNo ?? '').isNotEmpty)
            Text('Invoice ${entry.invoiceNo}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (!entry.isSent && (entry.lastError ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entry.lastError!, style: TextStyle(color: color, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _openReceipt(context),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Nota'),
              ),
              if (entry.isFailed) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.read(offlineProvider.notifier).retry(entry.id),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Kirim ulang'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Nota dibuka dari salinan di HP, jadi bisa dicetak ulang tanpa jaringan.
  void _openReceipt(BuildContext context) {
    final receipt = Receipt.fromJson(Map<String, dynamic>.from(jsonDecode(entry.receipt) as Map));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptPage(invoiceNo: entry.clientRef, receipt: receipt)),
    );
  }
}
