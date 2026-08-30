import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/stock_request_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/stock_request_provider.dart';
import 'package:pos_mobile/presentation/widgets/branch_switch_sheet.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'stock_request_detail_page.dart';
import 'stock_request_form_page.dart';

class StockRequestListPage extends ConsumerWidget {
  const StockRequestListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canCreate = canCreateStockRequest(auth.role);

    // Permintaan selalu milik satu cabang. Tangkap lebih awal supaya tidak
    // berujung 400 dari BE.
    final needsBranch =
        auth.role?.toLowerCase() != 'owner' && auth.branchId == null;
    if (needsBranch) {
      return Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Permintaan Stok'), centerTitle: true),
        body: const _BranchRequiredView(),
      );
    }

    final requestsAsync = ref.watch(stockRequestListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Permintaan Stok'), centerTitle: true),
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.brandBlue,
              icon: const Icon(Icons.add),
              label: const Text('Minta Barang'),
              onPressed: () async {
                final saved = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockRequestFormPage()),
                );
                if (saved == true) ref.invalidate(stockRequestListProvider);
              },
            ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(stockRequestListProvider),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Gagal memuat permintaan:\n$e',
                    textAlign: TextAlign.center),
              ),
            ],
          ),
          data: (requests) {
            if (requests.isEmpty) return const _EmptyView();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RequestCard(
                request: requests[i],
                onChanged: () => ref.invalidate(stockRequestListProvider),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 140),
        Icon(Icons.inventory_2_outlined, size: 56, color: AppTheme.textSecondary),
        SizedBox(height: 12),
        Center(
          child: Text('Belum ada permintaan stok',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Barang dari gudang hanya datang kalau diminta lebih dulu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _BranchRequiredView extends StatelessWidget {
  const _BranchRequiredView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text('Pilih cabang dulu',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Permintaan stok selalu atas nama satu cabang. Pilih cabang aktif '
            'dulu sebelum membuka menu ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => showBranchSwitchSheet(context),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Pilih Cabang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final StockRequest request;
  final VoidCallback onChanged;
  const _RequestCard({required this.request, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StockRequestDetailPage(requestId: request.id)),
        );
        if (changed == true) onChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permintaan #${request.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    request.note.isNotEmpty ? request.note : 'Tanpa catatan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (request.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(fmtRequestDate(request.createdAt!),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            StockRequestStatusChip(status: request.status),
          ],
        ),
      ),
    );
  }
}

/// Warna status dipilih supaya "menunggu" tidak terbaca sebagai masalah dan
/// "ditolak" tidak terbaca sebagai selesai.
class StockRequestStatusChip extends StatelessWidget {
  final String status;
  const StockRequestStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    late final Color color;
    late final String label;
    switch (lower) {
      case 'submitted':
        color = Colors.orange;
        label = 'Menunggu';
        break;
      case 'approved':
        color = Colors.green;
        label = 'Disetujui';
        break;
      case 'fulfilled':
        color = Colors.teal;
        label = 'Diterima';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Ditolak';
        break;
      case 'cancelled':
        color = AppTheme.textSecondary;
        label = 'Dibatalkan';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

String fmtRequestDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}
