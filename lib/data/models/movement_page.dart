/// Satu halaman riwayat mutasi outlet (bahan, topping, plastik, sedotan).
class MovementPage<T> {
  final List<T> items;
  final int total;
  final bool hasMore;

  const MovementPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  /// Membaca `data` dari endpoint riwayat mutasi yang dipanggil dengan
  /// `?page&limit` → `{items, total, page, limit}`.
  ///
  /// BE sebelum paginasi mengabaikan `page` dan membalas array; bentuk itu
  /// tetap diterima sebagai satu-satunya halaman supaya aplikasi tidak kosong
  /// bila terpasang lebih dulu daripada BE-nya.
  static MovementPage<T> parse<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson, {
    required int page,
    required int limit,
  }) {
    List<T> mapRows(List raw) => raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (data is List) {
      final items = mapRows(data);
      return MovementPage(items: items, total: items.length, hasMore: false);
    }
    if (data is Map && data['items'] is List) {
      final items = mapRows(data['items'] as List);
      final total = (data['total'] as num?)?.toInt() ?? items.length;
      return MovementPage(
        items: items,
        total: total,
        hasMore: items.isNotEmpty && page * limit < total,
      );
    }
    return const MovementPage(items: [], total: 0, hasMore: false);
  }
}
