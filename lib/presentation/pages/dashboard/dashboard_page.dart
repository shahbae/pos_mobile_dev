import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/stock_tab.dart';

import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';

import 'package:pos_mobile/presentation/pages/dashboard/tabs/home_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/sales_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/report_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/setting_tab.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/product_transaction_page.dart';
import 'package:pos_mobile/presentation/pages/service_transactions/service_transaction_page.dart';
import 'package:pos_mobile/presentation/providers/tenant_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dashboardIndexProvider);
    final tenantAsync = ref.watch(tenantProvider);
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
            if (isTablet) _Sidebar(index: index),

            Expanded(child: pages[index]),
          ],
        ),
      ),

      floatingActionButton: isTablet
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
                onPressed: () {
                  final businessType = tenantAsync.valueOrNull?.businessType;

                  if (businessType == 'laundry') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceTransactionPage(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductTransactionPage(),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.add, size: 28, color: Colors.white),
              ),
            ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: isTablet ? null : const _BottomBar(),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final int index;
  const _Sidebar({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      backgroundColor: AppTheme.brandGreenDark,
      indicatorColor: Colors.white.withOpacity(0.20),
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme: const IconThemeData(color: Colors.white70),
      selectedLabelTextStyle: const TextStyle(color: Colors.white),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
      selectedIndex: index,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (value) =>
          ref.read(dashboardIndexProvider.notifier).state = value,
      destinations: const [
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
      ],
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
