import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_access.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../../utils/currency.dart';
import 'expense_form_edit_page.dart';

class ExpenseDetailPage extends ConsumerWidget {
  final int expenseId;
  const ExpenseDetailPage({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final canManage = canManageExpense(ref.watch(authProvider).role);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Detail Pengeluaran"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          expenseAsync.maybeWhen(
            data: (exp) => exp != null && canManage
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseFormEditPage(expense: exp),
                            ),
                          );
                          if (updated == true) {
                            ref.invalidate(expenseDetailProvider(expenseId));
                            ref.invalidate(expenseListProvider);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus',
                        onPressed: () => _confirmDelete(context, ref, exp),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : const SizedBox(),
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: expenseAsync.when(
        data: (exp) {
          if (exp == null) {
            return const Center(child: Text("Data tidak ditemukan"));
          }
          return _buildBody(context, theme, exp);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Gagal memuat: $err")),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, ExpenseModel exp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── AMOUNT HERO ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withAlpha(20),
                  Colors.red.withAlpha(10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp.description ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exp.category?.toUpperCase() ?? '-',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  formatRupiah(num.tryParse(exp.amount ?? '0') ?? 0),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.red),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── INFO ROWS ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _infoRow(Icons.calendar_today_outlined, "Tanggal Pengeluaran", _fmtDate(exp.expenseDate)),
                const Divider(height: 28),
                _infoRow(Icons.category_outlined, "Kategori", _categoryLabel(exp.category)),
                const Divider(height: 28),
                _infoRow(Icons.description_outlined, "Keterangan", exp.description ?? '-'),
                if (exp.createdAt != null) ...[
                  const Divider(height: 28),
                  _infoRow(Icons.access_time_rounded, "Dicatat pada", _fmtDateTime(exp.createdAt!)),
                ]
              ],
            ),
          ),

          // ─── FOTO BUKTI ───
          if (exp.photoUrl != null) ...[
            const SizedBox(height: 24),
            const Text("Foto Bukti",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openPhoto(context, exp.photoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  exp.photoUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : Container(
                          height: 220,
                          color: Colors.grey.shade100,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (ctx, _, __) => Container(
                    height: 220,
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(url,
                    errorBuilder: (c, _, __) =>
                        const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ExpenseModel exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengeluaran'),
        content: Text('Yakin ingin menghapus pengeluaran "${exp.description ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final repo = ref.read(expenseRepositoryProvider);
      try {
        await repo.deleteExpense(exp.id!);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengeluaran berhasil dihapus')));
        ref.invalidate(expenseListProvider);
        Navigator.pop(context, true);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  String _fmtDate(String? dt) {
    if (dt == null) return '-';
    try {
      final p = DateTime.parse(dt).toLocal();
      return DateFormat('dd MMMM yyyy').format(p);
    } catch (_) { return dt; }
  }

  String _fmtDateTime(String dt) {
    try {
      final p = DateTime.parse(dt).toLocal();
      return DateFormat('dd MMM yyyy HH:mm').format(p);
    } catch (_) { return dt; }
  }

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'operational': return 'Operasional';
      case 'marketing': return 'Marketing';
      case 'salary': return 'Gaji Pegawai';
      default: return cat ?? '-';
    }
  }
}
