import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:pos_mobile/data/models/kitchen_order_model.dart';
import 'package:pos_mobile/presentation/providers/kitchen_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Layar monitoring pesanan (Kitchen Display System).
///
/// Pesanan yang sudah lunas muncul otomatis lewat SSE; snapshot REST ditarik
/// ulang tiap koneksi pulih agar tidak ada pesanan yang hilang saat wifi putus.
class KitchenDisplayPage extends ConsumerStatefulWidget {
  const KitchenDisplayPage({super.key});

  @override
  ConsumerState<KitchenDisplayPage> createState() => _KitchenDisplayPageState();
}

class _KitchenDisplayPageState extends ConsumerState<KitchenDisplayPage>
    with WidgetsBindingObserver {
  /// Hanya untuk menyegarkan label durasi tunggu — TIDAK untuk menarik data.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Provider dibaca setelah frame pertama supaya tidak memodifikasi state
    // saat build sedang berjalan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(kitchenDisplayProvider.notifier).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Koneksi socket mati saat app di background — sambungkan ulang dari nol.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(kitchenDisplayProvider.notifier).start();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kitchenDisplayProvider);
    final notifier = ref.read(kitchenDisplayProvider.notifier);

    ref.listen<KitchenDisplayState>(kitchenDisplayProvider, (prev, next) {
      final err = next.error;
      if (err != null && err != prev?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppTheme.danger),
          );
        notifier.clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text(
          'Monitoring Pesanan',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          _ConnectionBadge(connected: state.connected),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: notifier.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.orders.isEmpty
                ? _EmptyState(onRefresh: notifier.refresh)
                : RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Kartu enak dibaca di ~300px; tablet landscape dapat
                        // 3–4 kolom, ponsel 1 kolom.
                        final columns =
                            (constraints.maxWidth / 300).floor().clamp(1, 4);
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 280,
                          ),
                          itemCount: state.orders.length,
                          itemBuilder: (context, i) {
                            final order = state.orders[i];
                            return _OrderCard(
                              order: order,
                              onAdvance: () => notifier.advance(order),
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);

/// Warna kartu: makin dekat/lewat janji siap, makin mendesak.
///
/// Kalau pesanan punya `estimated_ready_at`, janji itulah acuannya. Tanpa
/// estimasi (produk belum diisi waktu pembuatan) dipakai ambang lama menunggu
/// seperti sebelumnya — bukan berarti pesanannya tepat waktu.
Color _urgencyColor(KitchenOrder order) {
  if (order.hasEstimate) {
    final remaining = -order.lateness;
    if (remaining.isNegative) return AppTheme.danger; // sudah lewat janji
    if (remaining.inMinutes < 3) return _amber;
    return _green;
  }
  final minutes = order.waiting.inMinutes;
  if (minutes < 3) return _green;
  if (minutes < 6) return _amber;
  return AppTheme.danger;
}

String _formatWaiting(Duration d) {
  if (d.isNegative) return '00:00';
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _OrderCard extends StatelessWidget {
  final KitchenOrder order;
  final VoidCallback onAdvance;

  const _OrderCard({required this.order, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final urgency = _urgencyColor(order);
    final actionLabel = kitchenActionLabel(order.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgency, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: nomor invoice + timer tunggu.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: urgency.withOpacity(0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (order.customerName.isNotEmpty)
                        Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      // Janji siap yang tercetak di nota pelanggan. Tanpa
                      // estimasi baris ini tidak muncul sama sekali.
                      if (order.hasEstimate) _EstimateLine(order: order),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.paidAt == null ? '--:--' : _formatWaiting(order.waiting),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: urgency,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    _StatusChip(status: order.status, color: urgency),
                  ],
                ),
              ],
            ),
          ),

          // Daftar item.
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: order.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ItemRow(item: order.items[i]),
            ),
          ),

          // Footer: aksi + metode bayar.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                if (order.paymentMethod.isNotEmpty) ...[
                  Icon(
                    Icons.payments_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.paymentMethod.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                if (actionLabel != null)
                  FilledButton(
                    onPressed: onAdvance,
                    style: FilledButton.styleFrom(
                      backgroundColor: urgency,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris "Target 17:27" di kartu; berubah jadi penanda telat begitu jam janji
/// terlewat. Hanya dirender bila pesanan punya `estimated_ready_at`.
class _EstimateLine extends StatelessWidget {
  final KitchenOrder order;
  const _EstimateLine({required this.order});

  @override
  Widget build(BuildContext context) {
    final late = order.isLate;
    final color = late ? AppTheme.danger : AppTheme.textSecondary;
    final clock = _formatClock(order.estimatedReadyAt!);
    final label = late
        ? 'Telat ${_formatWaiting(order.lateness)} • janji $clock'
        : 'Target $clock';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            late ? Icons.warning_amber_rounded : Icons.schedule,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: late ? FontWeight.w900 : FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final KitchenOrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.qty}×',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (item.toppings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.toppings
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        kitchenStatusLabel(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;
  const _ConnectionBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF16A34A) : AppTheme.danger;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Live' : 'Menyambung…',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.ramen_dining_outlined,
            size: 56,
            color: AppTheme.textSecondary,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Belum ada pesanan',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              'Pesanan yang sudah dibayar akan muncul di sini otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
