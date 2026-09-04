import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'shipment_detail_page.dart';

class ShipmentListPage extends ConsumerWidget {
  const ShipmentListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Kiriman selalu ditujukan ke satu cabang. Tangkap lebih awal supaya tidak
    // berujung daftar kosong yang membingungkan.
    final needsBranch =
        auth.role?.toLowerCase() != 'owner' && auth.branchId == null;
    if (needsBranch) {
      return Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Kiriman Gudang'), centerTitle: true),
        body: const _BranchRequiredView(),
      );
    }

    final shipmentsAsync = ref.watch(shipmentListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Kiriman Gudang'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shipmentListProvider),
        child: shipmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Gagal memuat kiriman:\n$e',
                    textAlign: TextAlign.center),
              ),
            ],
          ),
          data: (shipments) {
            if (shipments.isEmpty) return const _EmptyView();
            final waiting = shipments.where((s) => s.isOnTheWay).length;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: shipments.length + (waiting > 0 ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (waiting > 0 && i == 0) return _WaitingBanner(count: waiting);
                final s = shipments[waiting > 0 ? i - 1 : i];
                return _ShipmentCard(
                  shipment: s,
                  onChanged: () => ref.invalidate(shipmentListProvider),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Barang yang sudah sampai tapi belum ditekan terima berarti stoknya belum
/// bertambah — kasir bisa menolak pesanan padahal bahannya ada di gudang toko.
/// Karena itu jumlahnya ditonjolkan, bukan sekadar tersirat dari daftar.
class _WaitingBanner extends StatelessWidget {
  final int count;
  const _WaitingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined,
              color: Colors.blue.shade800, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count kiriman menunggu diterima. Stok belum bertambah sampai '
              'kamu menekan terima.',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 140),
        Icon(Icons.local_shipping_outlined,
            size: 56, color: AppTheme.textSecondary),
        SizedBox(height: 12),
        Center(
          child: Text('Belum ada kiriman dari gudang',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Kiriman muncul di sini setelah gudang memproses permintaan stok.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _BranchRequiredView extends StatelessWidget {
  const _BranchRequiredView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined,
              size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text('Pilih cabang dulu',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Kiriman gudang selalu ditujukan ke satu cabang. Pilih cabang aktif '
            'dulu sebelum membuka menu ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => showBranchSwitchSheet(context),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Pilih Cabang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final Shipment shipment;
  final VoidCallback onChanged;
  const _ShipmentCard({required this.shipment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final waiting = shipment.isOnTheWay;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ShipmentDetailPage(shipmentId: shipment.id)),
        );
        if (changed == true) onChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: waiting ? Colors.blue.shade300 : AppTheme.borderLight,
            width: waiting ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kiriman #${shipment.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  // Kurir tidak lagi diisi saat gudang menekan kirim, jadi
                  // barisnya hanya muncul untuk kiriman lama yang terlanjur
                  // mencatatnya. Menuliskan "tidak dicatat" di tiap baris cuma
                  // memberi tahu pembaca bahwa ada isian yang memang sudah
                  // ditiadakan.
                  if (shipment.courierName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Kurir ${shipment.courierName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                  if (shipment.shippedAt != null) ...[
                    // Rapat ke baris kurir, longgar ke judul: jaraknya
                    // mengikuti apa yang benar-benar ada di atasnya.
                    SizedBox(height: shipment.courierName.isEmpty ? 4 : 2),
                    Text(fmtShipmentDate(shipment.shippedAt!),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            ShipmentStatusChip(status: shipment.status),
          ],
        ),
      ),
    );
  }
}

class ShipmentStatusChip extends StatelessWidget {
  final String status;
  const ShipmentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (status.toLowerCase()) {
      case 'shipped':
        color = Colors.blue;
        label = 'Menunggu';
        break;
      case 'received':
        color = Colors.green;
        label = 'Diterima';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Ditolak';
        break;
      case 'cancelled':
        color = AppTheme.textSecondary;
        label = 'Ditarik';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

String fmtShipmentDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy • HH:mm')
        .format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}
