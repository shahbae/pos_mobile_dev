import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/utils/location_helper.dart';
import 'package:pos_mobile/data/models/branch_model.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/repositories/kpi_repository.dart';
import 'package:pos_mobile/presentation/pages/kpi/kpi_widgets.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _ymd = DateFormat('yyyy-MM-dd');
final _dayHm = DateFormat('EEE d MMM, HH.mm', 'id_ID');

/// Lokasi yang lebih tua dari ini diambil ulang saat kirim: SPV bisa
/// berpindah selama mengisi 29 butir.
const _kFreshLocation = Duration(minutes: 10);

/// Batas badan kiriman di server 30 MB; disisakan untuk isian teks.
const _kMaxUploadBytes = 28 * 1024 * 1024;

class _Answer {
  bool? passed;
  String note = '';
  Uint8List? photo;
}

/// Sidak satu outlet: pilih outlet → cek lokasi → foto SPV → checklist →
/// kirim. Jarak dicek di HP dulu supaya SPV tidak mengisi checklist lalu
/// ditolak; server tetap menghitung ulang dari koordinat cabang.
class InspectionFormPage extends ConsumerStatefulWidget {
  const InspectionFormPage({super.key});

  @override
  ConsumerState<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends ConsumerState<InspectionFormPage> {
  BranchModel? _branch;
  Position? _pos;
  DateTime? _posAt;
  bool _locating = false;
  String? _locError;
  Uint8List? _selfie;
  final _answers = <int, _Answer>{};
  final _notes = TextEditingController();
  final _followUp = TextEditingController();
  List<Inspection>? _thisWeek;
  bool _busy = false;
  String _busyText = '';

  @override
  void dispose() {
    _notes.dispose();
    _followUp.dispose();
    super.dispose();
  }

  _Answer _a(int itemId) => _answers.putIfAbsent(itemId, _Answer.new);

  double? get _distance {
    final b = _branch, p = _pos;
    if (b == null || p == null || !b.hasGeo) return null;
    return Geolocator.distanceBetween(b.latitude!, b.longitude!, p.latitude, p.longitude);
  }

  bool get _inRadius {
    final d = _distance;
    return d != null && d <= _branch!.attendanceRadius;
  }

  Future<void> _selectBranch(BranchModel? b) async {
    setState(() {
      _branch = b;
      _thisWeek = null;
    });
    if (b == null) return;
    final monday = weekStartOf(DateTime.now());
    try {
      final rows = await ref.read(kpiRepositoryProvider).inspections(
            branchId: b.id,
            from: _ymd.format(monday),
            to: _ymd.format(monday.add(const Duration(days: 6))),
          );
      if (mounted && _branch?.id == b.id) setState(() => _thisWeek = rows);
    } catch (_) {
      // Hanya pemberitahuan; server tetap menandai sidak kedua tanpa nilai.
    }
  }

  Future<Position?> _locate() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final p = await LocationHelper.getCurrentPosition();
      if (mounted) {
        setState(() {
          _pos = p;
          _posAt = DateTime.now();
        });
      }
      return p;
    } catch (e) {
      if (mounted) setState(() => _locError = '$e');
      return null;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _takeSelfie() async {
    final b = await pickKpiPhoto(context, camera: CameraDevice.front);
    if (b != null && mounted) setState(() => _selfie = b);
  }

  Future<void> _takeFinding(int itemId) async {
    final b = await pickKpiPhoto(context);
    if (b != null && mounted) setState(() => _a(itemId).photo = b);
  }

  Future<void> _submit(List<InspectionItem> items) async {
    final failed = items.where((i) => _answers[i.id]?.passed == false && i.group != 'info').length;
    final size = (_selfie?.length ?? 0) + _answers.values.fold<int>(0, (s, a) => s + (a.photo?.length ?? 0));
    if (size > _kMaxUploadBytes) {
      _snack('Total foto lebih dari 28 MB. Hapus beberapa foto temuan.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kirim sidak?'),
        content: Text(
          '${_branch!.name}: ${failed == 0 ? 'semua butir sesuai' : '$failed butir tidak sesuai'}.'
          '${(_thisWeek?.isNotEmpty ?? false) ? '\n\nSudah ada sidak di outlet ini minggu ini, jadi sidak ini tersimpan tanpa nilai.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa lagi')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _busyText = 'Mengambil lokasi…';
    });
    var pos = _pos;
    if (pos == null || _posAt == null || DateTime.now().difference(_posAt!) > _kFreshLocation) {
      pos = await _locate();
    }
    if (pos == null || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() => _busyText = 'Mengirim sidak…');
    try {
      final done = await ref.read(kpiRepositoryProvider).createInspection(
            branchId: _branch!.id,
            latitude: pos.latitude,
            longitude: pos.longitude,
            inspectorPhoto: _selfie!,
            notes: _notes.text.trim(),
            followUp: _followUp.text.trim(),
            answers: [
              for (final i in items)
                InspectionAnswer(
                  itemId: i.id,
                  passed: _answers[i.id]!.passed!,
                  note: _answers[i.id]!.note.trim(),
                  photo: _answers[i.id]!.passed! ? null : _answers[i.id]!.photo,
                ),
            ],
          );
      if (!mounted) return;
      _snack(done.scored ? 'Sidak terkirim.' : 'Sidak terkirim, tanpa nilai (bukan sidak pertama minggu ini).');
      Navigator.pop<Inspection>(context, done);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e is KpiApiError ? e.message : '$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
      duration: Duration(seconds: error ? 6 : 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(branchListProvider);
    final itemsAsync = ref.watch(inspectionItemsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final items = itemsAsync.valueOrNull ?? const <InspectionItem>[];
    final answered = items.where((i) => _answers[i.id]?.passed != null).length;
    final geoOk = _branch != null && _branch!.hasGeo && _pos != null && _inRadius;
    final ready = geoOk && _selfie != null && items.isNotEmpty && answered == items.length;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(title: const Text('Sidak Outlet'), centerTitle: true),
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
              children: [
                _Step(
                  number: 1,
                  title: 'Outlet',
                  child: branches.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.danger)),
                    data: (list) {
                      final active = [for (final b in list) if (b.status != 'disabled') b];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: _branch?.id,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Pilih outlet'),
                            items: [for (final b in active) DropdownMenuItem(value: b.id, child: Text(b.name))],
                            onChanged: _busy
                                ? null
                                : (id) => _selectBranch(active.where((b) => b.id == id).firstOrNull),
                          ),
                          if (_branch != null && !_branch!.hasGeo) ...[
                            const SizedBox(height: 8),
                            const SdmNote(
                              icon: Icons.location_off_outlined,
                              warning: true,
                              text: 'Koordinat outlet ini belum diatur. Atur dulu di master cabang (web admin).',
                            ),
                          ],
                          if (_thisWeek?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            SdmNote(
                              icon: Icons.info_outline,
                              warning: true,
                              text: 'Sudah ada sidak minggu ini (${_thisWeek!.first.inspectorName}'
                                  '${_thisWeek!.first.at == null ? '' : ', ${_dayHm.format(_thisWeek!.first.at!.toLocal())}'}). '
                                  'Sidak ini tetap tersimpan, tapi tidak dinilai.',
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 2,
                  title: 'Lokasi',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_distance != null)
                        Text(
                          _inRadius
                              ? '${_distance!.round()} m dari outlet (radius ${_branch!.attendanceRadius} m)'
                              : '${_distance!.round()} m dari outlet, di luar radius ${_branch!.attendanceRadius} m',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _inRadius ? const Color(0xFF15803D) : AppTheme.danger,
                          ),
                        )
                      else if (_pos != null)
                        const Text('Lokasi didapat.', style: TextStyle(color: AppTheme.textSecondary)),
                      if (_locError != null) Text(_locError!, style: const TextStyle(color: AppTheme.danger)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy || _locating || _branch == null ? null : _locate,
                          icon: _locating
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(_locating
                              ? 'Mendeteksi lokasi…'
                              : _pos == null
                                  ? 'Cek lokasi'
                                  : 'Cek ulang lokasi'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 3,
                  title: 'Foto SPV di outlet',
                  child: _selfie != null
                      ? KpiPhotoPreview(_selfie!, height: 160, onRemove: _busy ? null : () => setState(() => _selfie = null))
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _takeSelfie,
                            icon: const Icon(Icons.photo_camera_front_outlined, size: 18),
                            label: const Text('Ambil foto'),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 4,
                  title: 'Checklist ($answered/${items.length})',
                  child: itemsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.danger)),
                    data: (list) => list.isEmpty
                        ? const Text('Belum ada butir sidak aktif.', style: TextStyle(color: AppTheme.textSecondary))
                        : _Checklist(
                            items: list,
                            answerOf: _a,
                            enabled: !_busy,
                            onChanged: () => setState(() {}),
                            onPhoto: _takeFinding,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _Step(
                  number: 5,
                  title: 'Catatan',
                  child: Column(
                    children: [
                      TextField(
                        controller: _notes,
                        enabled: !_busy,
                        maxLines: 3,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Catatan sidak (opsional)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _followUp,
                        enabled: !_busy,
                        maxLines: 3,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Tindak lanjut (opsional)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!ready && !_busy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _branch == null
                          ? 'Pilih outlet dulu.'
                          : !_branch!.hasGeo
                              ? 'Koordinat outlet belum diatur.'
                              : _pos == null
                                  ? 'Cek lokasi dulu.'
                                  : !_inRadius
                                      ? 'Lokasi di luar radius outlet.'
                                      : _selfie == null
                                          ? 'Ambil foto SPV dulu.'
                                          : 'Jawab semua butir checklist (${items.length - answered} lagi).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _busy || !ready ? null : () => _submit(items),
                  child: const Text('Kirim sidak'),
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(_busyText),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final Widget child;
  const _Step({required this.number, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SdmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $title', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  final List<InspectionItem> items;
  final _Answer Function(int) answerOf;
  final bool enabled;
  final VoidCallback onChanged;
  final void Function(int itemId) onPhoto;

  const _Checklist({
    required this.items,
    required this.answerOf,
    required this.enabled,
    required this.onChanged,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<InspectionItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.group, () => []).add(i);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups.keys) ...[
          Row(
            children: [
              Expanded(
                child: Text(inspectionGroupLabels[g] ?? g,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
              ),
              TextButton(
                onPressed: !enabled
                    ? null
                    : () {
                        for (final i in groups[g]!) {
                          answerOf(i.id).passed ??= true;
                        }
                        onChanged();
                      },
                child: const Text('Sisanya sesuai'),
              ),
            ],
          ),
          for (final i in groups[g]!)
            _ItemTile(
              key: ValueKey(i.id),
              item: i,
              answer: answerOf(i.id),
              enabled: enabled,
              onChanged: onChanged,
              onPhoto: () => onPhoto(i.id),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final InspectionItem item;
  final _Answer answer;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onPhoto;

  const _ItemTile({
    super.key,
    required this.item,
    required this.answer,
    required this.enabled,
    required this.onChanged,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final a = answer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name, style: const TextStyle(color: AppTheme.textPrimary))),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Sesuai'),
                selected: a.passed == true,
                visualDensity: VisualDensity.compact,
                selectedColor: const Color(0xFF15803D).withValues(alpha: 0.18),
                onSelected: !enabled
                    ? null
                    : (_) {
                        a.passed = true;
                        onChanged();
                      },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Tidak'),
                selected: a.passed == false,
                visualDensity: VisualDensity.compact,
                selectedColor: AppTheme.danger.withValues(alpha: 0.18),
                onSelected: !enabled
                    ? null
                    : (_) {
                        a.passed = false;
                        onChanged();
                      },
              ),
            ],
          ),
          if (a.passed == false) ...[
            const SizedBox(height: 6),
            TextFormField(
              initialValue: a.note,
              enabled: enabled,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Temuan (opsional)', isDense: true),
              onChanged: (v) => a.note = v,
            ),
            if (a.photo != null)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(a.photo!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: !enabled
                        ? null
                        : () {
                            a.photo = null;
                            onChanged();
                          },
                    child: const Text('Hapus foto'),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: enabled ? onPhoto : null,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Foto temuan (opsional)'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
