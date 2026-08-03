import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';

class ExpenseFormEditPage extends ConsumerStatefulWidget {
  final ExpenseModel expense;
  const ExpenseFormEditPage({super.key, required this.expense});

  @override
  ConsumerState<ExpenseFormEditPage> createState() => _ExpenseFormEditPageState();
}

class _ExpenseFormEditPageState extends ConsumerState<ExpenseFormEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late final TextEditingController _amountController;
  late final TextEditingController _descController;
  late String _selectedCategory;
  late DateTime _selectedDate;

  final List<String> _categories = ['operational', 'marketing', 'salary', 'other'];

  /// Foto pengganti. `null` = pertahankan foto bukti lama di server.
  XFile? _newPhoto;
  static const _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};
  static const _maxBytes = 2 * 1024 * 1024; // 2 MB

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.expense.amount ?? '');
    _descController = TextEditingController(text: widget.expense.description ?? '');
    _selectedCategory = widget.expense.category ?? 'operational';
    try {
      _selectedDate = DateTime.parse(widget.expense.expenseDate ?? DateTime.now().toIso8601String());
    } catch (_) {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFEF4444) : null,
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80, // jaga tetap di bawah 2 MB + konversi HEIC → JPEG (iOS)
      maxWidth: 1600,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    if (!_allowedExt.contains(ext)) {
      if (!mounted) return;
      _snack('Format foto harus JPG, PNG, atau WEBP.', error: true);
      return;
    }
    final size = await picked.length();
    if (size > _maxBytes) {
      if (!mounted) return;
      _snack('Ukuran foto maksimal 2 MB.', error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _newPhoto = picked);
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final repo = ref.read(expenseRepositoryProvider);

    final payload = {
      'amount': _amountController.text.replaceAll('.', '').replaceAll(',', ''),
      'category': _selectedCategory,
      'description': _descController.text,
      'expense_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
    };

    try {
      await repo.updateExpense(
        widget.expense.id!,
        payload,
        photoPath: _newPhoto?.path, // null = foto bukti lama dipertahankan
      );
      if (!mounted) return;
      _snack('Berhasil mengupdate pengeluaran');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Preview: file lokal kalau user sudah memilih foto baru, kalau tidak foto
  /// bukti lama dari server. Data lama bisa saja belum punya foto.
  Widget _buildPhotoPreview() {
    if (_newPhoto != null) {
      return Image.file(
        File(_newPhoto!.path),
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      );
    }
    final url = widget.expense.photoUrl;
    if (url == null) return _photoPlaceholder('Belum ada foto bukti');
    return Image.network(
      url,
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) => progress == null
          ? child
          : Container(
              height: 180,
              color: Colors.grey.shade100,
              child: const Center(child: CircularProgressIndicator()),
            ),
      errorBuilder: (ctx, _, __) => _photoPlaceholder('Foto gagal dimuat'),
    );
  }

  Widget _photoPlaceholder(String label) {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFFF9FAFB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dt != null) setState(() => _selectedDate = dt);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Edit Pengeluaran'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AMOUNT ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jumlah / Nominal *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.6)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── DETAILS ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kategori Pengeluaran *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.6)),
                        ),
                        items: _categories.map((t) {
                          String label = t;
                          if (t == 'operational') label = 'Operasional';
                          if (t == 'marketing') label = 'Marketing';
                          if (t == 'salary') label = 'Gaji Pegawai';
                          if (t == 'other') label = 'Lainnya';
                          return DropdownMenuItem(value: t, child: Text(label));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v!),
                      ),

                      const SizedBox(height: 20),

                      const Text('Tanggal Pengeluaran *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd MMMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 15)),
                              Icon(Icons.calendar_month, color: cs.primary),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text('Keterangan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Keterangan pengeluaran',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.6)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── FOTO BUKTI (ganti, tidak bisa dihapus) ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Foto Bukti', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 4),
                      Text(
                        _newPhoto != null
                            ? 'Foto baru akan menggantikan bukti lama.'
                            : 'Biarkan kosong untuk mempertahankan foto lama.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildPhotoPreview(),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _loading ? null : _choosePhotoSource,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: Text(_newPhoto == null ? 'Ganti Foto' : 'Pilih Foto Lain'),
                      ),
                      if (_newPhoto != null)
                        TextButton.icon(
                          onPressed: _loading ? null : () => setState(() => _newPhoto = null),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Batal ganti, pakai foto lama'),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Simpan Perubahan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
