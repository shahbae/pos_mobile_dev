import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/kitchen_order_model.dart';
import 'package:pos_mobile/presentation/pages/kitchen/kitchen_display_page.dart';
import 'package:pos_mobile/presentation/providers/kitchen_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Pita monitoring pesanan kasir di kepala layar Pilih Produk (revisi owner
/// 21 Nov 2026: "kecil aja buat liat no antrean dan menitan aja, jika ada yang
/// ditinggal ada pencetan skip, dan bisa dibuka kalau mau lebar atau lihat
/// pesanan yang ditinggal").
///
/// Tiap pesanan aktif = satu kotak kecil "nomor · menit sejak dibayar"; yang
/// siap diserahkan berwarna hijau penuh. Ketuk kotak → Diserahkan atau
/// Ditinggal. Datanya dari [kitchenDisplayProvider] (SSE yang sama dengan
/// layar Monitoring), jadi membuka layar lebar tidak membuat koneksi kedua.
class KitchenQueueStrip extends ConsumerStatefulWidget {
  const KitchenQueueStrip({super.key});

  @override
  ConsumerState<KitchenQueueStrip> createState() => _KitchenQueueStripState();
}

class _KitchenQueueStripState extends ConsumerState<KitchenQueueStrip> with WidgetsBindingObserver {
  /// Hanya menyegarkan angka menit; data datang lewat SSE.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(kitchenDisplayProvider.notifier).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(kitchenDisplayProvider.notifier).start();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kitchenDisplayProvider);
    final orders = kitchenOrdersForView(state.orders, KitchenView.cashier);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: orders.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.loading ? 'Memuat antrean…' : 'Antrean kosong',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('kitchen-queue-strip'),
                    scrollDirection: Axis.horizontal,
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) => _QueueChip(
                      order: orders[i],
                      onTap: () => showQueueOrderSheet(context, ref, orders[i]),
                    ),
                  ),
          ),
          if (state.skipped.isNotEmpty)
            TextButton(
              onPressed: () => showSkippedOrdersSheet(context, ref),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                foregroundColor: AppTheme.danger,
              ),
              child: Text('Ditinggal ${state.skipped.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          IconButton(
            tooltip: 'Buka monitoring lebar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.open_in_full, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KitchenDisplayPage())),
          ),
        ],
      ),
    );
  }
}

/// Satu kotak di pita: nomor antrean + menit. Siap = hijau penuh.
class _QueueChip extends StatelessWidget {
  final KitchenOrder order;
  final VoidCallback onTap;
  const _QueueChip({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ready = order.status == kitchenStatusReady;
    final minutes = order.paidAt == null ? null : order.waiting.inMinutes;
    final late = order.isLate || (!order.hasEstimate && (minutes ?? 0) >= 6);
    final color = ready ? const Color(0xFF16A34A) : (late ? AppTheme.danger : const Color(0xFFD97706));
    return Material(
      color: ready ? color : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            minutes == null ? order.shortNumber : '${order.shortNumber} · ${minutes}m',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ready ? Colors.white : color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rincian satu pesanan dari pita: isi pesanan, lalu Diserahkan (bila siap)
/// atau Ditinggal (pelanggan pergi).
Future<void> showQueueOrderSheet(BuildContext context, WidgetRef ref, KitchenOrder order) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final notifier = ref.read(kitchenDisplayProvider.notifier);
      final minutes = order.paidAt == null ? null : order.waiting.inMinutes;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(order.displayNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(
                [
                  kitchenStatusLabel(order.status),
                  if (minutes != null) '$minutes menit sejak dibayar',
                  if (order.customerName.isNotEmpty) order.customerName,
                ].join(' · '),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final it in order.items)
                Text('${it.qty}× ${it.displayName}${it.toppings.isEmpty ? '' : ' + ${it.toppings.join(', ')}'}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.setStatus(order, kitchenStatusSkipped);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, minimumSize: const Size(0, 44)),
                      child: const Text('Ditinggal'),
                    ),
                  ),
                  if (order.status == kitchenStatusReady) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          notifier.setStatus(order, kitchenStatusServed);
                        },
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), minimumSize: const Size(0, 44)),
                        child: const Text('Diserahkan'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Ditinggal = pelanggan pergi sebelum mengambil. Pesanan pindah ke daftar Ditinggal dan masih bisa diserahkan bila pelanggannya kembali.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Daftar pesanan Ditinggal; tiap pesanan bisa Diserahkan bila pelanggannya
/// kembali. Tutup shift menyapu sisanya.
Future<void> showSkippedOrdersSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _SkippedOrdersSheet(),
  );
}

class _SkippedOrdersSheet extends ConsumerWidget {
  const _SkippedOrdersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped = ref.watch(kitchenDisplayProvider).skipped;
    final notifier = ref.read(kitchenDisplayProvider.notifier);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Pesanan Ditinggal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            if (skipped.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text('Tidak ada pesanan yang ditinggal.', style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: skipped.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final o = skipped[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.displayNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                [
                                  if (o.customerName.isNotEmpty) o.customerName,
                                  o.items.map((it) => '${it.qty}× ${it.displayName}').join(', '),
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => notifier.setStatus(o, kitchenStatusServed),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                          child: const Text('Diserahkan'),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
