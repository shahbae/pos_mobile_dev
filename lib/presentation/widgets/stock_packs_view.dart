import 'package:flutter/material.dart';

import 'package:pos_mobile/data/models/stock_pack_model.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Menampilkan konversi kemasan (packs[]) sebuah item stok sebagai baris chip,
/// mis. "2 Pack + 400 gram". Kosong bila item tak punya template kemasan.
class StockPacksView extends StatelessWidget {
  final List<StockPack> packs;
  final String unit;

  const StockPacksView({super.key, required this.packs, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (packs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final p in packs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                p.summary(unit),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
