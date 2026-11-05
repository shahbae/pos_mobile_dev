import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Sanggah satu kejadian KPI. Hanya sekali per kejadian; diputus SPV atau
/// owner. Mengembalikan sanggahan yang terkirim lewat `pop`.
class KpiDisputePage extends ConsumerStatefulWidget {
  final KpiEvent event;
  const KpiDisputePage({super.key, required this.event});

  @override
  ConsumerState<KpiDisputePage> createState() => _KpiDisputePageState();
}

class _KpiDisputePageState extends ConsumerState<KpiDisputePage> {
  final _reason = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final d = await ref.read(kpiRepositoryProvider).dispute(
            eventId: widget.event.id,
            reason: _reason.text.trim(),
            photo: _photo,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sanggahan terkirim. Keputusannya tampil di Skor KPI.'),
        backgroundColor: AppTheme.brandBlue,
      ));
      Navigator.pop<KpiDispute>(context, d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Sanggah Kejadian'), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
        children: [
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.indicatorCode} ${e.indicatorName}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('${kpiPoints(e.points)} poin', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                if (e.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.note, style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SdmCard(
            child: TextField(
              controller: _reason,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                hintText: 'mis. Saya bertugas penyaji hari itu, bukan kasir.',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Foto pendukung (opsional)',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
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
                              final b = await pickKpiPhotoAnySource(context);
                              if (b != null && mounted) setState(() => _photo = b);
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Tambah foto'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SdmNote(
            icon: Icons.info_outline,
            text: 'Satu kejadian hanya bisa disanggah sekali. Bila diterima, poinnya dikembalikan.',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy || _reason.text.trim().isEmpty ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kirim sanggahan'),
          ),
        ],
      ),
    );
  }
}
