import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/qris_payment_model.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Setting QRIS cabang (docs/api-qris-manual-fe.md §5) — owner & supervisor.
///
/// Mode `manual` memakai QR statis milik cabang: owner menempel hasil scan QR
/// yang terpasang di kasir, lalu BE menyisipkan nominal tiap transaksi. Mode
/// `midtrans` dipakai begitu gateway di-ACC — tombol konfirmasi kasir hilang
/// dengan sendirinya tanpa rilis ulang aplikasi.
class QrisSettingsPage extends ConsumerStatefulWidget {
  final int branchId;
  final String? branchName;

  const QrisSettingsPage({super.key, required this.branchId, this.branchName});

  @override
  ConsumerState<QrisSettingsPage> createState() => _QrisSettingsPageState();
}

class _QrisSettingsPageState extends ConsumerState<QrisSettingsPage> {
  final _payloadController = TextEditingController();

  QrisBranchConfig? _config;
  String _mode = QrisProvider.manual;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cfg =
          await ref.read(branchRepositoryProvider).getQrisConfig(widget.branchId);
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _mode = cfg.mode;
        _payloadController.text = cfg.payload ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _toast('Clipboard kosong', danger: true);
      return;
    }
    setState(() => _payloadController.text = text);
  }

  Future<void> _save() async {
    final payload = _payloadController.text.trim();
    if (_mode == QrisProvider.manual && payload.isEmpty) {
      _toast('Mode manual membutuhkan payload QRIS statis cabang', danger: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final cfg = await ref.read(branchRepositoryProvider).saveQrisConfig(
            widget.branchId,
            mode: _mode,
            // Kirim payload hanya bila diisi — kosong berarti "biarkan yang lama".
            payload: payload.isEmpty ? null : payload,
          );
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _mode = cfg.mode;
        _payloadController.text = cfg.payload ?? payload;
        _saving = false;
      });
      _toast('Setting QRIS cabang tersimpan');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString(), danger: true);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus setting QRIS?'),
        content: const Text(
            'Payload QR cabang dihapus dan cabang kembali mengikuti mode '
            'default server. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(branchRepositoryProvider).deleteQrisConfig(widget.branchId);
      if (!mounted) return;
      _payloadController.clear();
      setState(() => _saving = false);
      _toast('Setting QRIS cabang dihapus');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString(), danger: true);
    }
  }

  void _toast(String msg, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: danger ? AppTheme.danger : AppTheme.brandBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('QRIS Cabang'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorView()
              : _form(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    final cfg = _config;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _statusCard(cfg),
        const SizedBox(height: 24),
        _label('Mode Pembayaran QRIS'),
        const SizedBox(height: 8),
        _modeSelector(),
        const SizedBox(height: 24),
        _label('Payload QR Statis'),
        const SizedBox(height: 4),
        const Text(
          'Scan QR statis yang terpasang di kasir pakai aplikasi scanner apa '
          'pun, lalu tempel teksnya utuh di sini. Nominal disisipkan otomatis '
          'oleh server tiap transaksi.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: _boxDeco(),
          child: TextField(
            controller: _payloadController,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            // Tombol "Kosongkan" ikut aktif/nonaktif mengikuti isi field.
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '00020101021126...6304AB12',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _paste,
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Tempel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brandBlue,
                  side: const BorderSide(color: AppTheme.brandBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving || _payloadController.text.isEmpty
                    ? null
                    : () => setState(_payloadController.clear),
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: const Text('Kosongkan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
        ),
        if (cfg != null && cfg.isBranchOverride) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            // BE menolak hapus selama cabang masih di mode manual.
            onPressed: _saving || cfg.isManual ? null : _delete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(cfg.isManual
                ? 'Ubah ke Midtrans dulu untuk menghapus'
                : 'Hapus setting & ikuti default server'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  /// Ringkasan kondisi cabang: mode aktif, sumbernya, dan identitas merchant
  /// hasil parse BE — supaya owner bisa memastikan "ini benar QR cabang saya".
  Widget _statusCard(QrisBranchConfig? cfg) {
    final manual = _mode == QrisProvider.manual;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(manual ? Icons.qr_code_2 : Icons.bolt,
                  color: AppTheme.brandBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.branchName ?? 'Cabang #${widget.branchId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppTheme.textPrimary),
                ),
              ),
              if (cfg != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (cfg.configured ? AppTheme.brandBlue : AppTheme.danger)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cfg.configured ? 'Sudah diatur' : 'Belum diatur',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          cfg.configured ? AppTheme.brandGreenDark : AppTheme.danger,
                    ),
                  ),
                ),
            ],
          ),
          if (cfg != null) ...[
            const SizedBox(height: 12),
            _row(
                'Sumber mode',
                cfg.isBranchOverride
                    ? 'Setting cabang ini'
                    : 'Default server'),
            if (cfg.merchantName != null) _row('Merchant', cfg.merchantName!),
            if (cfg.nmid != null) _row('NMID', cfg.nmid!),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return Column(
      children: [
        _modeTile(
          value: QrisProvider.manual,
          title: 'Manual (QR statis cabang)',
          subtitle:
              'Pelanggan scan QR cabang, kasir menekan "Pembayaran Diterima" '
              'setelah dana masuk. Uang langsung ke rekening cabang.',
        ),
        const SizedBox(height: 10),
        _modeTile(
          value: QrisProvider.midtrans,
          title: 'Midtrans (gateway)',
          subtitle:
              'Pembayaran dikonfirmasi otomatis oleh gateway. Pakai ini setelah '
              'akun Midtrans di-ACC.',
        ),
      ],
    );
  }

  Widget _modeTile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _mode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _saving ? null : () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.brandBlue : AppTheme.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.brandBlue : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          color: AppTheme.textPrimary));

  BoxDecoration _boxDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      );
}
