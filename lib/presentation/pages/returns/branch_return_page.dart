import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/branch_return_model.dart';
import 'package:pos_mobile/presentation/providers/branch_return_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _qtyFmt = NumberFormat('#,##0.####', 'id_ID');
final _when = DateFormat('EEE d MMM, HH.mm', 'id_ID');

String fmtReturnQty(double v) => _qtyFmt.format(v);

/// Angka desimal dari isian (koma atau titik), null bila kosong/tidak valid.
double? parseReturnQty(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Retur Stok (revisi owner 26 Nov 2026): barang dikirim balik ke gudang tanpa
/// menghitung stok fisik, seperti Catat Waste. Isi jumlah yang diretur saja;
/// stok outlet langsung berkurang dan gudang memilahnya di "Retur Harian".
/// Teh dan gula diretur lewat opname harian/mingguan, jadi tidak ada di sini.
class BranchReturnPage extends ConsumerStatefulWidget {
  const BranchReturnPage({super.key});

  @override
  ConsumerState<BranchReturnPage> createState() => _BranchReturnPageState();
}

class _BranchReturnPageState extends ConsumerState<BranchReturnPage> {
  final Map<String, TextEditingController> _qty = {};
  final _note = TextEditingController();
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  TextEditingController _ctl(String key) => _qty.putIfAbsent(key, TextEditingController.new);

  /// Pesan galat isian, atau null bila siap dikirim.
  String? _problem(List<BranchReturnItem> items) {
    var any = false;
    for (final it in items) {
      final raw = _qty[it.key]?.text ?? '';
      if (raw.trim().isEmpty) continue;
      final v = parseReturnQty(raw);
      if (v == null || v <= 0) return '${it.name}: jumlah tidak valid';
      if (v > it.systemQty) return '${it.name}: stok sistem tinggal ${fmtReturnQty(it.systemQty)} ${it.unit}';
      any = true;
    }
    return any ? null : 'Isi jumlah minimal satu barang';
  }

  int _filled(List<BranchReturnItem> items) =>
      items.where((it) => (parseReturnQty(_qty[it.key]?.text ?? '') ?? 0) > 0).length;

  Future<void> _submit(List<BranchReturnItem> items) async {
    final problem = _problem(items);
    if (problem != null) {
      _snack(problem, error: true);
      return;
    }
    final picked = items.where((it) => (parseReturnQty(_qty[it.key]?.text ?? '') ?? 0) > 0).toList();
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim retur ke gudang?'),
        content: Text([
          for (final it in picked) '• ${it.name}: ${_qty[it.key]!.text.trim()} ${it.unit}',
          '',
          'Stok outlet langsung berkurang. Bawa barangnya ke gudang.',
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final qty = {for (final it in picked) it.key: _qty[it.key]!.text.trim().replaceAll(',', '.')};
      await ref.read(branchReturnRepositoryProvider).create(items: picked, qty: qty, note: _note.text);
      if (!mounted) return;
      for (final c in _qty.values) {
        c.clear();
      }
      _note.clear();
      ref.invalidate(branchReturnItemsProvider);
      ref.invalidate(branchReturnHistoryProvider);
      _snack('Retur tercatat. Gudang memilahnya saat barang tiba.');
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(branchReturnItemsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text('Retur Stok'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Riwayat retur',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchReturnHistoryPage())),
            ),
          ],
        ),
        body: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(icon: Icons.cloud_off, message: '$e', onRetry: () => ref.invalidate(branchReturnItemsProvider)),
          data: (all) {
            final q = _search.text.trim().toLowerCase();
            final items = all.where((it) => it.systemQty > 0 && (q.isEmpty || it.name.toLowerCase().contains(q))).toList();
            final filled = _filled(all);
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
              children: [
                const SdmNote(
                  icon: Icons.assignment_return_outlined,
                  text: 'Isi jumlah barang yang dikembalikan ke gudang, tanpa menghitung sisa stok. Teh dan gula '
                      'diretur lewat opname harian/mingguan.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari barang'),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Tidak ada barang dengan stok yang bisa diretur.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                  )
                else
                  SdmCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        for (final it in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                      Text('Stok ${fmtReturnQty(it.systemQty)} ${it.unit}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    key: ValueKey('retur-${it.key}'),
                                    controller: _ctl(it.key),
                                    enabled: !_busy,
                                    onChanged: (_) => setState(() {}),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                    textAlign: TextAlign.end,
                                    decoration: InputDecoration(
                                      hintText: 'Jumlah',
                                      suffixText: it.unit,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  enabled: !_busy,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'mis. kemasan rusak'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy || filled == 0 ? null : () => _submit(all),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.local_shipping_outlined),
                  label: Text(filled == 0 ? 'Kirim retur' : 'Kirim retur ($filled barang)'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Riwayat retur harian cabang ini: dalam perjalanan atau sudah dipilah gudang.
class BranchReturnHistoryPage extends ConsumerWidget {
  const BranchReturnHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchReturnHistoryProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Riwayat Retur'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(branchReturnHistoryProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(icon: Icons.cloud_off, message: '$e', onRetry: () => ref.invalidate(branchReturnHistoryProvider)),
          data: (docs) => docs.isEmpty
              ? const SdmStateView(icon: Icons.assignment_return_outlined, message: 'Belum ada retur harian.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final d in docs) ...[
                      SdmCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(d.createdAt == null ? 'Retur #${d.id}' : _when.format(d.createdAt!),
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: d.received ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(d.received ? 'Sudah dipilah gudang' : 'Dalam perjalanan',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: d.received ? Colors.green.shade800 : Colors.orange.shade800)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (final l in d.lines)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${l.name}: ${fmtReturnQty(l.returnedQty)} ${l.unit}'
                                  '${d.received ? ' · masuk gudang ${fmtReturnQty(l.receivedQty)}' : ''}'
                                  '${d.received && l.missingQty > 0 ? ' · tidak sampai ${fmtReturnQty(l.missingQty)}' : ''}',
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                ),
                              ),
                            if (d.notes.trim().isNotEmpty)
                              Text(d.notes, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
