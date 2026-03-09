import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/product_category_provider.dart';
import '../product_categories/product_category_detail_page.dart';
import '../product_categories/product_category_form_page.dart';

class ProductCategoryListPage extends ConsumerStatefulWidget {
  const ProductCategoryListPage({super.key});

  @override
  ConsumerState<ProductCategoryListPage> createState() =>
      _ProductCategoryListPageState();
}

class _ProductCategoryListPageState
    extends ConsumerState<ProductCategoryListPage> {
  String search = "";
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final categories = ref.watch(
      productCategoryListProvider(search.isEmpty ? null : search),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: const Text("Kategori Produk"),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: TextStyle(color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: "Cari kategori…",
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

              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => setState(() => search = value),
                );
              },
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProductCategoryFormPage(),
            ),
          );

          if (created == true) {
            ref.invalidate(
              productCategoryListProvider(search.isEmpty ? null : search),
            );
          }
        },
        child: const Icon(Icons.add),
      ),

      body: categories.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  search.isEmpty
                      ? "Belum ada kategori produk"
                      : "Kategori tidak ditemukan",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey.shade300),

                itemBuilder: (_, i) {
                  final c = list[i];

                  return ListTile(
                    leading: Icon(
                      Icons.category_outlined,
                      color: theme.colorScheme.primary,
                    ),

                    title: Text(
                      c.name,
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade500,
                    ),

                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductCategoryDetailPage(category: c),
                        ),
                      );

                      ref.invalidate(
                        productCategoryListProvider(
                          search.isEmpty ? null : search,
                        ),
                      );
                    },
                  );
                },
              ),

        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
