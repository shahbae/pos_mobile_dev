import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:pos_mobile/data/models/sop_model.dart';
import 'package:pos_mobile/presentation/providers/sop_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// SOP (revisi owner 26 Nov 2026): daftar SOP dari web, urut sesuai nomor.
/// Foto dibuka layar penuh (bisa diperbesar), PDF dibuka di pembuka PDF HP.
class SopPage extends ConsumerStatefulWidget {
  const SopPage({super.key});

  @override
  ConsumerState<SopPage> createState() => _SopPageState();
}

class _SopPageState extends ConsumerState<SopPage> {
  int? _opening;

  Future<void> _open(Sop sop) async {
    if (!sop.isPdf) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SopImagePage(sop: sop)));
      return;
    }
    setState(() => _opening = sop.id);
    try {
      final path = await ref.read(sopRepositoryProvider).downloadPdf(sop);
      final result = await OpenFilex.open(path, type: 'application/pdf');
      if (mounted && result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF tersimpan, tapi tidak ada aplikasi pembuka PDF di HP ini.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sopListProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('SOP'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(sopListProvider),
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(icon: Icons.cloud_off, message: '$e', onRetry: () => ref.invalidate(sopListProvider)),
          data: (rows) => rows.isEmpty
              ? const SdmStateView(icon: Icons.menu_book_outlined, message: 'Belum ada SOP.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final s = rows[i];
                    return SdmCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _opening == null ? () => _open(s) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: s.isPdf
                                      ? Container(
                                          color: AppTheme.brandBlue.withValues(alpha: 0.08),
                                          child: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.brandBlue, size: 32),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: s.fileUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                    if (s.description.trim().isNotEmpty)
                                      Text(s.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              if (_opening == s.id)
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Foto SOP layar penuh; dicubit untuk memperbesar.
class SopImagePage extends StatelessWidget {
  final Sop sop;
  const SopImagePage({super.key, required this.sop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(sop.title, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: sop.fileUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, _, _) => const Text('Gagal memuat foto SOP', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
