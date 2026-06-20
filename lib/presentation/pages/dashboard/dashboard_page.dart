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

/// Spesifikasi satu tab pada navigasi bawah / rail.
class _TabSpec {
  final int pageIndex; // index ke daftar `pages`
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabSpec(this.pageIndex, this.icon, this.activeIcon, this.label);
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  // Apakah role punya menu apa pun di tab Stok?
  static bool _showStockTab(String? role) {
    const stockish = {
      AppFeature.products,
      AppFeature.purchases,
      AppFeature.stockMaterial,
      AppFeature.stockTopping,
      AppFeature.stockMovements,
      AppFeature.toppingMovements,
      AppFeature.stockAudit,
      AppFeature.expenses,
    };
    return featuresForRole(role).any(stockish.contains);
  }

  static bool _showReportTab(String? role) =>
      hasFeature(role, AppFeature.reports) ||
      hasFeature(role, AppFeature.stockAlerts) ||
      hasFeature(role, AppFeature.transactions);

  /// Daftar tab yang terlihat untuk role ini (urut: Beranda, Stok, Laporan, Pengaturan).
  List<_TabSpec> _visibleTabs(String? role) {
    return [
      if (hasFeature(role, AppFeature.dashboard))
        const _TabSpec(0, Icons.dashboard_outlined, Icons.dashboard, 'Beranda'),
      if (_showStockTab(role))
        const _TabSpec(2, Icons.inventory_2_outlined, Icons.inventory_2, 'Stok'),
      if (_showReportTab(role))
        const _TabSpec(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Laporan'),
      const _TabSpec(4, Icons.settings_outlined, Icons.settings, 'Pengaturan'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    final tabs = _visibleTabs(role);
    final showFab = hasFeature(role, AppFeature.pos);

    final rawIndex = ref.watch(dashboardIndexProvider);
    // Pastikan index aktif termasuk tab yang terlihat; kalau tidak → tab pertama.
    final visibleIndices = tabs.map((t) => t.pageIndex).toSet();
    final index = visibleIndices.contains(rawIndex) ? rawIndex : tabs.first.pageIndex;

    final shortest = MediaQuery.of(context).size.shortestSide;
    // NavigationRail butuh minimal 2 destinasi; kalau cuma 1 tab, pakai bottom bar.
    final showSidebar = shortest >= 600 && tabs.length >= 2;
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
            if (showSidebar)
              _Sidebar(
                tabs: tabs,
                currentPageIndex: index,
                showNewTransaction: showFab,
                onNewTransaction: startTransaction,
              ),
            Expanded(child: pages[index]),
          ],
        ),
      ),

      floatingActionButton: (showSidebar || !showFab)
          ? null
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandBlue.withOpacity(0.33),
                    blurRadius: 22,
                    spreadRadius: 4,
                    offset: const Offset(0, 4),
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

      bottomNavigationBar: showSidebar
          ? null
          : _BottomBar(tabs: tabs, currentPageIndex: index, withFabNotch: showFab),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final List<_TabSpec> tabs;
  final int currentPageIndex;
  final bool showNewTransaction;
  final VoidCallback onNewTransaction;
  const _Sidebar({
    required this.tabs,
    required this.currentPageIndex,
    required this.showNewTransaction,
    required this.onNewTransaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = tabs.indexWhere((t) => t.pageIndex == currentPageIndex);

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
                leading: showNewTransaction
                    ? Padding(
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
                      )
                    : null,
                onDestinationSelected: (value) => ref
                    .read(dashboardIndexProvider.notifier)
                    .state = tabs[value].pageIndex,
                destinations: tabs
                    .map((t) => NavigationRailDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.activeIcon),
                          label: Text(t.label),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final List<_TabSpec> tabs;
  final int currentPageIndex;
  final bool withFabNotch;
  const _BottomBar({
    required this.tabs,
    required this.currentPageIndex,
    required this.withFabNotch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget itemFor(_TabSpec t) => Expanded(
          child: _NavItem(
            icon: t.activeIcon,
            label: t.label,
            active: currentPageIndex == t.pageIndex,
            onTap: () =>
                ref.read(dashboardIndexProvider.notifier).state = t.pageIndex,
          ),
        );

    final List<Widget> children;
    if (withFabNotch) {
      // Sisakan ruang di tengah untuk FAB POS.
      final half = (tabs.length / 2).ceil();
      children = [
        ...tabs.take(half).map(itemFor),
        const SizedBox(width: 44),
        ...tabs.skip(half).map(itemFor),
      ];
    } else {
      children = tabs.map(itemFor).toList();
    }

    return BottomAppBar(
      color: AppTheme.brandGreenDark,
      height: 70,
      shape: withFabNotch ? const CircularNotchedRectangle() : null,
      child: Row(children: children),
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
      behavior: HitTestBehavior.opaque,
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
