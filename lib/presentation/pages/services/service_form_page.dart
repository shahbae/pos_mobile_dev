import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/service_model.dart';
import '../../providers/service_provider.dart';

class ServiceFormPage extends ConsumerStatefulWidget {
  final ServiceModel? service;

  const ServiceFormPage({super.key, this.service});

  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late final TextEditingController _name;
  late final TextEditingController _price;

  String? _selectedUnitType;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  final _formatter = NumberFormat('#,###', 'id_ID');

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: widget.service?.name ?? '');
    _price = TextEditingController();

    _selectedUnitType = widget.service?.unitType ?? 'per_item';

    if (widget.service != null) {
      final pr = widget.service!.priceNum.toInt();
      if (pr > 0) _price.text = _formatter.format(pr);
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── SUBMIT ───────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final repo = ref.read(serviceRepositoryProvider);

    final priceDigits = _price.text.replaceAll(RegExp(r'[^0-9]'), '');

    final payload = {
      'name': _name.text.trim(),
      'price': '$priceDigits.00',
      'unit_type': _selectedUnitType,
    };

    debugPrint('[ServiceForm] payload=$payload');

    try {
      if (_isEdit) {
        await repo.updateService(widget.service!.id, payload);
      } else {
        await repo.createService(payload);
      }

      ref.invalidate(serviceListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isEdit
                    ? 'Layanan berhasil diperbarui'
                    : 'Layanan berhasil ditambahkan',
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error submit: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Terjadi kesalahan saat menyimpan'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isEdit ? 'Edit Layanan' : 'Tambah Layanan',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header illustration ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary.withOpacity(0.08),
                          cs.primary.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isEdit
                                ? Icons.edit_note_rounded
                                : Icons.design_services_rounded,
                            color: cs.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEdit ? 'Perbarui Layanan' : 'Layanan Baru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isEdit
                                    ? 'Edit detail informasi layanan'
                                    : 'Lengkapi data layanan di bawah ini',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Form card ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Informasi Layanan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        _buildField(
                          label: 'Nama Layanan',
                          hint: 'Contoh: Pemasangan, Perbaikan...',
                          controller: _name,
                          icon: Icons.miscellaneous_services_rounded,
                          required: true,
                        ),

                        const SizedBox(height: 18),

                        _buildMoneyField(
                          label: 'Harga Layanan',
                          controller: _price,
                          required: true,
                        ),

                        const SizedBox(height: 18),

                        _buildUnitTypeDropdown(cs),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Submit button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: cs.primary.withOpacity(0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isEdit
                                        ? Icons.save_rounded
                                        : Icons.add_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEdit
                                        ? 'Simpan Perubahan'
                                        : 'Tambah Layanan',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── UNIT TYPE DROPDOWN ───────────────────────────────
  Widget _buildUnitTypeDropdown(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Tipe Unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: 4),
            Text('*',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedUnitType,
          validator: (v) => v == null ? 'Tipe unit wajib dipilih' : null,
          decoration: InputDecoration(
            hintText: 'Pilih tipe unit',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.style_outlined,
                  size: 20, color: Color(0xFF9CA3AF)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.6),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'per_item', child: Text('Per Item')),
            DropdownMenuItem(value: 'per_hour', child: Text('Per Jam')),
            DropdownMenuItem(value: 'per_day', child: Text('Per Hari')),
          ],
          onChanged: (v) => setState(() => _selectedUnitType = v),
        ),
      ],
    );
  }

  // ─── REUSABLE FIELD ───────────────────────────────────
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                letterSpacing: 0.2,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          validator: required
              ? (v) =>
                  v == null || v.trim().isEmpty ? '$label wajib diisi' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoneyField({
    required String label,
    required TextEditingController controller,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                letterSpacing: 0.2,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          validator: required
              ? (v) => v == null || v.isEmpty ? '$label wajib diisi' : null
              : null,
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle:
                const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            hintText: '0',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.payments_outlined,
                  size: 20, color: Color(0xFF9CA3AF)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.6),
            ),
          ),
          onChanged: (value) {
            final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
            final num = int.tryParse(digits) ?? 0;
            if (num == 0) return;
            controller.value = TextEditingValue(
              text: _formatter.format(num),
              selection: TextSelection.collapsed(
                offset: _formatter.format(num).length,
              ),
            );
          },
        ),
      ],
    );
  }
}
