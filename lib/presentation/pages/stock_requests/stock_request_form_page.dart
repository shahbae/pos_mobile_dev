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

/// Urutan kategori di daftar. Bahan setengah jadi di atas karena itu yang
/// paling sering diminta; kemasan menyusul karena biasanya diisi belakangan.
const _categoryOrder = ['material', 'topping', 'plastic', 'sedotan'];

const _categoryLabels = {
  'material': 'Bahan',
  'topping': 'Topping',
  'plastic': 'Plastik',
  'sedotan': 'Sedotan',
};

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

  /// Saring ke kategori tertentu, atau ke yang sudah diisi saja. Daftar barang
  /// bisa puluhan; tanpa penyaring, memeriksa ulang sebelum mengajukan berarti
  /// menggulir seluruh katalog.
  String _filter = 'all';

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

  double _packQtyOf(String key) {
    final raw = _qtyCtrls[key]?.text.trim().replaceAll(',', '.') ?? '';
    if (raw.isEmpty) return 0;
    return double.tryParse(raw) ?? 0;
  }

  bool _isFilled(RequestableItem item) => _packQtyOf(item.key) > 0;

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

          final filledCount = catalogue.where(_isFilled).length;
          final visible = catalogue.where((c) {
            if (_search.isNotEmpty && !c.name.toLowerCase().contains(_search)) {
              return false;
            }
            if (_filter == 'filled') return _isFilled(c);
            if (_filter != 'all' && c.itemType != _filter) return false;
            return true;
          }).toList();

          // Kategori yang benar-benar punya isi saja — jangan tampilkan judul
          // "Sedotan" lalu kosong di bawahnya.
          final grouped = <String, List<RequestableItem>>{};
          for (final item in visible) {
            grouped.putIfAbsent(item.itemType, () => []).add(item);
          }
          final sections = _categoryOrder
              .where((c) => grouped[c]?.isNotEmpty ?? false)
              .toList();
          // Tipe yang belum dikenal app ini tetap ditampilkan di paling bawah,
          // daripada hilang diam-diam.
          for (final key in grouped.keys) {
            if (!_categoryOrder.contains(key)) sections.add(key);
          }

          return Column(
            children: [
              _toolbar(catalogue, filledCount),
              Expanded(
                child: visible.isEmpty
                    ? _noMatchView()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          for (final section in sections) ...[
                            _sectionHeader(
                                _categoryLabels[section] ?? section,
                                grouped[section]!.length),
                            for (final item in grouped[section]!) ...[
                              _ItemCard(
                                item: item,
                                qtyCtrl: _qtyCtrls.putIfAbsent(
                                    item.key, () => TextEditingController()),
                                templateId: _templateIds[item.key] ??
                                    item.templates.first.id,
                                onTemplateChanged: (id) =>
                                    setState(() => _templateIds[item.key] = id),
                                onQtyChanged: () => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                          const SizedBox(height: 8),
                          _noteField(),
                        ],
                      ),
              ),
              _saveBar(catalogue, filledCount),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar(List<RequestableItem> catalogue, int filledCount) {
    // Kategori yang tidak ada barangnya tidak perlu jadi tombol saring.
    final present = _categoryOrder
        .where((c) => catalogue.any((i) => i.itemType == c))
        .toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari barang',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    ),
              isDense: true,
              filled: true,
              fillColor: AppTheme.bgLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('all', 'Semua'),
                // Pintasan memeriksa ulang sebelum mengajukan, tanpa menggulir
                // seluruh katalog.
                if (filledCount > 0)
                  _filterChip('filled', 'Diisi ($filledCount)',
                      accent: true),
                for (final c in present)
                  _filterChip(c, _categoryLabels[c] ?? c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, {bool accent = false}) {
    final selected = _filter == value;
    final color = accent ? Colors.green.shade700 : AppTheme.brandBlue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _filter = value),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? color : AppTheme.borderLight),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: AppTheme.borderLight)),
        ],
      ),
    );
  }

  Widget _noMatchView() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _filter == 'filled'
                ? 'Belum ada barang yang diisi'
                : 'Tidak ada barang yang cocok',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _noteField() {
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
          const Text('Catatan untuk gudang',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'mis. kebutuhan minggu depan (opsional)',
              hintStyle: const TextStyle(fontSize: 13),
              isDense: true,
              filled: true,
              fillColor: AppTheme.bgLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar(List<RequestableItem> catalogue, int filledCount) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filledCount == 0
                        ? 'Belum ada barang diisi'
                        : '$filledCount barang',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: filledCount == 0
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    'Gudang bisa menyetujui lebih sedikit',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed:
                  _saving || filledCount == 0 ? null : () => _save(catalogue),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.borderLight,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Simpan' : 'Ajukan'),
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
    final filled = packQty > 0;
    final baseTotal = packQty * template.baseQty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filled ? AppTheme.brandBlue : AppTheme.borderLight,
          width: filled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris nama berdiri sendiri supaya nama panjang boleh turun ke baris
          // kedua tanpa mendorong kotak jumlah keluar layar.
          Text(
            item.name,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Stok gudang ${_trimNum(item.warehouseQty)} ${item.unit}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: item.templates.length > 1
                    ? _templateDropdown()
                    : _templateLabel(template),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: qtyCtrl,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => onQtyChanged(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    filled: true,
                    fillColor: filled ? Colors.white : AppTheme.bgLight,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: filled
                              ? AppTheme.brandBlue
                              : AppTheme.borderLight),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Terjemahan ke satuan dasar. Muncul hanya setelah diisi, supaya
          // kartu yang kosong tetap ringkas.
          if (filled) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Diminta ${_trimNum(baseTotal)} ${item.unit}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _templateDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: templateId,
      isDense: true,
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppTheme.bgLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
      ),
      items: item.templates
          .map((t) => DropdownMenuItem(
                value: t.id,
                child: Text(
                  '${t.name} · ${_trimNum(t.baseQty)} ${item.unit}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onTemplateChanged(v);
      },
    );
  }

  Widget _templateLabel(RequestableTemplate template) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Text(
        '${template.name} · ${_trimNum(template.baseQty)} ${item.unit}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
      ),
    );
  }
}

/// Buang nol di belakang koma supaya "2" tidak tampil sebagai "2.0000".
String _trimNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
