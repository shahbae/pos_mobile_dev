import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/employee_model.dart';
import 'package:pos_mobile/presentation/providers/employee_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class EmployeeFormPage extends ConsumerStatefulWidget {
  final Employee? employee;
  const EmployeeFormPage({super.key, this.employee});

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _status = 'active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee?.name ?? '');
    _emailController = TextEditingController(text: widget.employee?.email ?? '');
    _passwordController = TextEditingController();
    _status = widget.employee?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = EmployeeRequest(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text.isEmpty ? null : _passwordController.text,
      status: _status,
    );

    bool success;
    if (widget.employee == null) {
      success = await ref.read(employeeProvider.notifier).createEmployee(request);
    } else {
      success = await ref.read(employeeProvider.notifier).updateEmployee(widget.employee!.id, request);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Berhasil ${widget.employee == null ? 'menambah' : 'mengubah'} karyawan")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Terjadi kesalahan")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.employee == null ? "Tambah Karyawan" : "Edit Karyawan"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Nama Lengkap"),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Masukkan nama"),
                validator: (v) => v == null || v.isEmpty ? "Nama wajib diisi" : null,
              ),
              const SizedBox(height: 20),
              _buildLabel("Email"),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration("Masukkan email"),
                validator: (v) => v == null || v.isEmpty ? "Email wajib diisi" : null,
              ),
              const SizedBox(height: 20),
              _buildLabel(widget.employee == null ? "Password" : "Password (Kosongkan jika tidak diubah)"),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration("Masukkan password"),
                validator: (v) {
                  if (widget.employee == null && (v == null || v.isEmpty)) return "Password wajib diisi";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildLabel("Status"),
              Row(
                children: [
                  _statusRadio("Aktif", 'active'),
                  const SizedBox(width: 16),
                  _statusRadio("Non-aktif", 'inactive'),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.employee == null ? "Simpan" : "Simpan Perubahan",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
    );
  }

  Widget _statusRadio(String label, String value) {
    return InkWell(
      onTap: () => setState(() => _status = value),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: _status,
            activeColor: AppTheme.brandBlue,
            onChanged: (v) => setState(() => _status = v!),
          ),
          Text(label),
        ],
      ),
    );
  }
}
