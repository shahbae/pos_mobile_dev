import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/branch_waste_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart' show KpiApiError;
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/branch_waste_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _qtyFmt = NumberFormat('#,##0.####', 'id_ID');

/// "1,5" atau "1.5" → 1.5; kosong atau tak terbaca → null.
double? parseWasteQty(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Catat Waste outlet (revisi 15 Nov, poin 1): pilih barang, jumlah, penyebab,
/// foto wajib. Mencatat langsung memotong stok cabang dan tidak boleh minus.
class WasteFormPage extends ConsumerStatefulWidget {
  const WasteFormPage({super.key});

  @override
  ConsumerState<WasteFormPage> createState() => _WasteFormPageState();
}

class _WasteFormPageState extends ConsumerState<WasteFormPage> {
  BranchWasteItem? _item;
  final _qty = TextEditingController();
  final _cause = TextEditingController();
  final _note = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _cause.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _qtyValue => parseWasteQty(_qty.text);

  /// Kelebihan dibanding stok, dicek di layar supaya kasir tidak menunggu
  /// server; 422 server tetap penentu.
  bool get _overStock => _item != null && _qtyValue != null && _qtyValue! > _item!.qtyOnHand + 1e-9;

  bool get _ready =>
      _item != null &&
      (_qtyValue ?? 0) > 0 &&
      !_overStock &&
      _cause.text.trim().isNotEmpty &&
      _photo != null;

  Future<void> _pickItem(List<BranchWasteItem> items) async {
    final picked = await showModalBottomSheet<BranchWasteItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemPicker(items: items),
    );
    if (picked != null && mounted) {
      setState(() {
        _item = picked;
        _error = null;
      });
    }
  }

  Future<void> _takePhoto() async {
    final b = await pickKpiPhoto(context);
    if (b != null && mounted) setState(() => _photo = b);
  }

  Future<void> _submit() async {
    final item = _item!;
    final qty = _qtyValue!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Catat waste?'),
        content: Text(
          '${item.name}: ${_qtyFmt.format(qty)} ${item.unit} (${_cause.text.trim()}).\n\n'
          'Stok outlet langsung berkurang dan catatan ini tidak bisa diubah atau dihapus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa lagi')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Catat'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(branchWasteRepositoryProvider).create(
            itemType: item.itemType,
            itemId: item.id,
            qty: qty.toString(),
            cause: _cause.text.trim(),
            note: _note.text.trim(),
            photo: _photo!,
          );
      if (!mounted) return;
      ref.invalidate(branchWasteItemsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Waste ${r.itemName} tercatat. Stok outlet berkurang.'),
        backgroundColor: AppTheme.brandBlue,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Pesan server (stok kurang, belum ada jadwal, dst.) ditampilkan apa adanya.
      final msg = e is KpiApiError ? e.message : '$e';
      setState(() {
        _busy = false;
        _error = msg;
      });
      // Catatan galat ada di atas tombol dan bisa terdorong keluar layar saat
      // muncul; snackbar memastikan pesannya terbaca.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        duration: const Duration(seconds: 6),
      ));
      // Stok bisa berubah sejak daftar dimuat (penjualan jalan terus).
      ref.invalidate(branchWasteItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(branchWasteItemsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Catat Waste'), centerTitle: true),
        body: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: e.toString(),
            onRetry: () => ref.invalidate(branchWasteItemsProvider),
          ),
          data: (items) {
            // Barang yang dipilih bisa berubah stoknya sesudah muat ulang.
            final fresh = _item == null ? null : items.where((i) => i.itemType == _item!.itemType && i.id == _item!.id).firstOrNull;
            final item = fresh ?? _item;
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
              children: [
                const SdmNote(
                  icon: Icons.info_outline,
                  text: 'Waste = barang yang dibuang (tumpah, basi, rusak, dst.). Stok outlet langsung berkurang. '
                      'Salah catat tidak bisa dihapus; koreksinya lewat opname.',
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 1,
                  title: 'Barang',
                  child: items.isEmpty
                      ? const Text('Tidak ada barang dengan stok di outlet ini.', style: TextStyle(color: AppTheme.textSecondary))
                      : InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _busy ? null : () => _pickItem(items),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Pilih barang', suffixIcon: Icon(Icons.arrow_drop_down)),
                            child: Text(
                              item == null ? 'Ketuk untuk memilih' : '${item.name} · ${item.typeLabel}',
                              style: TextStyle(color: item == null ? AppTheme.textSecondary : AppTheme.textPrimary),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 2,
                  title: 'Jumlah',
                  child: TextField(
                    controller: _qty,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _error = null),
                    decoration: InputDecoration(
                      labelText: item == null ? 'Jumlah' : 'Jumlah (${item.unit})',
                      helperText: item == null ? null : 'Stok outlet: ${_qtyFmt.format(item.qtyOnHand)} ${item.unit}',
                      errorText: _overStock ? 'Melebihi stok outlet' : null,
                      suffixText: item?.unit,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 3,
                  title: 'Penyebab',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final c in branchWasteCauses)
                            ChoiceChip(
                              label: Text(c),
                              selected: _cause.text.trim() == c,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() {
                                        _cause.text = c;
                                        _error = null;
                                      }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cause,
                        enabled: !_busy,
                        maxLength: branchWasteCauseMax,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() => _error = null),
                        decoration: const InputDecoration(labelText: 'Penyebab (pilih di atas atau ketik)'),
                      ),
                      TextField(
                        controller: _note,
                        enabled: !_busy,
                        maxLines: 2,
                        maxLength: branchWasteNoteMax,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 4,
                  title: 'Foto (wajib)',
                  child: _photo != null
                      ? KpiPhotoPreview(_photo!, height: 160, onRemove: _busy ? null : () => setState(() => _photo = null))
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _takePhoto,
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: const Text('Ambil foto'),
                          ),
                        ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SdmNote(icon: Icons.error_outline, warning: true, text: _error!),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy || !_ready ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Catat waste'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final Widget child;
  const _Step({required this.number, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $title', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Daftar barang yang bisa dicari; empat jenis dalam satu daftar.
class _ItemPicker extends StatefulWidget {
  final List<BranchWasteItem> items;
  const _ItemPicker({required this.items});

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final rows = [for (final i in widget.items) if (q.isEmpty || i.name.toLowerCase().contains(q)) i];
    final height = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari barang'),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Tidak ada yang cocok.', style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, n) {
                        final i = rows[n];
                        return ListTile(
                          title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${i.typeLabel} · stok ${_qtyFmt.format(i.qtyOnHand)} ${i.unit}'),
                          onTap: () => Navigator.pop(context, i),
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
