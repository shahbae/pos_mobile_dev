import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/plastic_stock_movement_model.dart';
import 'package:pos_mobile/presentation/providers/plastic_provider.dart';

/// Riwayat mutasi stok plastik (IN/OUT/ADJUST), qty desimal.
class PlasticStockMovementPage extends ConsumerStatefulWidget {
  const PlasticStockMovementPage({super.key});

  @override
  ConsumerState<PlasticStockMovementPage> createState() => _PlasticStockMovementPageState();
}

class _PlasticStockMovementPageState extends ConsumerState<PlasticStockMovementPage> {
  int? _selectedPlasticId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plasticsAsync = ref.watch(plasticListProvider);
    final movementsAsync = ref.watch(plasticStockMovementListProvider(_selectedPlasticId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Riwayat Stok Plastik'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter berdasarkan Plastik:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                plasticsAsync.when(
                  data: (plastics) => DropdownButtonFormField<int?>(
                    value: _selectedPlasticId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                      const DropdownMenuItem<int?>(value: null, child: Text('Semua Plastik')),
                      ...plastics.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedPlasticId = val),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Gagal memuat plastik'),
                ),
              ],
            ),
          ),
          Expanded(
            child: movementsAsync.when(
              data: (movements) {
                if (movements.isEmpty) {
                  return Center(
                    child: Text('Belum ada riwayat stok plastik',
                        style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _item(context, movements[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat riwayat: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, PlasticStockMovement m) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
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
        typeLabel = m.type ?? '-';
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
                decoration: BoxDecoration(color: typeColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, color: typeColor, size: 14),
                    const SizedBox(width: 6),
                    Text(typeLabel,
                        style: TextStyle(fontWeight: FontWeight.w700, color: typeColor, fontSize: 11, letterSpacing: 0.5)),
                  ],
                ),
              ),
              Text(_formatDate(m.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF6B7280), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text('Ref: ${m.referenceType?.toUpperCase() ?? '-'} #${m.referenceId ?? '-'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${m.type == 'OUT' ? '-' : '+'}${_fmtQty(m.quantity)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: typeColor)),
                  Text(m.unit.isNotEmpty ? m.unit : 'Unit',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  String _formatDate(String? s) {
    if (s == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return s;
    }
  }
}
