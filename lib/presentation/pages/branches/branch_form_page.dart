import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Form tambah/edit cabang (name, address, footer_note).
class BranchFormPage extends ConsumerStatefulWidget {
  final BranchModel? branch;
  const BranchFormPage({super.key, this.branch});

  @override
  ConsumerState<BranchFormPage> createState() => _BranchFormPageState();
}

class _BranchFormPageState extends ConsumerState<BranchFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _footer;
  bool _loading = false;

  bool get _isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.branch?.name ?? '');
    _address = TextEditingController(text: widget.branch?.address ?? '');
    _footer = TextEditingController(text: widget.branch?.footerNote ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final repo = ref.read(branchRepositoryProvider);
    final data = {
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'footer_note': _footer.text.trim(),
    };

    try {
      if (_isEdit) {
        await repo.updateBranch(widget.branch!.id, data);
      } else {
        await repo.createBranch(data);
      }
      ref.invalidate(branchListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Cabang diperbarui' : 'Cabang ditambahkan'),
        backgroundColor: AppTheme.brandBlue,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: $e'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Cabang' : 'Tambah Cabang')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                label: 'Nama Cabang',
                controller: _name,
                hint: 'mis. Cabang Utama',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 18),
              _field(
                label: 'Alamat',
                controller: _address,
                hint: 'mis. Jl. Contoh No. 1',
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              _field(
                label: 'Catatan Footer Nota',
                controller: _footer,
                hint: 'Muncul di bagian bawah nota cetak',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              const Text(
                'Contoh: "Terima kasih sudah berkunjung!"',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isEdit ? 'Simpan Perubahan' : 'Tambah Cabang',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
          ),
        ),
      ],
    );
  }
}
