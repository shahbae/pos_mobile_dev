import 'package:flutter/material.dart';

import 'package:pos_mobile/presentation/providers/paged_list_notifier.dart';

/// Daftar riwayat yang memuat halaman berikutnya sendiri saat ujung daftar
/// mendekati layar. Dipakai layar riwayat mutasi (bahan, topping, plastik,
/// sedotan) dan daftar audit stok.
class PagedListView<T> extends StatelessWidget {
  final PagedListState<T> state;
  final PagedListNotifier<T> notifier;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;

  /// Kata benda untuk kaki daftar, mis. "mutasi" → "Semua 40 mutasi ...".
  final String unit;

  /// Pengganti tampilan kosong bawaan (teks [emptyText]).
  final Widget? empty;

  const PagedListView({
    super.key,
    required this.state,
    required this.notifier,
    required this.itemBuilder,
    required this.emptyText,
    required this.unit,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isFirstLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty && state.error != null) {
      return Center(
        child: _Retry(
          message: _errorText(state.error),
          onRetry: notifier.retry,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: state.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                empty ??
                    Padding(
                      padding: const EdgeInsets.only(top: 160),
                      child: Center(
                        child: Text(
                          emptyText,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
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

  /// Repository yang sudah menyiapkan pesan siap tampil melempar [String];
  /// selain itu (mis. DioException mentah) cukup pesan umum.
  static String _errorText(Object? error) =>
      error is String && error.trim().isNotEmpty
      ? error
      : 'Gagal memuat riwayat';

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
          'Semua ${state.total} $unit sudah ditampilkan',
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
