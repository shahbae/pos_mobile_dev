import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/purchase_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/auth/role_access.dart';
import '../../../data/models/purchase_model.dart';
import 'purchase_form_page.dart';
import 'purchase_detail_page.dart';

class PurchaseListPage extends ConsumerStatefulWidget {
  const PurchaseListPage({super.key});

  @override
  ConsumerState<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends ConsumerState<PurchaseListPage> {
  String search = "";
  int page = 1;
  bool loadingMore = false;
  bool hasMore = true;
  bool isInitialLoading = true;

  /// Rentang tanggal aktif; null = tanpa filter tanggal (semua pembelian).
  DateTimeRange? _range;

  Timer? _debounce;
  final ScrollController _scroll = ScrollController();

  List<PurchaseModel> items = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);

    _scroll.addListener(() async {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120 &&
          !loadingMore &&
          hasMore) {
        await _load();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      page = 1;
      hasMore = true;
      items.clear();
    }

    setState(() => loadingMore = true);

    final repo = ref.read(purchaseRepositoryProvider);

    try {
      final result = await repo.getPurchases(
        page: page,
        limit: 10,
        search: search,
        from: _range?.start,
        to: _range?.end,
      );

      setState(() {
        items.addAll(result);
        loadingMore = false;
        isInitialLoading = false;
        hasMore = result.length == 10;
        if (hasMore) page++;
      });
    } catch (e) {
      setState(() {
        loadingMore = false;
        isInitialLoading = false;
      });
    }
  }

  /// Label rentang aktif: satu hari → "03 Agu 2026", lebih → "01 – 03 Agu 2026".
  String get _rangeLabel {
    final r = _range;
    if (r == null) return "Semua Tanggal";
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    if (DateUtils.isSameDay(r.start, r.end)) return fmt.format(r.start);
    return "${fmt.format(r.start)} – ${fmt.format(r.end)}";
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load(reset: true);
  }

  void _clearRange() {
    setState(() => _range = null);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRange = _range != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      appBar: AppBar(
        title: const Text("Data Pembelian"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Filter tanggal",
            icon: Icon(
              hasRange ? Icons.event_available : Icons.date_range_outlined,
              color: hasRange ? theme.colorScheme.primary : null,
            ),
            onPressed: _pickRange,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasRange ? 108 : 60),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
              style: TextStyle(color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: "Cari pembelian (opsional)...",
                hintStyle: TextStyle(color: Colors.grey.shade500),

                filled: true,
                fillColor: theme.colorScheme.surface,

                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  search = v;
                  _load(reset: true);
                });
              },
            ),
              ),
              if (hasRange)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: InputChip(
                          avatar: Icon(
                            Icons.date_range,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _rangeLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.08),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          onPressed: _pickRange,
                          onDeleted: _clearRange,
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),

      floatingActionButton: !canCreatePurchase(ref.watch(authProvider).role)
          ? null
          : FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchaseFormPage()),
                );

                if (created == true) _load(reset: true);
              },
            ),

      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      search.isNotEmpty
                          ? "Pembelian tidak ditemukan"
                          : hasRange
                              ? "Tidak ada pembelian pada $_rangeLabel"
                              : "Belum ada transaksi pembelian",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade300, height: 1),
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      return loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }

                    final p = items[i];
                    return _item(context, p);
                  },
                ),
    );
  }

  Widget _item(BuildContext context, PurchaseModel p) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        Icons.shopping_cart_checkout_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        p.supplierName != null 
            ? "Pembelian #${p.id} (${p.supplierName})"
            : "Pembelian #${p.id} (Pemasok ${p.supplierId ?? '-'})",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.note ?? '-',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDate(p.createdAt),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: () {
        if (p.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseDetailPage(purchaseId: p.id!),
            ),
          );
        }
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
