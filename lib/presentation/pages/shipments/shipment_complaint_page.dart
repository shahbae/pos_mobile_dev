import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Komplain kualitas atas kiriman yang sudah diterima (Tahap 7, PRD-C1),
/// misalnya teh terasa asam. Finance memvalidasinya; yang valid mengurangi
/// skor tim Produksi gudang pengirim, tidak pernah skor crew.
///
/// Mengembalikan `true` lewat `pop` bila terkirim.
class ShipmentComplaintPage extends ConsumerStatefulWidget {
  final Shipment shipment;
  const ShipmentComplaintPage({super.key, required this.shipment});

  @override
  ConsumerState<ShipmentComplaintPage> createState() => _ShipmentComplaintPageState();
}

class _ShipmentComplaintPageState extends ConsumerState<ShipmentComplaintPage> {
  final _content = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  bool get _ready => _content.text.trim().isNotEmpty && _photo != null;

  Future<void> _submit() async {
    final ok = await confirmAction(
      context,
      title: 'Kirim komplain kualitas?',
      message: 'Komplain ini diperiksa finance. Kalau valid, skor tim produksi gudang berkurang.',
      confirmLabel: 'Ya, kirim',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(kpiRepositoryProvider).createQualityComplaint(
            shipmentId: widget.shipment.id,
            branchId: widget.shipment.branchId,
            content: _content.text,
            photo: _photo!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Komplain terkirim. Finance akan memeriksanya.'),
        backgroundColor: AppTheme.brandBlue,
      ));
      Navigator.pop(context, true);
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
      appBar: AppBar(title: Text('Komplain Kiriman #${widget.shipment.id}'), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
        children: [
          const SdmNote(
            icon: Icons.info_outline,
            text: 'Untuk mutu barang dari gudang (rasa, warna, kekentalan, kemasan). '
                'Barang rusak atau kedaluwarsa saat datang dicatat waktu menerima, bukan di sini.',
          ),
          const SizedBox(height: 12),
          SdmCard(
            child: TextField(
              controller: _content,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Apa masalahnya?',
                hintText: 'mis. Teh dari jerigen ini terasa asam.',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Foto (wajib)', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                if (_photo != null)
                  KpiPhotoPreview(_photo!, onRemove: _busy ? null : () => setState(() => _photo = null))
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final b = await pickKpiPhoto(context);
                              if (b != null && mounted) setState(() => _photo = b);
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Ambil foto'),
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
                : const Text('Kirim komplain'),
          ),
        ],
      ),
    );
  }
}
