/// Helper promo item gratis berbasis ukuran "XL".
///
/// Aturan bisnis: item gratis hanya boleh diklaim bila SEMUA item di keranjang
/// berukuran XL, dan item gratis yang boleh dipilih pun hanya yang berukuran XL.
/// Ukuran dideteksi dari nama produk atau nama varian (mis. "XL", "M").
library;

// Token "XL" dengan batas kata agar tidak salah cocok di dalam kata lain.
final _xlPattern = RegExp(r'\bxl\b', caseSensitive: false);

/// True bila [name] mengandung token "XL" (case-insensitive).
bool nameHasXL(String? name) => name != null && _xlPattern.hasMatch(name);
