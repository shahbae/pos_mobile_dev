import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/stock_request_model.dart';
import 'package:pos_mobile/presentation/providers/stock_request_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Form mengajukan / mengubah permintaan stok.
///
/// Jumlah diisi dalam KEMASAN ("2 pack"), bukan satuan dasar — itu cara orang
/// outlet berpikir. Terjemahan ke ml/gram ditampilkan di bawah isian supaya
/// tetap terlihat, tapi tidak pernah diketik.
class StockRequestFormPage extends ConsumerStatefulWidget {
  /// Diisi saat mengubah permintaan yang sudah ada; null berarti membuat baru.
  final StockRequest? existing;
  const StockRequestFormPage({super.key, this.existing});

  @override
  ConsumerState<StockRequestFormPage> createState() =>
      _StockRequestFormPageState();
}

class _StockRequestFormPageState extends ConsumerState<StockRequestFormPage> {
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  /// Jumlah pack per barang, key = "material:33". Barang tanpa entri (atau
  /// bernilai nol) tidak ikut dikirim.
  final Map<String, TextEditingController> _qtyCtrls = {};

  /// Kemasan yang dipilih per barang. Hanya perlu dipilih kalau barangnya punya
  /// lebih dari satu; kalau cuma satu, dipakai diam-diam.
  final Map<String, int> _templateIds = {};

  String _search = '';
  bool _saving = false;
  bool _prefilled = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _noteCtrl.text = widget.existing?.note ?? '';
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Isi ulang form dari permintaan yang sedang diubah. Dijalankan sekali, saat
  /// katalog sudah datang — sebelum itu tidak ada barang untuk dicocokkan.
  void _prefill(List<RequestableItem> catalogue) {
    if (_prefilled || !_isEdit) return;
    _prefilled = true;
    for (final line in widget.existing!.lines) {
      final key = '${line.itemType}:${line.itemId}';
      // Barang yang sudah tidak ada di katalog (mis. penandaannya diubah admin)
      // sengaja dilewati: mengirimnya balik akan kena 422.
      if (!catalogue.any((c) => c.key == key)) continue;
      _qtyCtrls[key] = TextEditingController(text: _trimNum(line.packQty));
      _templateIds[key] = line.templateId;
    }
  }

  List<Map<String, dynamic>> _buildItems(List<RequestableItem> catalogue) {
    final items = <Map<String, dynamic>>[];
    for (final item in catalogue) {
      final raw = _qtyCtrls[item.key]?.text.trim().replaceAll(',', '.') ?? '';
      if (raw.isEmpty) continue;
      final qty = double.tryParse(raw);
      if (qty == null || qty <= 0) continue;
      items.add({
        'item_type': item.itemType,
        'item_id': item.itemId,
        'template_id': _templateIds[item.key] ?? item.templates.first.id,
        // Dikirim sebagai teks: BE memakai desimal presisi tinggi dan angka
        // JSON bisa kehilangan pecahannya di perjalanan.
        'pack_qty': raw,
      });
    }
    return items;
  }

  Future<void> _save(List<RequestableItem> catalogue) async {
    final items = _buildItems(catalogue);
    if (items.isEmpty) {
      _snack('Isi jumlah minimal satu barang dulu.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(stockRequestRepositoryProvider);
      if (_isEdit) {
        await repo.updateRequest(
          id: widget.existing!.id,
          note: _noteCtrl.text.trim(),
          items: items,
        );
      } else {
        await repo.createRequest(note: _noteCtrl.text.trim(), items: items);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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
    final catalogueAsync = ref.watch(requestableItemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Permintaan' : 'Minta Barang'),
        centerTitle: true,
      ),
      body: catalogueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat daftar barang:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (catalogue) {
          if (catalogue.isEmpty) return const _CatalogueEmptyView();
          _prefill(catalogue);

          final visible = _search.isEmpty
              ? catalogue
              : catalogue
                  .where((c) => c.name.toLowerCase().contains(_search))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari barang',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visible.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == visible.length) return _noteField();
                    final item = visible[i];
                    return _ItemCard(
                      item: item,
                      qtyCtrl: _qtyCtrls.putIfAbsent(
                          item.key, () => TextEditingController()),
                      templateId:
                          _templateIds[item.key] ?? item.templates.first.id,
                      onTemplateChanged: (id) =>
                          setState(() => _templateIds[item.key] = id),
                      onQtyChanged: () => setState(() {}),
                    );
                  },
                ),
              ),
              _saveBar(catalogue),
            ],
          );
        },
      ),
    );
  }

  Widget _noteField() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _noteCtrl,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Catatan (opsional)',
          hintText: 'mis. kebutuhan minggu depan',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.borderLight),
          ),
        ),
      ),
    );
  }

  Widget _saveBar(List<RequestableItem> catalogue) {
    final count = _buildItems(catalogue).length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? 'Belum ada barang yang diisi'
                    : '$count barang akan diminta',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: _saving || count == 0 ? null : () => _save(catalogue),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Simpan Perubahan' : 'Ajukan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Katalog kosong bukan error — di awal memang belum ada barang setengah jadi
/// yang ditandai atau yang punya kemasan. Jelaskan apa yang harus dilakukan,
/// dan siapa yang bisa melakukannya, karena bukan orang outlet.
class _CatalogueEmptyView extends StatelessWidget {
  const _CatalogueEmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox_outlined, size: 56, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Belum ada barang yang bisa diminta',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textPrimary)),
          SizedBox(height: 8),
          Text(
            'Gudang belum menyiapkan barang untuk dikirim ke outlet. Yang perlu '
            'diatur dari web admin: menandai bahan sebagai setengah jadi, dan '
            'menentukan kemasannya (mis. 1 pack = 5.000 ml).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final RequestableItem item;
  final TextEditingController qtyCtrl;
  final int templateId;
  final ValueChanged<int> onTemplateChanged;
  final VoidCallback onQtyChanged;

  const _ItemCard({
    required this.item,
    required this.qtyCtrl,
    required this.templateId,
    required this.onTemplateChanged,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final template = item.templates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => item.templates.first,
    );
    final packQty =
        double.tryParse(qtyCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final baseTotal = packQty * template.baseQty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: packQty > 0 ? AppTheme.brandBlue : AppTheme.borderLight,
          width: packQty > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${item.typeLabel} • stok gudang '
                      '${_trimNum(item.warehouseQty)} ${item.unit}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: qtyCtrl,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => onQtyChanged(),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.templates.length > 1)
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: templateId,
                    isDense: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.borderLight),
                      ),
                    ),
                    items: item.templates
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.name} (${_trimNum(t.baseQty)} ${item.unit})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onTemplateChanged(v);
                    },
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'Satuan: ${template.name} '
                    '(${_trimNum(template.baseQty)} ${item.unit})',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              if (packQty > 0) ...[
                const SizedBox(width: 8),
                // Terjemahan ke satuan dasar. Ditampilkan supaya orang tahu
                // "2 pack" itu sebenarnya berapa, tanpa harus mengetiknya.
                Text(
                  '= ${_trimNum(baseTotal)} ${item.unit}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandBlue),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Buang nol di belakang koma supaya "2" tidak tampil sebagai "2.0000".
String _trimNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
