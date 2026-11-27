import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/widgets/offline_banner.dart';
import 'package:pos_mobile/presentation/widgets/pending_reminder_banner.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';
import 'package:pos_mobile/presentation/providers/duty_provider.dart';

import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_tiles.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/home_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/sales_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/stock_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/report_tab.dart';
import 'package:pos_mobile/presentation/pages/dashboard/tabs/profile_tab.dart';
import 'package:pos_mobile/presentation/pages/product_transactions/product_transaction_page.dart';
import 'package:pos_mobile/presentation/pages/settings/setting_page.dart';
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

/// Layout baru app kasir (revisi owner 26 Nov 2026): navigasi bawah Beranda ·
/// Stok · (+) · Laporan · Profil, Setting lewat ikon gir di kanan atas. Di
/// tablet navigasinya rail samping dengan urutan yang sama.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  /// Tab yang terlihat hari ini (urut: Beranda, Stok, Laporan, Profil). Stok &
  /// Laporan hanya tampil bila ada menu di dalamnya; Profil selalu ada.
  List<_TabSpec> _visibleTabs(MenuAccess access) {
    return [
      if (access.today.contains(AppFeature.dashboard))
        const _TabSpec(0, Icons.dashboard_outlined, Icons.dashboard, 'Beranda'),
      if (stockMenu(access).isNotEmpty)
        const _TabSpec(2, Icons.inventory_2_outlined, Icons.inventory_2, 'Stok'),
      if (reportMenu(access).isNotEmpty)
        const _TabSpec(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Laporan'),
      const _TabSpec(4, Icons.person_outline, Icons.person, 'Profil'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fitur role, dikurangi menu kasir untuk karyawan yang hari ini bertugas
    // penyaji saja (Tahap 1 SDM).
    final features = ref.watch(todayFeaturesProvider);
    final tabs = _visibleTabs(ref.watch(menuAccessProvider));
    final showFab = features.contains(AppFeature.pos);
    // Spanduk penjualan offline mengikuti role, bukan tugas hari ini: antrean
    // di HP ini tetap harus terlihat walau hari ini ia bertugas penyaji.
    final showOfflineBanner = hasFeature(ref.watch(authProvider).role, AppFeature.pos);

    final rawIndex = ref.watch(dashboardIndexProvider);
    // Pastikan index aktif termasuk tab yang terlihat; kalau tidak → tab pertama.
    final visibleIndices = tabs.map((t) => t.pageIndex).toSet();
    final index = visibleIndices.contains(rawIndex) ? rawIndex : tabs.first.pageIndex;

    final shortest = MediaQuery.of(context).size.shortestSide;
    // NavigationRail butuh minimal 2 destinasi; kalau cuma 1 tab, pakai bottom bar.
    final showSidebar = shortest >= 600 && tabs.length >= 2;
    final theme = Theme.of(context);

    final pages = const [
      HomeTab(),
      SalesTab(),
      StockTab(),
      ReportTab(),
      ProfileTab(),
    ];

    const titles = [
      'Dashboard',
      'Transaksi',
      'Stok',
      'Laporan',
      'Profil',
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
        // Pita hijau muda dengan judul hijau (gambar owner).
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          titles[index],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: const [_SettingAction()],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // Selalu terlihat di semua tab: selama spanduk ini ada, masih ada
            // penjualan yang hanya tersimpan di HP ini.
            if (showOfflineBanner) const OfflineBanner(),
            // Reminder yang belum dibalas, di semua tab (Tahap 4).
            const PendingReminderBanner(),
            Expanded(
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

/// Ikon gir + tulisan "Setting" di kanan atas semua tab.
class _SettingAction extends StatelessWidget {
  const _SettingAction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkResponse(
        radius: 32,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingPage())),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, color: AppTheme.brandGreenDark, size: 24),
              Text('Setting', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.brandGreenDark)),
            ],
          ),
        ),
      ),
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

    final Widget content;
    if (withFabNotch) {
      // FAB POS di tengah. Bagi tab jadi dua sisi dengan lebar SAMA (masing-masing
      // Expanded) supaya celah notch benar-benar di tengah, berapapun jumlah tab.
      final half = (tabs.length / 2).ceil();
      final left = tabs.take(half).toList();
      final right = tabs.skip(half).toList();
      content = Row(
        children: [
          Expanded(child: Row(children: left.map(itemFor).toList())),
          const SizedBox(width: 56), // ruang FAB
          Expanded(child: Row(children: right.map(itemFor).toList())),
        ],
      );
    } else {
      content = Row(children: tabs.map(itemFor).toList());
    }

    return BottomAppBar(
      color: AppTheme.brandGreenDark,
      height: 70,
      padding: EdgeInsets.zero,
      notchMargin: 8,
      shape: withFabNotch ? const CircularNotchedRectangle() : null,
      child: content,
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
