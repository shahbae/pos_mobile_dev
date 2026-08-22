import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' show PosDrawer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/services/printer_prefs.dart';
import 'package:pos_mobile/data/services/thermal_printer_service.dart';

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

/// Konfigurasi printer default (tersimpan di prefs).
class PrinterConfig {
  final String? mac;
  final String? name;
  final bool autoPrint;

  /// Kirim perintah buka laci kas saat mencetak nota.
  final bool openDrawer;

  /// Pin kick laci kas: 2 (umum) atau 5.
  final int drawerPin;

  /// Printer punya pemotong kertas otomatis. Bila false, perintah potong
  /// (GS V) tidak dikirim sama sekali — lihat [ThermalPrinterService].
  final bool hasCutter;

  final bool loaded;

  const PrinterConfig({
    this.mac,
    this.name,
    this.autoPrint = true,
    this.openDrawer = false,
    this.drawerPin = 2,
    this.hasCutter = false,
    this.loaded = false,
  });

  bool get hasPrinter => mac != null && mac!.isNotEmpty;

  PosDrawer get posDrawerPin => drawerPin == 5 ? PosDrawer.pin5 : PosDrawer.pin2;

  PrinterConfig copyWith({
    String? mac,
    String? name,
    bool? autoPrint,
    bool? openDrawer,
    int? drawerPin,
    bool? hasCutter,
    bool clearPrinter = false,
  }) {
    return PrinterConfig(
      mac: clearPrinter ? null : (mac ?? this.mac),
      name: clearPrinter ? null : (name ?? this.name),
      autoPrint: autoPrint ?? this.autoPrint,
      openDrawer: openDrawer ?? this.openDrawer,
      drawerPin: drawerPin ?? this.drawerPin,
      hasCutter: hasCutter ?? this.hasCutter,
      loaded: true,
    );
  }
}

final printerConfigProvider =
    StateNotifierProvider<PrinterConfigNotifier, PrinterConfig>((ref) {
  return PrinterConfigNotifier()..load();
});

class PrinterConfigNotifier extends StateNotifier<PrinterConfig> {
  PrinterConfigNotifier() : super(const PrinterConfig());

  Future<void> load() async {
    final mac = await PrinterPrefs.getMac();
    final name = await PrinterPrefs.getName();
    final auto = await PrinterPrefs.getAutoPrint();
    final drawer = await PrinterPrefs.getOpenDrawer();
    final drawerPin = await PrinterPrefs.getDrawerPin();
    final cutter = await PrinterPrefs.getHasCutter();
    state = PrinterConfig(
      mac: mac,
      name: name,
      autoPrint: auto,
      openDrawer: drawer,
      drawerPin: drawerPin,
      hasCutter: cutter,
      loaded: true,
    );
  }

  Future<void> setDefaultPrinter(String mac, String name) async {
    await PrinterPrefs.saveDefault(mac: mac, name: name);
    state = state.copyWith(mac: mac, name: name);
  }

  Future<void> clearDefaultPrinter() async {
    await PrinterPrefs.clearDefault();
    state = state.copyWith(clearPrinter: true);
  }

  Future<void> setAutoPrint(bool value) async {
    await PrinterPrefs.setAutoPrint(value);
    state = state.copyWith(autoPrint: value);
  }

  Future<void> setOpenDrawer(bool value) async {
    await PrinterPrefs.setOpenDrawer(value);
    state = state.copyWith(openDrawer: value);
  }

  Future<void> setDrawerPin(int pin) async {
    await PrinterPrefs.setDrawerPin(pin);
    state = state.copyWith(drawerPin: pin);
  }

  Future<void> setHasCutter(bool value) async {
    await PrinterPrefs.setHasCutter(value);
    state = state.copyWith(hasCutter: value);
  }
}

enum PrinterPhase { idle, loading, scanning, connecting, printing }

class PrinterState {
  final PrinterPhase phase;
  final List<BluetoothInfo> devices;
  final String? connectedMac;
  final String? error;
  final String? message;

  const PrinterState({
    this.phase = PrinterPhase.idle,
    this.devices = const [],
    this.connectedMac,
    this.error,
    this.message,
  });

  bool get isBusy => phase != PrinterPhase.idle;

  PrinterState copyWith({
    PrinterPhase? phase,
    List<BluetoothInfo>? devices,
    String? connectedMac,
    String? error,
    String? message,
  }) {
    return PrinterState(
      phase: phase ?? this.phase,
      devices: devices ?? this.devices,
      connectedMac: connectedMac ?? this.connectedMac,
      error: error,
      message: message,
    );
  }
}

final printerProvider =
    StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier(ref.watch(thermalPrinterServiceProvider), ref);
});

class PrinterNotifier extends StateNotifier<PrinterState> {
  final ThermalPrinterService service;
  final Ref _ref;

  PrinterNotifier(this.service, this._ref) : super(const PrinterState());

  /// Muat daftar printer yang sudah dipasangkan.
  Future<void> loadDevices() async {
    state = state.copyWith(phase: PrinterPhase.scanning, error: null, message: null);
    try {
      final granted = await service.permissionGranted;
      if (!granted) {
        state = state.copyWith(
          phase: PrinterPhase.idle,
          error: 'Izin Bluetooth ditolak. Aktifkan izin di pengaturan.',
        );
        return;
      }

      final enabled = await service.bluetoothEnabled;
      if (!enabled) {
        state = state.copyWith(
          phase: PrinterPhase.idle,
          error: 'Bluetooth tidak aktif. Nyalakan Bluetooth terlebih dahulu.',
        );
        return;
      }

      final devices = await service.getPairedDevices();
      state = state.copyWith(
        phase: PrinterPhase.idle,
        devices: devices,
        message: devices.isEmpty
            ? 'Tidak ada printer terpasang. Pasangkan (pair) printer di pengaturan Bluetooth.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(phase: PrinterPhase.idle, error: 'Gagal memuat printer: $e');
    }
  }

  /// Pastikan terhubung ke printer. Bila socket nyangkut → putus lalu retry 1×.
  Future<bool> _ensureConnected(String mac, String name) async {
    final already = state.connectedMac == mac && await service.isConnected;
    if (already) return true;

    state = state.copyWith(phase: PrinterPhase.connecting, error: null, message: null);
    var connected = await service.connect(mac);
    if (!connected) {
      // Socket mungkin masih terbuka dari sesi sebelumnya — putus lalu coba lagi.
      await service.disconnect;
      await Future.delayed(const Duration(milliseconds: 400));
      connected = await service.connect(mac);
    }
    if (!connected) {
      state = state.copyWith(
        phase: PrinterPhase.idle,
        connectedMac: null,
        error: 'Gagal terhubung ke $name.',
      );
      return false;
    }
    state = state.copyWith(connectedMac: mac);
    return true;
  }

  /// Hubungkan ke printer, lalu cetak nota.
  Future<bool> connectAndPrint({
    required String mac,
    required String name,
    required Receipt receipt,
  }) async {
    try {
      if (!await _ensureConnected(mac, name)) return false;

      state = state.copyWith(phase: PrinterPhase.printing, error: null, message: null);
      final config = _ref.read(printerConfigProvider);
      final printed = await service.printReceipt(
        receipt,
        // Laci hanya dibuka untuk pembayaran tunai — non-tunai tidak ada
        // uang fisik yang masuk/keluar laci.
        openDrawer: config.openDrawer && receipt.isCashPayment,
        drawerPin: config.posDrawerPin,
        hasCutter: config.hasCutter,
      );
      state = state.copyWith(
        phase: PrinterPhase.idle,
        message: printed ? 'Nota berhasil dicetak.' : null,
        error: printed ? null : 'Gagal mencetak nota.',
      );
      return printed;
    } catch (e) {
      state = state.copyWith(phase: PrinterPhase.idle, error: 'Gagal mencetak: $e');
      return false;
    }
  }

  /// Hubungkan ke printer lalu kirim tes cetak.
  Future<bool> connectAndTest({required String mac, required String name}) async {
    try {
      if (!await _ensureConnected(mac, name)) return false;

      state = state.copyWith(phase: PrinterPhase.printing, error: null, message: null);
      final ok = await service.printTest(
        hasCutter: _ref.read(printerConfigProvider).hasCutter,
      );
      state = state.copyWith(
        phase: PrinterPhase.idle,
        message: ok ? 'Tes cetak terkirim.' : null,
        error: ok ? null : 'Gagal tes cetak.',
      );
      return ok;
    } catch (e) {
      state = state.copyWith(phase: PrinterPhase.idle, error: 'Gagal tes cetak: $e');
      return false;
    }
  }

  /// Hubungkan ke printer lalu kirim perintah buka laci kas saja.
  ///
  /// Printer selalu menerima perintah ini walau laci tidak terpasang — jadi
  /// hasil `true` berarti perintah terkirim, bukan jaminan laci terbuka.
  Future<bool> connectAndOpenDrawer({required String mac, required String name}) async {
    try {
      if (!await _ensureConnected(mac, name)) return false;

      state = state.copyWith(phase: PrinterPhase.printing, error: null, message: null);
      final pin = _ref.read(printerConfigProvider).posDrawerPin;
      final ok = await service.openCashDrawer(pin: pin);
      state = state.copyWith(
        phase: PrinterPhase.idle,
        message: ok
            ? 'Perintah buka laci terkirim. Bila laci tetap tertutup, coba pin lain.'
            : null,
        error: ok ? null : 'Gagal mengirim perintah buka laci.',
      );
      return ok;
    } catch (e) {
      state = state.copyWith(phase: PrinterPhase.idle, error: 'Gagal buka laci: $e');
      return false;
    }
  }
}
