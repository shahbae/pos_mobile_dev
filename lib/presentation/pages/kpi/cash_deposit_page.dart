import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/utils/currency_input_formatter.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

final _day = DateFormat('EEE d MMM yyyy', 'id_ID');
final _when = DateFormat('d MMM, HH.mm', 'id_ID');
final _ymd = DateFormat('yyyy-MM-dd');

/// Batas tanggal operasional di server (`kpiDepositMaxAgeDays`).
const kDepositMaxAgeDays = 31;

/// Batas foto bukti di server (`KPIDepositMaxPhotos`).
const kDepositMaxPhotos = 5;

/// Jam batas setoran di server (`kpiDepositDefaultCutoff`), sehari sesudah
/// tanggal operasional.
const kDepositCutoffHour = 19;

DateTime _yesterday() => DateUtils.addDaysToDate(DateUtils.dateOnly(DateTime.now()), -1);

Color cashDepositStatusColor(String status) => switch (status) {
  'pending' => const Color(0xFFD97706),
  'verified' => const Color(0xFF15803D),
  'rejected' => AppTheme.danger,
  _ => AppTheme.textSecondary,
};

/// Setoran tunai outlet ke rekening (Tahap 6, L5.A) — leader. Finance atau
/// owner menekan Verified di web; kejadian terlambat baru berlaku sesudahnya.
class CashDepositPage extends ConsumerWidget {
  const CashDepositPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashDepositsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Future<void> openForm({CashDeposit? retry}) async {
      final sent = await Navigator.push<CashDeposit>(
        context,
        MaterialPageRoute(builder: (_) => CashDepositFormPage(retry: retry)),
      );
      if (sent != null) ref.invalidate(cashDepositsProvider);
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Setoran'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openForm,
        icon: const Icon(Icons.add),
        label: const Text('Kirim setoran'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cashDepositsProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(cashDepositsProvider),
          ),
          data: (rows) => ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + bottomInset),
            children: [
              const SdmNote(
                icon: Icons.info_outline,
                text: 'Kirim bukti transfer setoran penjualan kemarin, paling lambat hari ini '
                    'pukul $kDepositCutoffHour.00. Jam transfer dicatat saat bukti diunggah.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const SdmEmpty(icon: Icons.account_balance_outlined, message: 'Belum ada setoran.')
              else
                for (final d in rows) ...[
                  _DepositCard(d: d, onRetry: d.status == 'rejected' ? () => openForm(retry: d) : null),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final CashDeposit d;
  final VoidCallback? onRetry;
  const _DepositCard({required this.d, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(d.operationalDate);
    final sub = [
      if (d.transferAt != null) 'transfer ${_when.format(d.transferAt!.toLocal())}',
      if (d.leaderName.isNotEmpty) d.leaderName,
    ].join(' · ');
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.photoUrl != null) ...[
                KpiThumb(d.photoUrl!, size: 52),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatRupiah(d.amount),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                    Text(date == null ? d.operationalDate : _day.format(date),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (d.photoUrls.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final url in d.photoUrls.skip(1)) KpiThumb(url, size: 44)],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              SdmPill(cashDepositStatusLabels[d.status] ?? d.status, color: cashDepositStatusColor(d.status)),
              if (d.late) const SdmPill('Terlambat', color: AppTheme.danger),
            ],
          ),
          if (d.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(d.note, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          if (d.status == 'verified' && d.verifiedByName != null) ...[
            const SizedBox(height: 6),
            Text('Diverifikasi ${d.verifiedByName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (d.status == 'rejected') ...[
            const SizedBox(height: 6),
            Text(
              'Ditolak${d.rejectedByName == null ? '' : ' oleh ${d.rejectedByName}'}: ${d.rejectReason}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.danger),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Kirim ulang'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Form kirim setoran. Tanggal otomatis kemarin; tanggal yang lebih lama boleh
/// untuk setoran tertinggal. [retry]: setoran yang ditolak, tanggal dan
/// nominalnya diisikan lagi. [pickPhoto]: pengganti pemilih foto untuk tes.
class CashDepositFormPage extends ConsumerStatefulWidget {
  final CashDeposit? retry;
  final Future<Uint8List?> Function(BuildContext context)? pickPhoto;
  const CashDepositFormPage({super.key, this.retry, this.pickPhoto});

  @override
  ConsumerState<CashDepositFormPage> createState() => _CashDepositFormPageState();
}

class _CashDepositFormPageState extends ConsumerState<CashDepositFormPage> {
  late DateTime _date = _initialDate();
  late final _amount = TextEditingController(
    text: widget.retry == null ? '' : NumberFormat.decimalPattern('id_ID').format(widget.retry!.amount.round()),
  );
  final _note = TextEditingController();
  final List<Uint8List> _photos = [];
  bool _busy = false;

  DateTime _initialDate() {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = _yesterday();
    final d = widget.retry == null ? null : DateTime.tryParse(widget.retry!.operationalDate);
    if (d == null || d.isAfter(yesterday) || today.difference(d).inDays > kDepositMaxAgeDays) return yesterday;
    return d;
  }

  /// Batas kirim tanggal terpilih, cermin `depositDeadline` di server.
  String get _deadlineHint {
    final deadline = DateTime(_date.year, _date.month, _date.day + 1, kDepositCutoffHour);
    if (DateTime.now().isAfter(deadline)) {
      return 'Sudah lewat batas kirim ${_when.format(deadline)}, setoran tercatat terlambat.';
    }
    return 'Batas kirim ${_when.format(deadline)}.';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _amountValue => int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  bool get _ready => _amountValue > 0 && _photos.isNotEmpty;

  Future<void> _addPhoto() async {
    final pick = widget.pickPhoto ?? pickKpiPhotoAnySource;
    final b = await pick(context);
    if (b != null && mounted) setState(() => _photos.add(b));
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: kDepositMaxAgeDays)),
      lastDate: _yesterday(),
      helpText: 'Tanggal operasional',
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final d = await ref.read(kpiRepositoryProvider).createCashDeposit(
            operationalDate: _ymd.format(_date),
            amount: _amountValue,
            photos: _photos,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(d.late ? 'Setoran terkirim, tercatat terlambat.' : 'Setoran terkirim.'),
        backgroundColor: d.late ? const Color(0xFFD97706) : AppTheme.brandBlue,
      ));
      Navigator.pop<CashDeposit>(context, d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Kirim Setoran'), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
        children: [
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _busy ? null : _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tanggal operasional',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      helperText: _deadlineHint,
                      helperMaxLines: 2,
                    ),
                    child: Text(_day.format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp '),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bukti transfer', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                const Text('Foto struk atau tangkapan layar m-banking, paling banyak $kDepositMaxPhotos foto.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                if (_photos.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _photos.length; i++)
                        _PhotoTile(
                          key: ValueKey('bukti-$i-${_photos[i].length}'),
                          bytes: _photos[i],
                          onRemove: _busy ? null : () => setState(() => _photos.removeAt(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_photos.length < kDepositMaxPhotos)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _addPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(_photos.isEmpty ? 'Tambah bukti' : 'Tambah bukti (${_photos.length}/$kDepositMaxPhotos)'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy || !_ready ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kirim setoran'),
          ),
        ],
      ),
    );
  }
}

/// Satu foto bukti di form, dengan tombol hapus di sudutnya.
class _PhotoTile extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback? onRemove;
  const _PhotoTile({super.key, required this.bytes, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Tooltip(
                    message: 'Hapus foto',
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
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
