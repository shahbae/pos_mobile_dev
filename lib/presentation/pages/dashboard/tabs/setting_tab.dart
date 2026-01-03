import 'package:flutter/material.dart';
import '../../../pages/suppliers/supplier_list_page.dart';

class SettingTab extends StatelessWidget {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      body: ListView(
        children: [
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.factory, color: Colors.white),
            title: const Text("Pemasok", style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierListPage()),
              );
            },
          ),

          const Divider(color: Colors.white12),
        ],
      ),
    );
  }
}
