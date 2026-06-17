import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/stock_movement_provider.dart';
import '../../providers/material_provider.dart';
import '../../../data/models/material_model.dart';
import '../../../data/models/stock_movement_model.dart';

class StockMovementListPage extends ConsumerStatefulWidget {
  const StockMovementListPage({super.key});

  @override
  ConsumerState<StockMovementListPage> createState() =>
      _StockMovementListPageState();
}

class _StockMovementListPageState extends ConsumerState<StockMovementListPage> {
  int? _selectedMaterialId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materialsAsync = ref.watch(materialListProvider);
    final movementsAsync =
        ref.watch(stockMovementListProvider(_selectedMaterialId));
    final names = {
      for (final m in (materialsAsync.valueOrNull ?? const <MaterialItem>[])) m.id: m.name
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Riwayat Mutasi Stok"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter berdasarkan Material:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                materialsAsync.when(
                  data: (materials) {
                    return DropdownButtonFormField<int?>(
                      value: _selectedMaterialId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('Semua Material')),
                        ...materials.map(
                          (m) => DropdownMenuItem<int?>(
                            value: m.id,
                            child: Text(m.name),
                          ),
                        )
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedMaterialId = val;
                        });
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Gagal memuat material'),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: movementsAsync.when(
              data: (movements) {
                if (movements.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada riwayat mutasi stok',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final m = movements[i];
                    return _buildItem(context, m, names);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Gagal memuat data mutasi')),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, StockMovementModel m, Map<int, String> names) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel = m.type ?? '';

    switch (m.type) {
      case 'IN':
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.arrow_downward_rounded;
        typeLabel = 'MASUK';
        break;
      case 'OUT':
        typeColor = const Color(0xFFEF4444);
        typeIcon = Icons.arrow_upward_rounded;
        typeLabel = 'KELUAR';
        break;
      case 'ADJUST':
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.sync_alt_rounded;
        typeLabel = 'PENYESUAIAN';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(25), // ~0.1 opacity
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, color: typeColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(m.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6B7280), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.materialId != null
                          ? (names[m.materialId] ?? 'Material #${m.materialId}')
                          : 'Material',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ref: ${m.referenceType?.toUpperCase() ?? '-'} #${m.referenceId ?? '-'}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${m.type == 'OUT' ? '-' : '+'}${m.quantity}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: typeColor,
                    ),
                  ),
                  Text(
                    'Unit',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  )
                ],
              ),
            ],
          ),
        ],
      ),
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
