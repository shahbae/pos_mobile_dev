import 'package:flutter/material.dart';

import 'package:pos_mobile/theme/app_theme.dart';

/// Kartu menu tab Stok, Laporan, Profil, halaman Tugas setiap hari, dan
/// Setting (layout baru, revisi owner 26 Nov 2026): ikon putih dalam lingkaran
/// hijau tua, judul tebal, keterangan abu satu baris. [onTap] null membuatnya
/// redup dan tidak bisa diketuk.
class SettingMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  /// Warna lingkaran ikon.
  final Color color;

  /// Null = kartu nonaktif (redup, tidak bisa diketuk).
  final VoidCallback? onTap;

  /// Jumlah hal yang menunggu ditindak di balik menu ini. Nol berarti tidak
  /// ada penanda sama sekali — lencana yang selalu tampil berhenti dibaca.
  final int badge;

  /// Nilai ringkas di kanan (mis. saldo jatah minum).
  final Widget? trailing;

  const SettingMenuCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = AppTheme.brandGreenDark,
    this.onTap,
    this.badge = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (badge > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
