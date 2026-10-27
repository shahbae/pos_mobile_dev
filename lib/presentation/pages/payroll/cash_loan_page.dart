import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pos_mobile/data/models/payroll_model.dart';
import 'package:pos_mobile/presentation/pages/payroll/payroll_widgets.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Pinjaman tunai yang ditunjuk finance ke laci outlet ini (Tahap 2 SDM).
/// Kasir yang sedang buka shift menyerahkan uangnya ke peminjam dan memotret
/// serah terimanya. Uang itu tercatat sebagai pengeluaran "pinjaman karyawan"
/// di shift yang buka, jadi tutup shift tetap cocok dengan isi laci.
class CashLoanPage extends ConsumerStatefulWidget {
  const CashLoanPage({super.key});

  @override
  ConsumerState<CashLoanPage> createState() => _CashLoanPageState();
}

class _CashLoanPageState extends ConsumerState<CashLoanPage> {
  bool _busy = false;
  String _progress = '';

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  Future<void> _handOut(LoanModel loan) async {
    final yakin = await confirmAction(
      context,
      title: 'Serahkan ${formatRupiah(loan.amount)}?',
      message: 'Ambil ${formatRupiah(loan.amount)} dari laci dan serahkan ke ${loan.userName}. '
          'Sesudah ini kamera terbuka: foto saat uang diserahkan.',
      confirmLabel: 'Ambil foto',
    );
    if (!yakin || !mounted) return;
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75, // batas server 5 MB
      maxWidth: 1280,
    );
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _progress = 'Mengirim foto…';
    });
    try {
      await ref.read(payrollRepositoryProvider).handOut(loan.id, photo.path);
      if (!mounted) return;
      ref.invalidate(cashPendingLoansProvider);
      // Ringkasan uang laci shift ikut berubah.
      ref.invalidate(currentShiftProvider);
      _snack('Serah terima tercatat. ${formatRupiah(loan.amount)} keluar dari laci.');
    } catch (e) {
      if (!mounted) return;
      ref.invalidate(cashPendingLoansProvider);
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noBranch = ref.watch(authProvider).branchId == null;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Pinjaman Tunai'), centerTitle: true),
      body: Stack(
        children: [
          if (noBranch)
            const SdmStateView(
              icon: Icons.store_outlined,
              message: 'Pilih cabang aktif dulu lewat menu Ganti Cabang.',
            )
          else
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(cashPendingLoansProvider),
              child: ref.watch(cashPendingLoansProvider).when(
                    loading: SdmStateView.loading,
                    error: (e, _) => SdmStateView(
                      icon: Icons.error_outline,
                      message: '$e',
                      onRetry: () => ref.invalidate(cashPendingLoansProvider),
                    ),
                    data: (rows) => ListView(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
                      children: [
                        const SdmNote(
                          icon: Icons.info_outline,
                          text: 'Pinjaman yang sudah disetujui owner dan ditunjuk finance untuk '
                              'diambil tunai di outlet ini. Uangnya keluar dari laci shift yang '
                              'sedang buka dan tercatat sebagai pengeluaran.',
                        ),
                        const SizedBox(height: 16),
                        if (rows.isEmpty)
                          const SdmEmpty(
                            icon: Icons.payments_outlined,
                            message: 'Tidak ada pinjaman yang menunggu diserahkan.',
                          ),
                        for (final l in rows) ...[
                          _PendingCard(loan: l, onHandOut: _busy ? null : () => _handOut(l)),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
            ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 16),
                          Text(_progress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback? onHandOut;
  const _PendingCard({required this.loan, this.onHandOut});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.userName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ),
              Text(formatRupiah(l.amount),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.purpose, style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Disetujui ${payrollDateTime(l.approvedAt)}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onHandOut,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Serahkan & foto'),
            ),
          ),
        ],
      ),
    );
  }
}
