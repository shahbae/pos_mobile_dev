import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/stock_tab.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';

import 'package:pos_mobile/presentation/pages/dashboard/tabs/home_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/sales_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/report_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/setting_tab.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/product_transaction_page.dart';
import 'package:pos_mobile/presentation/pages/shifts/shift_guard.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = accessForRole(ref.watch(authProvider).role);
    final isStockOnly = access == AppAccess.stockOnly;

    final rawIndex = ref.watch(dashboardIndexProvider);
    // Role stok-saja hanya boleh halaman Stok(2) & Pengaturan(4).
    final index = isStockOnly ? (rawIndex == 4 ? 4 : 2) : rawIndex;

    final shortest = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortest >= 600;
    final theme = Theme.of(context);
    final titleColor = index == 1 ? AppTheme.textPrimary : theme.colorScheme.primary;

    final pages = const [
      HomeTab(),
      SalesTab(),
      StockTab(),
      ReportTab(),
      SettingTab(),
    ];

    const titles = [
      'Dashboard',
      'Transaksi',
      'Manajemen Stok',
      'Laporan',
      'Pengaturan',
    ];

    Future<void> startTransaction() async {
      // BE mewajibkan shift aktif untuk membuat transaksi POS.
      final ok = await ensureActiveShift(context, ref);
      if (!ok || !context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProductTransactionPage()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          titles[index],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
      ),

      body: SafeArea(
        child: Row(
          children: [
            if (isTablet)
              _Sidebar(index: index, isStockOnly: isStockOnly, onNewTransaction: startTransaction),

            Expanded(child: pages[index]),
          ],
        ),
      ),

      floatingActionButton: (isTablet || isStockOnly)
          ? null
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandBlue.withOpacity(0.33),
                    blurRadius: 22,
                    spreadRadius: 4,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: AppTheme.brandBlue,
                shape: const CircleBorder(),
                onPressed: startTransaction,
                child: const Icon(Icons.add, size: 28, color: Colors.white),
              ),
            ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: isTablet
          ? null
          : (isStockOnly ? const _StockOnlyBottomBar() : const _BottomBar()),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final int index;
  final bool isStockOnly;
  final VoidCallback onNewTransaction;
  const _Sidebar({required this.index, required this.isStockOnly, required this.onNewTransaction});

  // Posisi menu rail -> index halaman sebenarnya.
  // (index 1 = SalesTab placeholder, diakses lewat tombol transaksi baru)
  List<int> get _pageIndices => isStockOnly ? const [2, 4] : const [0, 2, 3, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _pageIndices.indexOf(index);

    final destinations = isStockOnly
        ? const [
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text("Stok"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              label: Text("Pengaturan"),
            ),
          ]
        : const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              label: Text("Beranda"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text("Stok"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.bar_chart_outlined),
              label: Text("Laporan"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              label: Text("Pengaturan"),
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                backgroundColor: AppTheme.brandGreenDark,
                indicatorColor: Colors.white.withOpacity(0.20),
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedIconTheme: const IconThemeData(color: Colors.white70),
                selectedLabelTextStyle: const TextStyle(color: Colors.white),
                unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
                selectedIndex: selected < 0 ? null : selected,
                labelType: NavigationRailLabelType.all,
                leading: isStockOnly
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FloatingActionButton(
                          heroTag: 'tabletNewTransaction',
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.brandGreenDark,
                          elevation: 0,
                          tooltip: 'Transaksi Baru',
                          onPressed: onNewTransaction,
                          child: const Icon(Icons.add, size: 28),
                        ),
                      ),
                onDestinationSelected: (value) =>
                    ref.read(dashboardIndexProvider.notifier).state = _pageIndices[value],
                destinations: destinations,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockOnlyBottomBar extends ConsumerWidget {
  const _StockOnlyBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dashboardIndexProvider);
    final onSettings = index == 4;

    return BottomAppBar(
      color: AppTheme.brandGreenDark,
      height: 70,
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.inventory_2,
              label: "Stok",
              active: !onSettings,
              onTap: () => ref.read(dashboardIndexProvider.notifier).state = 2,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings,
              label: "Pengaturan",
              active: onSettings,
              onTap: () => ref.read(dashboardIndexProvider.notifier).state = 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dashboardIndexProvider);

    return BottomAppBar(
      color: AppTheme.brandGreenDark,
      height: 70,
      shape: const CircularNotchedRectangle(),

      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.dashboard,
              label: "Beranda",
              active: index == 0,
              onTap: () => ref.read(dashboardIndexProvider.notifier).state = 0,
            ),
          ),

          Expanded(
            child: _NavItem(
              icon: Icons.inventory_2,
              label: "Stok",
              active: index == 2,
              onTap: () => ref.read(dashboardIndexProvider.notifier).state = 2,
            ),
          ),

          const SizedBox(width: 44), // ruang FAB tetap ada

          Expanded(
            child: _NavItem(
              icon: Icons.bar_chart,
              label: "Laporan",
              active: index == 3,
              onTap: () => ref.read(dashboardIndexProvider.notifier).state = 3,
            ),
          ),

          Expanded(
            child: _NavItem(
              icon: Icons.settings,
              label: "Pengaturan",
              active: index == 4,
              onTap: () => ref.read(dashboardIndexProvider.notifier).state = 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? Colors.white : Colors.white70),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
