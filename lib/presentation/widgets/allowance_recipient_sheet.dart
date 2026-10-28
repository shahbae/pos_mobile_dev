import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/allowance_model.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

/// Pilih siapa yang menerima pesanan jatah. Yang absen di outlet ini tampil
/// langsung; yang absen di lokasi lain (mis. orang gudang yang mampir) muncul
/// lewat pencarian. Daftar dan saldonya dimuat ulang tiap lembar ini dibuka.
Future<AllowanceRecipient?> showAllowanceRecipientPicker(BuildContext context) {
  return showModalBottomSheet<AllowanceRecipient>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _RecipientSheet(),
  );
}

class _RecipientSheet extends ConsumerStatefulWidget {
  const _RecipientSheet();

  @override
  ConsumerState<_RecipientSheet> createState() => _RecipientSheetState();
}

class _RecipientSheetState extends ConsumerState<_RecipientSheet> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Saldo berubah oleh kasir lain: jangan pakai jawaban lama.
    Future.microtask(() {
      if (mounted) ref.invalidate(allowanceRecipientsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allowanceRecipientsProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Penerima Jatah", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                        "Yang sudah absen masuk hari ini. Saldo hangus tiap 00.00.",
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: "Cari nama (termasuk dari lokasi lain)...",
                    prefixIcon: const Icon(Icons.search, color: AppTheme.brandBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.toString(), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => ref.invalidate(allowanceRecipientsProvider),
                            child: const Text("Coba lagi"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (all) => _list(all, scrollController),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _list(List<AllowanceRecipient> all, ScrollController controller) {
    final keyword = _search.trim().toLowerCase();
    // Tanpa pencarian hanya yang absen di sini; dengan pencarian, semua yang
    // cocok — orang outlet ini tetap di atas.
    final shown = all
        .where((r) => keyword.isEmpty ? r.atThisBranch : r.name.toLowerCase().contains(keyword))
        .toList();
    final elsewhere = all.where((r) => !r.atThisBranch).length;
    if (shown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            keyword.isNotEmpty
                ? "Tidak ada yang cocok. Hanya yang sudah absen masuk hari ini yang punya jatah."
                : elsewhere > 0
                    ? "Belum ada yang absen di outlet ini. Cari nama untuk $elsewhere orang di lokasi lain."
                    : "Belum ada yang absen masuk hari ini, jadi belum ada yang punya jatah.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: shown.length + (keyword.isEmpty && elsewhere > 0 ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
      itemBuilder: (context, i) {
        if (i == shown.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text("+ $elsewhere orang absen di lokasi lain — cari namanya.",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          );
        }
        final r = shown[i];
        final empty = r.balance <= 0;
        return ListTile(
          enabled: !empty,
          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(r.atThisBranch ? "Absen di sini" : "Absen di ${r.locationName}"),
          trailing: Text(
            empty ? "Habis" : formatRupiah(r.balance),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: empty ? AppTheme.textSecondary : AppTheme.brandBlue,
            ),
          ),
          onTap: empty ? null : () => Navigator.pop(context, r),
        );
      },
    );
  }
}
