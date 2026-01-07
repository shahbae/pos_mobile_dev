import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/supplier_provider.dart';
import '../suppliers/supplier_detail_page.dart';
import '../suppliers/supplier_form_page.dart';

class SupplierListPage extends ConsumerStatefulWidget {
  const SupplierListPage({super.key});

  @override
  ConsumerState<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends ConsumerState<SupplierListPage> {
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

    final suppliers = ref.watch(
      supplierListProvider(search.isEmpty ? null : search),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.background,

      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        title: const Text("Data Pemasok"),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: TextStyle(color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: "Cari pemasok…",
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
            MaterialPageRoute(builder: (_) => const SupplierFormPage()),
          );

          if (created == true) {
            ref.invalidate(
              supplierListProvider(search.isEmpty ? null : search),
            );
          }
        },
        child: const Icon(Icons.add),
      ),

      body: suppliers.when(
        data: (list) => list.isEmpty
            ? Center(
                // 🔥 tambahkan Center wrapper
                child: Text(
                  search.isEmpty
                      ? "Data pemasok kosong" // 🔥 pesan jika memang kosong
                      : "Pemasok tidak ditemukan", // 🔥 pesan jika hasil pencarian kosong
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey.shade300),

                itemBuilder: (_, i) {
                  final s = list[i];

                  return ListTile(
                    leading: Icon(
                      Icons.factory,
                      color: theme.colorScheme.primary,
                    ),

                    title: Text(
                      s.name,
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    subtitle: Text(
                      s.phone ?? "-",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),

                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade500,
                    ),

                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierDetailPage(supplier: s),
                        ),
                      );

                      ref.invalidate(
                        supplierListProvider(search.isEmpty ? null : search),
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
