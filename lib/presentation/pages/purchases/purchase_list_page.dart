import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      appBar: AppBar(
        title: const Text("Data Pembelian"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
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
                  child: Text(
                    search.isEmpty
                        ? "Belum ada transaksi pembelian"
                        : "Pembelian tidak ditemukan",
                    style: TextStyle(color: Colors.grey.shade600),
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
