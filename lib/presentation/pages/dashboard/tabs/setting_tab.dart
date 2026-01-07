import 'package:flutter/material.dart';
import '../../../pages/suppliers/supplier_list_page.dart';

class SettingTab extends StatelessWidget {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,

      appBar: AppBar(
        title: const Text("Pengaturan"),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
      ),

      body: ListView(
        children: [
          const SizedBox(height: 4),

          ListTile(
            leading: Icon(
              Icons.factory_outlined,
              color: theme.colorScheme.primary,
            ),

            title: Text(
              "Pemasok",
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),

            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierListPage()),
              );
            },
          ),

          Divider(color: Colors.grey.shade300),
        ],
      ),
    );
  }
}
