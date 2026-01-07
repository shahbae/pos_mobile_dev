import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/supplier_model.dart';
import '../../providers/supplier_provider.dart';
import '../../widgets/text_input_field.dart';

class SupplierFormPage extends ConsumerStatefulWidget {
  final Supplier? supplier;

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

    final repo = ref.read(supplierRepositoryProvider);
    final edit = widget.supplier != null;

    final payload = {
      "name": name.text,
      "pic": pic.text,
      "email": email.text,
      "phone": phone.text,
      "address": address.text,
    };

    try {
      if (edit) {
        await repo.updateSupplier(widget.supplier!.id, payload);
      } else {
        await repo.createSupplier(payload);
      }

      ref.invalidate(supplierListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            edit
                ? "Pemasok berhasil diperbarui"
                : "Pemasok berhasil ditambahkan",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal menyimpan data pemasok"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.supplier != null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,

      appBar: AppBar(
        elevation: 0,
        title: Text(edit ? "Edit Pemasok" : "Tambah Pemasok"),
        backgroundColor: Theme.of(context).colorScheme.background,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Form(
              key: _formKey,

              child: ListView(
                children: [
                  TextInputField(
                    label: "Nama",
                    hint: "Masukkan nama pemasok",
                    controller: name,
                    validator: (v) =>
                        v == null || v.isEmpty ? "Wajib diisi" : null,
                  ),

                  TextInputField(
                    label: "PIC",
                    hint: "Nama penanggung jawab",
                    controller: pic,
                  ),

                  TextInputField(
                    label: "Email",
                    hint: "nama@email.com",
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  TextInputField(
                    label: "Telepon",
                    hint: "08xxxxxxxxxx",
                    controller: phone,
                    keyboardType: TextInputType.phone,
                  ),

                  TextInputField(
                    label: "Alamat",
                    hint: "Masukkan alamat lengkap pemasok",
                    controller: address,
                    multiline: true,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: loading
                          ? const CircularProgressIndicator()
                          : Text(edit ? "Simpan" : "Buat"),
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

  Widget field(
    String label,
    TextEditingController c, {
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        maxLines: multiline ? 4 : 1,
        validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
