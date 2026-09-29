import 'package:flutter/material.dart';

import 'package:pos_mobile/presentation/providers/movement_list_notifier.dart';

/// Daftar riwayat mutasi yang memuat halaman berikutnya sendiri saat ujung
/// daftar mendekati layar. Dipakai layar riwayat bahan, topping, plastik, dan
/// sedotan.
class PagedMovementList<T> extends StatelessWidget {
  final MovementListState<T> state;
  final MovementListNotifier<T> notifier;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;

  const PagedMovementList({
    super.key,
    required this.state,
    required this.notifier,
    required this.itemBuilder,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isFirstLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty && state.error != null) {
      return Center(
        child: _Retry(message: 'Gagal memuat riwayat', onRetry: notifier.retry),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: state.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 160),
                Center(
                  child: Text(
                    emptyText,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i < state.items.length) {
                  return itemBuilder(context, state.items[i]);
                }
                return _footer(context);
              },
            ),
    );
  }

  Widget _footer(BuildContext context) {
    if (state.error != null) {
      return _Retry(message: 'Gagal memuat lanjutan', onRetry: notifier.retry);
    }
    if (state.hasMore) {
      // Kaki daftar baru dibangun ketika mendekati layar — saat itulah halaman
      // berikutnya diminta. Notifier menolak panggilan ganda selama memuat.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.loadMore());
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          'Semua ${state.total} mutasi sudah ditampilkan',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _Retry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
