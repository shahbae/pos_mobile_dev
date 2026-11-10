import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/pages/reminders/reminder_detail_page.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Potongan tampilan bersama halaman KPI (Tahap 6).

final _two = NumberFormat('#,##0.##', 'id_ID');

/// Skor/poin dengan koma Indonesia, maksimal 2 desimal (kontrak: server
/// menyimpan 4, tampilkan 2). Null = belum ada angka.
String kpiNum(double? v) => v == null ? '—' : _two.format(v);

/// Poin kejadian bertanda: "−0,4", "+1,5".
String kpiPoints(double v) {
  if (v == 0) return '0';
  return '${v < 0 ? '−' : '+'}${_two.format(v.abs())}';
}

/// Pembilang & penyebut indikator modul pusat (Tahap 7), dalam kalimat:
/// "10 dari 12 minggu", "Rp 13.000.000 dari Rp 15.000.000". SPV-C1 mengirim
/// jumlah skor leader ÷ banyak leader, jadi yang ditampilkan rata-ratanya.
String kpiMeasureText(KpiMeasure m) {
  switch (m.unit) {
    case 'Rp':
      return '${formatRupiah(m.numerator)} dari ${formatRupiah(m.denominator)}';
    case 'leader':
      return 'rata-rata ${kpiNum(m.denominator > 0 ? m.numerator / m.denominator : 0)} '
          'dari ${kpiNum(m.denominator)} leader';
    default:
      return '${kpiNum(m.numerator)} dari ${kpiNum(m.denominator)}${m.unit.isEmpty ? '' : ' ${m.unit}'}';
  }
}

Color kpiPredicateColor(String predicate) => switch (predicate) {
  'Sangat Baik' => const Color(0xFF15803D),
  'Baik' => const Color(0xFF0369A1),
  'Cukup' => const Color(0xFFD97706),
  'Perlu Pembinaan' => AppTheme.danger,
  _ => AppTheme.textSecondary,
};

/// Ambil satu foto dan langsung baca ke memori. Null = batal atau gagal
/// (galat kamera sudah ditampilkan).
Future<Uint8List?> pickKpiPhoto(
  BuildContext context, {
  ImageSource source = ImageSource.camera,
  CameraDevice camera = CameraDevice.rear,
}) async {
  XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
  } catch (e) {
    if (context.mounted) _cameraFailed(context, e);
    return null;
  }
  if (file == null) return null;
  // Dibaca sekarang juga, sebelum folder cache kamera sempat dikosongkan.
  final bytes = await file.readAsBytes();
  if (bytes.length > 5 * 1024 * 1024) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto lebih dari 5 MB. Ambil ulang.'),
        backgroundColor: AppTheme.danger,
      ));
    }
    return null;
  }
  return bytes;
}

void _cameraFailed(BuildContext context, Object e) {
  final denied = isCameraPermissionError(e);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(cameraErrorMessage(e)),
    backgroundColor: AppTheme.danger,
    duration: const Duration(seconds: 6),
    action: denied
        ? SnackBarAction(label: 'Pengaturan', textColor: Colors.white, onPressed: PushService.openAppSettings)
        : null,
  ));
}

/// Pilihan kamera atau galeri (bukti setoran boleh tangkapan layar m-banking,
/// foto sanggahan boleh dari galeri).
Future<Uint8List?> pickKpiPhotoAnySource(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  return pickKpiPhoto(context, source: source);
}

void showKpiPhoto(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url))),
  );
}

/// Gambar kecil yang bisa diketuk untuk memperbesar.
class KpiThumb extends StatelessWidget {
  final String url;
  final double size;
  const KpiThumb(this.url, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showKpiPhoto(context, url),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: AppTheme.bgLight,
            child: const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Pratinjau foto yang baru diambil, dengan tombol hapus.
class KpiPhotoPreview extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback? onRemove;
  final double height;
  const KpiPhotoPreview(this.bytes, {super.key, this.onRemove, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, height: height, width: double.infinity, fit: BoxFit.cover),
        ),
        if (onRemove != null)
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus foto'),
          ),
      ],
    );
  }
}
