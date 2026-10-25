import 'package:flutter/material.dart';

import 'package:pos_mobile/theme/app_theme.dart';

/// Potongan tampilan yang dipakai bersama halaman SDM (Jadwal Saya, Profil,
/// Yang Bertugas, Izin Keluar).

class SdmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const SdmCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: child,
    );
  }
}

class SdmPill extends StatelessWidget {
  final String text;
  final Color color;
  const SdmPill(this.text, {super.key, this.color = AppTheme.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class SdmNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;
  const SdmNote({super.key, required this.icon, required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFD97706) : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Kotak "belum ada data" di dalam daftar yang sudah bisa digulir.
class SdmEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  const SdmEmpty({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

/// Isi halaman saat memuat, gagal, atau kosong — semuanya tetap bisa ditarik
/// untuk muat ulang.
class SdmStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  const SdmStateView({super.key, required this.icon, required this.message, this.onRetry});

  static Widget loading() => ListView(children: const [
        SizedBox(height: 160),
        Center(child: CircularProgressIndicator()),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 48, color: AppTheme.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi'))),
        ],
      ],
    );
  }
}
