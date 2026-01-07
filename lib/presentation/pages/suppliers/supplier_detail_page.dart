import 'package:flutter/material.dart';
import '../../../data/models/supplier_model.dart';
import '../suppliers/supplier_form_page.dart';

class SupplierDetailPage extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,

      appBar: AppBar(
        title: const Text("Detail Pemasok"),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =====================
            // HEADER NAME
            // =====================
            Text(
              supplier.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 6),

            Text(
              "Informasi pemasok & kontak",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 18),

            // =====================
            // DETAIL CARD
            // =====================
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),

              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _item("PIC", supplier.pic ?? "-"),
                    _item("Email", supplier.email ?? "-"),
                    _item("Telepon", supplier.phone ?? "-"),
                    _item("Alamat", supplier.address ?? "-"),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // =====================
            // ACTION BUTTON
            // =====================
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text("Edit Data Pemasok"),
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierFormPage(supplier: supplier),
                    ),
                  );

                  if (updated == true) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
