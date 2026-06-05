import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/services/thermal_printer_service.dart';

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

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
  return PrinterNotifier(ref.watch(thermalPrinterServiceProvider));
});

class PrinterNotifier extends StateNotifier<PrinterState> {
  final ThermalPrinterService service;

  PrinterNotifier(this.service) : super(const PrinterState());

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

  /// Hubungkan ke printer, lalu cetak nota.
  Future<bool> connectAndPrint(BluetoothInfo device, Receipt receipt) async {
    try {
      // Hubungkan jika belum terhubung ke perangkat yang dipilih.
      final alreadyConnected =
          state.connectedMac == device.macAdress && await service.isConnected;
      if (!alreadyConnected) {
        state = state.copyWith(phase: PrinterPhase.connecting, error: null, message: null);
        final connected = await service.connect(device.macAdress);
        if (!connected) {
          state = state.copyWith(
            phase: PrinterPhase.idle,
            connectedMac: null,
            error: 'Gagal terhubung ke ${device.name}.',
          );
          return false;
        }
        state = state.copyWith(connectedMac: device.macAdress);
      }

      state = state.copyWith(phase: PrinterPhase.printing, error: null, message: null);
      final printed = await service.printReceipt(receipt);
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
}
