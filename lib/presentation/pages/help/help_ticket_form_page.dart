import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/presentation/providers/help_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Buat tiket bantuan (leader). Outlet diambil server dari akun leader, jadi
/// tidak dipilih di sini. Mengembalikan tiket yang dibuat lewat `pop`.
class HelpTicketFormPage extends ConsumerStatefulWidget {
  const HelpTicketFormPage({super.key});

  @override
  ConsumerState<HelpTicketFormPage> createState() => _HelpTicketFormPageState();
}

class _HelpTicketFormPageState extends ConsumerState<HelpTicketFormPage> {
  String _target = 'supervisor';
  int? _categoryId;
  final _description = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _ready => _categoryId != null && _description.text.trim().isNotEmpty;

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('Foto maksimal 5 MB.', error: true);
      return;
    }
    if (mounted) setState(() => _photo = bytes);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final t = await ref.read(helpRepositoryProvider).create(
            target: _target,
            categoryId: _categoryId!,
            description: _description.text.trim(),
            photo: _photo,
          );
      if (mounted) Navigator.pop<HelpTicket>(context, t);
    } catch (e) {
      _snack('$e', error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(helpCategoriesProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Buat Tiket'), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
        children: [
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ditujukan ke', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'supervisor', label: Text('SPV'), icon: Icon(Icons.supervisor_account_outlined)),
                    ButtonSegment(value: 'finance', label: Text('Finance'), icon: Icon(Icons.payments_outlined)),
                  ],
                  selected: {_target},
                  onSelectionChanged: (v) => setState(() => _target = v.first),
                ),
                const SizedBox(height: 16),
                categories.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.danger)),
                  data: (list) => list.isEmpty
                      ? const Text('Belum ada kategori aktif. Minta SPV menambahkannya di web admin.',
                          style: TextStyle(color: AppTheme.danger))
                      : DropdownButtonFormField<int>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: [
                            for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    hintText: 'mis. Blender mati sejak pagi, pesanan es campur tertahan.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SdmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Foto (opsional)', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                if (_photo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_photo!, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus foto'),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Kamera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeri'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy || !_ready ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kirim tiket'),
          ),
        ],
      ),
    );
  }
}
