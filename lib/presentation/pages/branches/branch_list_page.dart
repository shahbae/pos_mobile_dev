import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/branches/branch_form_page.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Daftar cabang + aksi tambah/edit.
class BranchListPage extends ConsumerWidget {
  const BranchListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Cabang')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BranchFormPage()),
        ),
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Gagal memuat cabang:\n$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(branchListProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (branches) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(branchListProvider),
          child: branches.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Belum ada cabang')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: branches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = branches[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.brandBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.store_outlined, color: AppTheme.brandBlue),
                        ),
                        title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          [
                            if (b.address != null && b.address!.isNotEmpty) b.address!,
                            if (b.footerNote != null && b.footerNote!.isNotEmpty) '🧾 ${b.footerNote!}',
                          ].join('\n'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BranchFormPage(branch: b)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
