import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:pos_mobile/data/models/receipt_model.dart';

/// Service untuk mencetak nota ke printer thermal Bluetooth (ESC/POS).
class ThermalPrinterService {
  static final NumberFormat _money = NumberFormat.decimalPattern('id_ID');
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _timeFmt = DateFormat('HH:mm');

  static const String _logoAsset = 'lib/images/logo_estehcandi.png';

  /// Cache logo yang sudah di-decode & di-resize per lebar kertas (px)
  /// supaya tidak diproses ulang tiap cetak.
  static final Map<int, img.Image?> _logoCache = {};

  /// Muat logo dari asset, ubah ke grayscale, dan resize agar pas dengan lebar
  /// area cetak. Return null bila asset tak ada / gagal decode (nota tetap
  /// tercetak tanpa logo).
  Future<img.Image?> _loadLogo(int maxWidth) async {
    if (_logoCache.containsKey(maxWidth)) return _logoCache[maxWidth];
    img.Image? logo;
    try {
      final data = await rootBundle.load(_logoAsset);
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded != null) {
        final resized = decoded.width > maxWidth
            ? img.copyResize(decoded, width: maxWidth)
            : decoded;
        logo = img.grayscale(resized);
      }
    } catch (_) {
      logo = null;
    }
    _logoCache[maxWidth] = logo;
    return logo;
  }

  /// Lebar area cetak (px) per ukuran kertas.
  int _printWidth(PaperSize size) => size == PaperSize.mm80 ? 512 : 384;

  /// Cek izin Bluetooth (akan meminta izin runtime di Android 12+).
  Future<bool> get permissionGranted => PrintBluetoothThermal.isPermissionBluetoothGranted;

  /// Cek apakah Bluetooth aktif.
  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  /// Daftar perangkat Bluetooth yang sudah dipasangkan (paired).
  Future<List<BluetoothInfo>> getPairedDevices() => PrintBluetoothThermal.pairedBluetooths;

  /// Status koneksi saat ini.
  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<bool> connect(String mac) => PrintBluetoothThermal.connect(macPrinterAddress: mac);

  Future<bool> get disconnect => PrintBluetoothThermal.disconnect;

  /// Cetak nota ke printer yang sedang terhubung.
  ///
  /// [openDrawer] mengirim perintah kick laci kas (ESC p) di awal cetak.
  /// Hanya berfungsi bila laci dicolok ke port RJ11/RJ12 printer.
  Future<bool> printReceipt(
    Receipt receipt, {
    PaperSize paperSize = PaperSize.mm58,
    bool openDrawer = false,
    PosDrawer drawerPin = PosDrawer.pin2,
  }) async {
    final bytes = await _buildBytes(
      receipt,
      paperSize,
      openDrawer: openDrawer,
      drawerPin: drawerPin,
    );
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Kirim perintah buka laci kas saja (tanpa mencetak apa pun).
  ///
  /// Laci harus terhubung ke port cash drawer (RJ11/RJ12) di printer —
  /// printer bluetooth mini/portable umumnya tidak punya port ini.
  Future<bool> openCashDrawer({PosDrawer pin = PosDrawer.pin2}) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm58, profile);
    return PrintBluetoothThermal.writeBytes(g.drawer(pin: pin));
  }

  /// Kirim tes cetak singkat untuk verifikasi koneksi printer.
  Future<bool> printTest({PaperSize paperSize = PaperSize.mm58}) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paperSize, profile);
    List<int> bytes = [];
    bytes += g.text('TES CETAK',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += g.hr();
    bytes += g.text('Printer berhasil terhubung', styles: const PosStyles(align: PosAlign.center));
    bytes += g.text(_dateFmt.format(DateTime.now()), styles: const PosStyles(align: PosAlign.center));
    bytes += g.feed(2);
    bytes += g.cut();
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<List<int>> _buildBytes(
    Receipt r,
    PaperSize paperSize, {
    bool openDrawer = false,
    PosDrawer drawerPin = PosDrawer.pin2,
  }) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(paperSize, profile);
    List<int> bytes = [];

    // Kick laci kas dikirim paling awal agar laci terbuka bersamaan cetak.
    if (openDrawer) bytes += g.drawer(pin: drawerPin);

    // Logo di paling atas (di-center). Dilewati bila gagal dimuat.
    // Ukuran ideal ~55% lebar cetak: tidak terlalu kecil, tak melebihi awal.
    final logo = await _loadLogo((_printWidth(paperSize) * 0.55).round());
    if (logo != null) {
      // Tanpa feed agar nama cabang menempel dekat di bawah logo.
      bytes += g.image(logo, align: PosAlign.center);
    }

    // Header toko
    if (r.store.name.isNotEmpty) {
      bytes += g.text(
        r.store.name,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
    }
    bytes += g.hr(ch: '=');

    // Nomor antrean — dicetak paling atas dan besar, karena inilah satu-satunya
    // angka yang dibaca pelanggan dari jauh saat namanya dipanggil. Dilewati
    // untuk transaksi yang belum punya nomor (QRIS belum lunas, atau nota lama
    // sebelum fitur ini ada).
    if (r.hasQueueNo) {
      bytes += g.text(
        'ANTRIAN',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += g.text(
        '${r.queueNo}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += g.hr(ch: '=');
    }

    // Info transaksi
    bytes += g.text('No    : ${r.invoiceNo}');
    if (r.createdAt != null) {
      bytes += g.text('Tanggal: ${_dateFmt.format(r.createdAt!.toLocal())}');
    }
    bytes += g.text('Kasir : ${r.cashierName}');
    if (r.customerName != null) {
      bytes += g.text('Plgn  : ${r.customerName}');
    }
    bytes += g.text('Bayar : ${_paymentLabel(r.paymentMethod)}');
    bytes += g.hr();

    // Item
    for (final item in r.items) {
      bytes += g.text(item.displayName, styles: const PosStyles(bold: true));
      bytes += g.row([
        PosColumn(text: '  ${item.qty} x ${_money.format(item.price)}', width: 7),
        PosColumn(
          text: _money.format(item.lineTotal),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      // Topping per item
      for (final t in item.toppings) {
        bytes += g.row([
          PosColumn(
            text: '  + ${t.name} x${t.qty}${t.isFree ? ' (gratis)' : ''}',
            width: 8,
          ),
          PosColumn(
            text: t.isFree ? '' : _money.format(t.lineTotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    }
    bytes += g.hr();

    // Ringkasan
    bytes += _summaryRow(g, 'Subtotal', r.subtotal);
    if (r.promos.isNotEmpty) {
      for (final p in r.promos) {
        bytes += _summaryRow(g, p.name, -p.discount);
      }
    } else if (r.promoDiscount > 0) {
      bytes += _summaryRow(g, 'Diskon Promo', -r.promoDiscount);
    }
    if (r.discount > 0) bytes += _summaryRow(g, 'Diskon', -r.discount);
    if (r.tax > 0) bytes += _summaryRow(g, 'Pajak', r.tax);
    bytes += g.hr();
    // TOTAL ditonjolkan (teks lebih besar)
    bytes += g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _money.format(r.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);
    bytes += g.hr(ch: '=');

    bytes += _summaryRow(g, _paymentLabel(r.paymentMethod), r.paid);
    bytes += _summaryRow(g, 'Kembalian', r.change);
    if (r.paymentRef != null && r.paymentRef!.isNotEmpty) {
      bytes += g.text('Ref: ${r.paymentRef}');
    }

    // Estimasi siap. Dicetak sebagai jam absolut — kertas tidak ikut berjalan,
    // jadi hitung mundur tidak berguna. Tanpa estimasi barisnya dilewati.
    if (r.hasEstimate) {
      bytes += g.hr();
      bytes += g.text(
        'Estimasi siap : ${_timeFmt.format(r.estimatedReadyAt!.toLocal())}',
        styles: const PosStyles(bold: true),
      );
      // "+/-" dan bukan "±": codepage printer (CP437) memetakan ± ke karakter
      // blok, jadi simbolnya tercetak sebagai sampah.
      // "tunggu", bukan "proses": angkanya sudah termasuk antrean pesanan lain
      // di depan, bukan cuma waktu meracik pesanan ini.
      bytes += g.text('Perkiraan tunggu +/-${r.estimatedPrepMinutes} menit');
    }

    // Footer
    bytes += g.feed(1);
    final footer = r.store.footerNote.isNotEmpty
        ? r.store.footerNote
        : 'Terima kasih atas kunjungan Anda';
    bytes += g.text(footer, styles: const PosStyles(align: PosAlign.center, bold: true));
    if (r.store.complaintNote.isNotEmpty) {
      bytes += g.text(r.store.complaintNote,
          styles: const PosStyles(align: PosAlign.center));
    }
    bytes += g.feed(1);
    bytes += g.cut();

    return bytes;
  }

  List<int> _summaryRow(Generator g, String label, num value, {bool bold = false}) {
    final style = PosStyles(bold: bold);
    return g.row([
      PosColumn(text: label, width: 7, styles: style),
      PosColumn(
        text: _money.format(value),
        width: 5,
        styles: PosStyles(align: PosAlign.right, bold: bold),
      ),
    ]);
  }

  static String _paymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'transfer':
      case 'bank_transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      case 'debit':
        return 'Debit';
      case 'credit':
        return 'Kredit';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method.isEmpty ? 'Bayar' : method.toUpperCase();
    }
  }
}
