import 'package:flutter/material.dart';
import '../../../data/models/supplier_model.dart';
import '../suppliers/supplier_form_page.dart';

class SupplierDetailPage extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("Detail Pemasok"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplier.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            _item("PIC", supplier.pic),
            _item("Email", supplier.email),
            _item("Telepon", supplier.phone),
            _item("Alamat", supplier.address),

            const Spacer(),

            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierFormPage(supplier: supplier),
                    ),
                  );

                  if (updated == true) {
                    Navigator.pop(context); // balik ke list supaya reload
                  }
                },

                child: const Text("Edit Data Pemasok"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
