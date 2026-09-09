import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'shipment_list_page.dart' show ShipmentStatusChip, fmtShipmentDate;

class ShipmentDetailPage extends ConsumerStatefulWidget {
  final int shipmentId;
  const ShipmentDetailPage({super.key, required this.shipmentId});

  @override
  ConsumerState<ShipmentDetailPage> createState() =>
      _ShipmentDetailPageState();
}

class _ShipmentDetailPageState extends ConsumerState<ShipmentDetailPage> {
  bool _busy = false;
  bool _changed = false;

  Future<void> _receive(Shipment sh) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terima seluruh kiriman?'),
        content: const Text(
            'Stok cabang akan langsung bertambah sesuai isi surat jalan, dan '
            'ini tidak bisa dibatalkan.\n\n'
            'Pastikan barangnya sudah benar-benar diturunkan dan jumlahnya '
            'cocok. Kalau ada yang kurang atau rusak, tolak seluruhnya — '
            'tidak ada terima sebagian.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Periksa lagi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terima', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(shipmentRepositoryProvider).receive(sh.id));
  }

  Future<void> _reject(Shipment sh) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak seluruh kiriman?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Seluruh barang dikembalikan ke gudang — tidak ada tolak '
                'sebagian. Permintaan stoknya ikut tertutup: gudang TIDAK bisa '
                'mengirim ulang, jadi kalau barangnya masih dibutuhkan, kamu '
                'harus mengajukan permintaan baru.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                hintText: 'mis. segel rusak, teh tumpah',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    if (reason.isEmpty) {
      _snack('Alasan wajib diisi supaya gudang tahu apa yang harus dibenahi.');
      return;
    }
    await _run(() => ref.read(shipmentRepositoryProvider).reject(sh.id, reason));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      ref.invalidate(shipmentDetailProvider(widget.shipmentId));
      ref.invalidate(shipmentListProvider);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canDecide = canReceiveShipment(auth.role);
    final async = ref.watch(shipmentDetailProvider(widget.shipmentId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: Text('Kiriman #${widget.shipmentId}'),
          centerTitle: true,
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e', textAlign: TextAlign.center),
            ),
          ),
          data: (sh) => RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(shipmentDetailProvider(widget.shipmentId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _header(sh),
                if (sh.isRejected || sh.isCancelled)
                  _reasonNote(sh),
                const SizedBox(height: 16),
                const Text('Isi kiriman',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ...sh.lines.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LineCard(line: l),
                    )),
                if (canDecide && sh.isOnTheWay) ...[
                  const SizedBox(height: 16),
                  _actions(sh),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Shipment sh) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(
                  sh.branchName ?? 'Cabang #${sh.branchId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.textPrimary),
                ),
              ),
              ShipmentStatusChip(status: sh.status),
            ],
          ),
          const SizedBox(height: 8),
          _kv('Dari permintaan', '#${sh.stockRequestId}'),
          if (sh.shippedAt != null)
            _kv('Dikirim', fmtShipmentDate(sh.shippedAt!)),
          if (sh.shipperName != null) _kv('Oleh', sh.shipperName!),
          if (sh.receivedAt != null)
            _kv(sh.isReceived ? 'Diterima' : 'Diputuskan',
                fmtShipmentDate(sh.receivedAt!)),
          if (sh.isOnTheWay) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Barang ini sudah keluar gudang tapi belum masuk stok cabang. '
                'Stok baru bertambah setelah kamu menekan terima.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _reasonNote(Shipment sh) {
    final reason = sh.rejectedReason ?? '';
    if (reason.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sh.isRejected ? 'Alasan ditolak' : 'Alasan gudang menarik',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.red.shade900)),
          const SizedBox(height: 4),
          Text(reason,
              style: TextStyle(fontSize: 13, color: Colors.red.shade900)),
        ],
      ),
    );
  }

  Widget _actions(Shipment sh) {
    return ShipmentActionBar(
      busy: _busy,
      onReceive: () => _receive(sh),
      onReject: () => _reject(sh),
    );
  }
}

/// Bar tombol terima / tolak.
///
/// Dipisah jadi widget sendiri supaya bisa dirender di test tanpa perlu
/// berpura-pura login — di sinilah jebakan layout berada, dan menguji halaman
/// utuh tanpa auth justru melewatkan bagian yang paling rawan.
///
/// Tombol disusun BERTUMPUK dan memenuhi lebar, bukan berdampingan dalam Row.
/// Bukan sekadar selera: AppTheme menyetel minimumSize tombol ke
/// `Size.fromHeight(44)` — lebar minimum TAK HINGGA — jadi menaruhnya sebagai
/// anak non-flex di dalam Row akan menggagalkan layout satu halaman penuh.
class ShipmentActionBar extends StatelessWidget {
  final bool busy;
  final VoidCallback onReceive;
  final VoidCallback onReject;

  const ShipmentActionBar({
    super.key,
    required this.busy,
    required this.onReceive,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: busy ? null : onReceive,
          icon: const Icon(Icons.check),
          label: const Text('Terima Kiriman'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.borderLight,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : onReject,
          icon: const Icon(Icons.close),
          label: const Text('Tolak Seluruhnya'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.red),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Terima seluruhnya atau tolak seluruhnya — tidak ada terima sebagian.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  final ShipmentLine line;
  const _LineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(line.typeLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_fmtQty(line.qty)} ${line.unit}',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

String _fmtQty(double v) {
  final f = NumberFormat.decimalPattern('id_ID');
  if (v == v.roundToDouble()) return f.format(v.toInt());
  return f.format(v);
}
