import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/printer_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Pengaturan perangkat cetak: pilih printer default, auto-print, tes cetak.
class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  ConsumerState<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerProvider.notifier).loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(printerConfigProvider);
    final state = ref.watch(printerProvider);

    // Snackbar untuk pesan/error koneksi & cetak.
    ref.listen(printerProvider, (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.error != null && next.error != prev?.error) {
        messenger.showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      } else if (next.message != null && next.message != prev?.message) {
        messenger.showSnackBar(SnackBar(
          content: Text(next.message!),
          backgroundColor: AppTheme.brandBlue,
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Perangkat Cetak'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Printer default ──
          _sectionLabel('Printer Default'),
          const SizedBox(height: 8),
          _defaultPrinterCard(config, state),
          const SizedBox(height: 24),

          // ── Auto-print ──
          _sectionLabel('Cetak Otomatis'),
          const SizedBox(height: 8),
          Container(
            decoration: _boxDeco(),
            child: SwitchListTile(
              value: config.autoPrint,
              activeColor: AppTheme.brandBlue,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Cetak nota otomatis setelah transaksi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                config.hasPrinter
                    ? 'Nota langsung tercetak ke printer default.'
                    : 'Pilih printer default dulu agar bisa aktif.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              onChanged: (v) => ref.read(printerConfigProvider.notifier).setAutoPrint(v),
            ),
          ),
          const SizedBox(height: 24),

          // ── Pemotong kertas ──
          _sectionLabel('Pemotong Kertas'),
          const SizedBox(height: 8),
          Container(
            decoration: _boxDeco(),
            child: SwitchListTile(
              value: config.hasCutter,
              activeColor: AppTheme.brandBlue,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Printer punya pemotong kertas otomatis',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Biarkan mati bila printer tidak memotong kertas sendiri. '
                'Menyalakannya pada printer tanpa pemotong membuat kertas '
                'keluar panjang dan kosong di bawah nota.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              onChanged: (v) => ref.read(printerConfigProvider.notifier).setHasCutter(v),
            ),
          ),
          const SizedBox(height: 24),

          // ── Laci kas ──
          _sectionLabel('Laci Kas (Cash Drawer)'),
          const SizedBox(height: 8),
          _drawerCard(config, state),
          const SizedBox(height: 24),

          // ── Daftar printer ter-pair ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Pilih Printer (ter-pair)'),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.brandBlue),
                onPressed: state.isBusy ? null : () => ref.read(printerProvider.notifier).loadDevices(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
              icon: const Icon(Icons.bluetooth, size: 18),
              label: const Text('Buka Pengaturan Bluetooth'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandBlue,
                side: const BorderSide(color: AppTheme.brandBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _deviceList(config, state),
        ],
      ),
    );
  }

  Widget _drawerCard(PrinterConfig config, PrinterState state) {
    final notifier = ref.read(printerConfigProvider.notifier);
    return Container(
      decoration: _boxDeco(),
      child: Column(
        children: [
          SwitchListTile(
            value: config.openDrawer,
            activeColor: AppTheme.brandBlue,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Buka laci otomatis saat bayar tunai',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Laci hanya terbuka untuk pembayaran tunai. Laci kas harus dicolok '
              'ke port RJ11/RJ12 di printer — printer bluetooth mini umumnya '
              'tidak punya port ini.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            onChanged: (v) => notifier.setOpenDrawer(v),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pin kick laci',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Kebanyakan laci pakai Pin 2. Ganti ke Pin 5 bila laci tidak merespons.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('Pin 2')),
                    ButtonSegment(value: 5, label: Text('Pin 5')),
                  ],
                  selected: {config.drawerPin},
                  onSelectionChanged: (s) => notifier.setDrawerPin(s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (state.isBusy || !config.hasPrinter)
                        ? null
                        : () => ref.read(printerProvider.notifier).connectAndOpenDrawer(
                              mac: config.mac!,
                              name: config.name ?? 'Printer',
                            ),
                    icon: const Icon(Icons.point_of_sale_outlined, size: 18),
                    label: Text(config.hasPrinter
                        ? 'Tes Buka Laci'
                        : 'Pilih printer default dulu'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brandBlue,
                      side: const BorderSide(color: AppTheme.brandBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultPrinterCard(PrinterConfig config, PrinterState state) {
    if (!config.hasPrinter) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _boxDeco(),
        child: const Row(
          children: [
            Icon(Icons.print_disabled_outlined, color: AppTheme.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text('Belum ada printer default. Pilih dari daftar di bawah.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDeco(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print, color: AppTheme.brandBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name ?? 'Printer',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(config.mac ?? '-',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: () => ref.read(printerConfigProvider.notifier).clearDefaultPrinter(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => ref.read(printerProvider.notifier).connectAndTest(
                        mac: config.mac!,
                        name: config.name ?? 'Printer',
                      ),
              icon: state.isBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(state.isBusy ? 'Memproses…' : 'Tes Cetak'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceList(PrinterConfig config, PrinterState state) {
    if (state.phase == PrinterPhase.scanning && state.devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _boxDeco(),
        child: const Text(
          'Tidak ada printer ter-pair. Pasangkan printer di pengaturan Bluetooth lalu tekan refresh.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: _boxDeco(),
      child: Column(
        children: state.devices.map((device) {
          final isDefault = config.mac == device.macAdress;
          return ListTile(
            leading: Icon(Icons.print, color: isDefault ? AppTheme.brandBlue : AppTheme.textSecondary),
            title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(device.macAdress, style: const TextStyle(fontSize: 12)),
            trailing: isDefault
                ? const Chip(
                    label: Text('Default', style: TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: AppTheme.brandBlue,
                    visualDensity: VisualDensity.compact,
                  )
                : const Icon(Icons.radio_button_unchecked, color: AppTheme.textSecondary),
            onTap: () => ref
                .read(printerConfigProvider.notifier)
                .setDefaultPrinter(device.macAdress, device.name),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 0.5));
  }

  BoxDecoration _boxDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      );
}
