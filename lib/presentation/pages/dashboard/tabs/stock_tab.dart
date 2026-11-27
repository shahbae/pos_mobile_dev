import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_tiles.dart';

/// Tab Stok (layout baru, revisi owner 26 Nov 2026). Urutan di [stockMenu].
class StockTab extends ConsumerWidget {
  const StockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuList(keys: stockMenu(ref.watch(menuAccessProvider)));
  }
}
