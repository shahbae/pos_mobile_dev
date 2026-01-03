import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/supplier_model.dart';
import '../../providers/supplier_provider.dart';

class SupplierFormPage extends ConsumerStatefulWidget {
  final Supplier? supplier; // <-- kalau null berarti create

  const SupplierFormPage({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends ConsumerState<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController name;
  late final TextEditingController pic;
  late final TextEditingController email;
  late final TextEditingController phone;
  late final TextEditingController address;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    name = TextEditingController(text: widget.supplier?.name ?? "");
    pic = TextEditingController(text: widget.supplier?.pic ?? "");
    email = TextEditingController(text: widget.supplier?.email ?? "");
    phone = TextEditingController(text: widget.supplier?.phone ?? "");
    address = TextEditingController(text: widget.supplier?.address ?? "");
  }

  @override
  void dispose() {
    name.dispose();
    pic.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final payload = {
      "name": name.text,
      "pic": pic.text,
      "email": email.text,
      "phone": phone.text,
      "address": address.text,
    };

    final repo = ref.read(supplierRepositoryProvider);
    final editMode = widget.supplier != null;

    try {
      if (editMode) {
        await repo.updateSupplier(widget.supplier!.id, payload);
      } else {
        await repo.createSupplier(payload);
      }

      ref.invalidate(supplierListProvider);

      // 🔵 Tampilkan snackbar sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            editMode
                ? "Pemasok berhasil diperbarui"
                : "Pemasok berhasil ditambahkan",
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      // 🔴 Error notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Gagal menyimpan data pemasok"),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editMode = widget.supplier != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(editMode ? "Edit Pemasok" : "Tambah Pemasok"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              field("Nama", name),
              field("PIC", pic),
              field("Email", email),
              field("Telepon", phone),
              field("Alamat", address, multiline: true),

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(editMode ? "Simpan" : "Buat"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget field(
    String label,
    TextEditingController c, {
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: multiline ? 4 : 1,
        minLines: multiline ? 3 : 1,
        style: const TextStyle(color: Colors.white),
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
      ),
    );
  }
}
