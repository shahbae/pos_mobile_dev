import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/supplier_provider.dart';
import '../suppliers/supplier_detail_page.dart';
import '../suppliers/supplier_form_page.dart';

class SupplierListPage extends ConsumerWidget {
  const SupplierListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(supplierListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("Data Pemasok"),
      ),

      body: suppliers.when(
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white12),
          itemBuilder: (_, i) {
            final s = list[i];
            return ListTile(
              leading: const Icon(Icons.factory, color: Colors.white),
              title: Text(s.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                s.phone ?? '-',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupplierDetailPage(supplier: s),
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupplierFormPage()),
          );

          if (res != null) {
            await ref.read(supplierRepositoryProvider).createSupplier(res);

            ref.invalidate(supplierListProvider);
          }
        },
      ),
    );
  }
}
