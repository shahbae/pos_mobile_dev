import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/product_provider.dart';
import '../../../data/models/product_model.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';
import '../../../utils/currency.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  String search = "";
  int page = 1;
  bool loadingMore = false;
  bool hasMore = true;
  bool isInitialLoading = true; // 🔥 tambahkan ini

  Timer? _debounce;
  final ScrollController _scroll = ScrollController();

  List<Product> items = [];

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

    final repo = ref.read(productRepositoryProvider);

    final result = await repo.getProducts(
      page: page,
      limit: 10,
      search: search,
    );

    setState(() {
      items.addAll(result);
      loadingMore = false;
      isInitialLoading = false; // 🔥 set false setelah load pertama
      hasMore = result.length == 10;
      if (hasMore) page++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,

      appBar: AppBar(
        title: const Text("Data Produk"),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari produk…",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
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

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormPage()),
          );

          if (created == true) _load(reset: true);
        },
      ),

      body:
          isInitialLoading // 🔥 cek loading awal dulu
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(
              child: Text(
                "Data produk kosong",
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.separated(
              controller: _scroll,
              itemCount: items.length + 1,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.grey.shade200, height: 1),
              itemBuilder: (_, i) {
                if (i == items.length) {
                  return loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox.shrink();
                }

                final p = items[i];
                return _item(context, p);
              },
            ),
    );
  }

  Widget _item(BuildContext context, Product p) {
    return ListTile(
      leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        "Stok: ${p.stock} • ${formatRupiah(p.sellingPrice)}",
        style: const TextStyle(color: Colors.black54),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black45),

      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailPage(product: p)),
        );

        if (updated == true) {
          _load(reset: true);
        }
      },
    );
  }
}
