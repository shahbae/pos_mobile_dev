import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/presentation/pages/help/help_ticket_list_page.dart';
import 'package:pos_mobile/presentation/providers/help_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _when = DateFormat('EEE d MMM, HH.mm', 'id_ID');

String _fmt(DateTime? t) => t == null ? '-' : _when.format(t.toLocal());

/// Satu tiket bantuan dengan riwayat statusnya. Juga tujuan ketukan
/// notifikasi `help.status` (`app:/help-tickets/<id>`). Tombol Tandai selesai
/// diambil dari `actions` kiriman server.
class HelpTicketDetailPage extends ConsumerStatefulWidget {
  final int ticketId;
  const HelpTicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<HelpTicketDetailPage> createState() => _HelpTicketDetailPageState();
}

class _HelpTicketDetailPageState extends ConsumerState<HelpTicketDetailPage> {
  HelpTicket? _t;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PushService.cancelTag('help-${widget.ticketId}');
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(helpRepositoryProvider).one(widget.ticketId);
      if (mounted) {
        setState(() {
          _t = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Future<HelpTicket> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(myHelpTicketsProvider);
      // Balasan aksi tidak membawa riwayat; muat ulang utuh.
      await _load();
      _snack(done);
    } catch (e) {
      _snack('$e', error: true);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final note = await showDialog<String>(context: context, builder: (_) => const _ResolveDialog());
    if (note == null) return;
    await _act(() => ref.read(helpRepositoryProvider).resolve(widget.ticketId, note: note), 'Tiket ditandai selesai.');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: Text(t == null ? 'Tiket' : 'Tiket #${t.id}'), centerTitle: true),
      body: t == null
          ? (_error == null
              ? SdmStateView.loading()
              : SdmStateView(icon: Icons.error_outline, message: '$_error', onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
                children: [
                  SdmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(t.categoryName,
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                            ),
                            SdmPill(helpStatusLabels[t.status] ?? t.status, color: helpStatusColor(t.status)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ke ${helpTargetLabels[t.target] ?? t.target} · ${t.branchName} · ${_fmt(t.createdAt)}',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text(t.description, style: const TextStyle(fontSize: 15, height: 1.4, color: AppTheme.textPrimary)),
                        if (t.photoUrl != null) ...[
                          const SizedBox(height: 12),
                          _Photo(url: t.photoUrl!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (t.dueAt != null)
                    SdmNote(
                      icon: Icons.event_outlined,
                      warning: t.overdue || t.late == true,
                      text: [
                        'Tenggat ${_fmt(t.dueAt)}',
                        if (t.approvedByName != null) 'disetujui ${t.approvedByName}',
                        if (t.overdue) 'sudah lewat',
                        if (t.late == true) 'diselesaikan terlambat',
                      ].join(' · '),
                    ),
                  if (t.status == 'rejected' && t.rejectReason != null) ...[
                    const SizedBox(height: 12),
                    SdmNote(
                      icon: Icons.block,
                      warning: true,
                      text: 'Ditolak${t.rejectedByName == null ? '' : ' oleh ${t.rejectedByName}'}: ${t.rejectReason}',
                    ),
                  ],
                  if (t.status == 'resolved') ...[
                    const SizedBox(height: 12),
                    SdmCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ditandai selesai${t.resolvedByName == null ? '' : ' oleh ${t.resolvedByName}'} · ${_fmt(t.resolvedAt)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                          ),
                          if (t.resolutionNote != null) ...[
                            const SizedBox(height: 6),
                            Text(t.resolutionNote!, style: const TextStyle(color: AppTheme.textPrimary)),
                          ],
                          if (t.resolutionPhotoUrl != null) ...[
                            const SizedBox(height: 10),
                            _Photo(url: t.resolutionPhotoUrl!),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (t.can('resolve')) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _resolve,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Tandai selesai'),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tandai kalau masalahnya sudah beres. Terlambat bila ditandai sesudah tenggat.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Riwayat',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  for (final e in t.events) _EventRow(e: e),
                ],
              ),
            ),
    );
  }
}

/// Konfirmasi tanda selesai. Memegang kontrolernya sendiri, karena kolomnya masih
/// tergambar selama animasi dialog menutup. Hasilnya keterangan; null = batal.
class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog();

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tandai selesai?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tandai kalau masalahnya sudah beres. Tiket yang selesai tidak bisa dibuka lagi.'),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Keterangan (opsional)', hintText: 'mis. Blender sudah diganti'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(context, _note.text.trim()), child: const Text('Tandai selesai')),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final HelpTicketEvent e;
  const _EventRow({required this.e});

  @override
  Widget build(BuildContext context) {
    final label = e.fromStatus.isEmpty
        ? 'Diajukan'
        : e.fromStatus == 'resolved' && e.toStatus == 'approved'
            ? 'Dibuka kembali'
            : helpStatusLabels[e.toStatus] ?? e.toStatus;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: helpStatusColor(e.toStatus), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                Text(
                  [
                    e.actorName ?? 'Sistem',
                    _fmt(e.createdAt),
                    if (e.dueAt != null) 'tenggat ${_fmt(e.dueAt)}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (e.note != null) ...[
                  const SizedBox(height: 4),
                  Text(e.note!, style: const TextStyle(color: AppTheme.textPrimary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String url;
  const _Photo({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url))),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 60,
            child: Center(child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary)),
          ),
        ),
      ),
    );
  }
}
