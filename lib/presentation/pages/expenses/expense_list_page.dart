import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_access.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../../utils/currency.dart';
import 'expense_detail_page.dart';
import 'expense_form_page.dart';

class ExpenseListPage extends ConsumerStatefulWidget {
  const ExpenseListPage({super.key});

  @override
  ConsumerState<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends ConsumerState<ExpenseListPage> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? fromStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final String? toStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final expensesAsync = ref.watch(expenseListProvider((fromStr, toStr)));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Pengeluaran (Expenses)"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter indicator
            if (_startDate != null || _endDate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.primary.withAlpha(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter: ${fromStr ?? "-"} s/d ${toStr ?? "-"}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        ref.invalidate(expenseListProvider);
                      },
                      child: const Icon(Icons.close, size: 18),
                    )
                  ],
                ),
              ),

            Expanded(
              child: expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      return GestureDetector(
                        onTap: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailPage(expenseId: exp.id!),
                            ),
                          );
                          if (changed == true) {
                            ref.invalidate(expenseListProvider);
                          }
                        },
                        child: _buildExpenseCard(theme, exp),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Terjadi kesalahan: $err")),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !canManageExpense(ref.watch(authProvider).role)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseFormPage()),
                );
                if (refresh == true) {
                  ref.invalidate(expenseListProvider);
                }
              },
              backgroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text(
                "Catat Pengeluaran",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Widget _buildExpenseCard(ThemeData theme, ExpenseModel exp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exp.category?.toUpperCase() ?? '-',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(exp.expenseDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  exp.description ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  formatRupiah(num.tryParse(exp.amount ?? '0') ?? 0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.money_off_csred_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Belum ada data pengeluaran",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          )
        ],
      ),
    );
  }

  String _formatDate(String? dt) {
    if (dt == null) return '-';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      return "${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}";
    } catch (_) {
      return dt;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      ref.invalidate(expenseListProvider);
    }
  }
}
