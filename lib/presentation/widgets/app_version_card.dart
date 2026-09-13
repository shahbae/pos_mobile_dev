import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/presentation/widgets/app_update_dialog.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Kartu "Versi Aplikasi" di tab Pengaturan.
///
/// Menjawab dua pertanyaan yang selama ini hanya bisa dijawab dengan membuka
/// halaman /download: aplikasi ini versi berapa, dan apakah ada yang lebih
/// baru. Angka dalam kurung adalah versionCode — itulah yang dibandingkan,
/// dan itu pula yang tertulis di halaman rilis.
class AppVersionCard extends ConsumerWidget {
  const AppVersionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appUpdateProvider);
    final status = async.valueOrNull;
    final checking = async.isLoading;
    final hasUpdate = status?.hasUpdate ?? false;
    final accent = hasUpdate ? AppTheme.brandBlue : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasUpdate
              ? AppTheme.brandBlue.withOpacity(0.35)
              : AppTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasUpdate ? Icons.system_update_alt : Icons.info_outline,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Versi Aplikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status == null
                          ? 'Membaca versi…'
                          : 'Terpasang ${status.installedLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusLine(status, checking),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: hasUpdate
                ? FilledButton.icon(
                    onPressed: checking
                        ? null
                        : () => showAppUpdateDialog(context, status!.latest!),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Perbarui Sekarang'),
                  )
                : OutlinedButton.icon(
                    onPressed: checking
                        ? null
                        : () => ref.read(appUpdateProvider.notifier).check(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      checking ? 'Memeriksa…' : 'Periksa Pembaruan',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(AppUpdateStatus? status, bool checking) {
    if (checking && status == null) {
      return const _Line(
        icon: Icons.hourglass_empty,
        color: AppTheme.textSecondary,
        text: 'Memeriksa versi terbaru…',
      );
    }
    if (status == null) {
      return const SizedBox.shrink();
    }
    if (status.error != null) {
      return _Line(
        icon: Icons.cloud_off_rounded,
        color: AppTheme.danger,
        text: status.error!,
      );
    }
    if (status.latest == null) {
      return const _Line(
        icon: Icons.inbox_outlined,
        color: AppTheme.textSecondary,
        text: 'Belum ada rilis yang dipublikasikan di server.',
      );
    }
    if (status.hasUpdate) {
      return _Line(
        icon: Icons.new_releases_outlined,
        color: AppTheme.brandBlue,
        text: 'Tersedia versi ${status.latest!.label} '
            '· ${status.latest!.fileSizeLabel}',
      );
    }
    return const _Line(
      icon: Icons.verified_outlined,
      color: AppTheme.brandBlue,
      text: 'Sudah memakai versi terbaru.',
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Line({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
