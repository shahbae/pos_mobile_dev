import 'package:flutter/material.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Tanya dulu sebelum menulis. Dipakai di semua aksi simpan, ubah, hapus, dan
/// penyesuaian stok, supaya satu ketukan keliru di layar sempit tidak langsung
/// mengubah data yang sudah masuk pembukuan.
///
/// Mengembalikan `true` hanya bila kasir menekan tombol pembenarannya; ditutup
/// dengan tombol kembali atau mengetuk di luar sama dengan membatalkan.
///
/// [danger] mewarnai tombol pembenaran merah — pakai untuk yang menghapus atau
/// tidak bisa dibatalkan.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Tidak',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(message,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel,
              style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  color: danger ? AppTheme.danger : AppTheme.brandBlue,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return result == true;
}
