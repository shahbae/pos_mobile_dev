import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class BranchSwitchSheet extends ConsumerStatefulWidget {
  const BranchSwitchSheet({super.key});

  @override
  ConsumerState<BranchSwitchSheet> createState() => _BranchSwitchSheetState();
}

class _BranchSwitchSheetState extends ConsumerState<BranchSwitchSheet> {
  bool _switching = false;
  String? _error;

  /// Cabang yang sedang dituju — dipakai supaya spinner muncul di baris yang
  /// ditekan, bukan di cabang yang masih aktif.
  int? _targetBranchId;

  Future<void> _onSelect(int branchId) async {
    final currentBranchId = ref.read(authProvider).branchId;
    if (branchId == currentBranchId) {
      Navigator.pop(context);
      return;
    }

    // Keranjang milik cabang lama: produk, harga, dan stoknya tidak berlaku di
    // cabang baru. Dibuang, tapi kasir dikasih tahu dulu supaya tidak kaget
    // kehilangan pesanan yang sedang disusun.
    final cart = ref.read(productTransactionProvider);
    if (cart.items.isNotEmpty) {
      final lanjut = await _confirmDiscardCart(cart.items.length);
      if (lanjut != true || !mounted) return;
    }

    setState(() {
      _switching = true;
      _targetBranchId = branchId;
      _error = null;
    });

    try {
      ref.read(productTransactionProvider.notifier).clearCart();
      // switchBranch menaikkan branchScopeProvider, yang merontokkan seluruh
      // data cabang lama sekaligus — lihat providers/branch_scope.dart.
      await ref.read(branchSwitchProvider.notifier).switchBranch(branchId);
      if (!mounted) return;

      // Pulang ke Beranda: halaman yang sedang terbuka bisa saja menampilkan
      // detail milik cabang lama, dan menutupnya lebih aman daripada
      // membiarkannya memuat ulang dengan id yang sudah tidak relevan.
      ref.read(dashboardIndexProvider.notifier).state = 0;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _switching = false;
          _targetBranchId = null;
          _error = e.toString();
        });
      }
    }
  }

  Future<bool?> _confirmDiscardCart(int itemCount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keranjang akan dikosongkan'),
        content: Text(
          'Ada $itemCount item di keranjang yang belum dibayar. Item itu milik '
          'cabang saat ini dan akan dibuang kalau Anda pindah cabang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Pindah & Kosongkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchAsync = ref.watch(branchListProvider);
    final currentBranchId = ref.watch(authProvider).branchId;
    final accent = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Tombol kembali dimatikan selama pindah: membatalkan di tengah jalan
    // meninggalkan token cabang baru dengan data cabang lama di layar.
    return PopScope(
      canPop: !_switching,
      child: Stack(
        children: [
          _sheetBody(branchAsync, currentBranchId, accent, bottomInset),
          if (_switching) _switchingOverlay(accent),
        ],
      ),
    );
  }

  /// Menutup seluruh sheet selama data cabang lama dibuang dan cabang baru
  /// dimuat, supaya kasir tidak menekan cabang lain di tengah proses.
  Widget _switchingOverlay(Color accent) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: Colors.white.withOpacity(0.92),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
              ),
              const SizedBox(height: 16),
              const Text(
                'Menyiapkan data cabang…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Data cabang sebelumnya sedang dibersihkan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetBody(
    AsyncValue<List<BranchModel>> branchAsync,
    int? currentBranchId,
    Color accent,
    double bottomInset,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.store_outlined, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pilih Cabang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withOpacity(0.20)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          branchAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    e.toString(),
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(branchListProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
            data: (branches) {
              if (branches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Tidak ada cabang tersedia',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: branches.map((branch) {
                  final isActive = branch.id == currentBranchId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _switching ? null : () => _onSelect(branch.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? accent.withOpacity(0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? accent.withOpacity(0.40)
                                : AppTheme.borderLight,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: 20,
                              color: isActive ? accent : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                branch.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? accent : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (_switching && branch.id == _targetBranchId)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              )
                            else if (isActive)
                              Icon(Icons.check_circle, color: accent, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

void showBranchSwitchSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const BranchSwitchSheet(),
  );
}
