import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/profile_model.dart';
import 'package:pos_mobile/presentation/pages/allowance/my_allowance_page.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/widgets/confirm_dialog.dart';
import 'package:pos_mobile/presentation/widgets/notification_readiness_card.dart';
import 'package:pos_mobile/presentation/widgets/offline_hold.dart';
import 'package:pos_mobile/presentation/widgets/sdm_widgets.dart';
import 'package:pos_mobile/theme/app_theme.dart';

final _dateLabel = DateFormat('d MMMM yyyy', 'id_ID');

String _date(String? ymd) {
  if (ymd == null) return '-';
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : _dateLabel.format(d);
}

/// Profil sendiri (Tahap 1 SDM). Nomor HP, alamat, dan kontak darurat diubah
/// sendiri; NIK, rekening, dan tanggal kerja diubah owner atau SPV.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Profil'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(myAllowanceProvider);
        },
        child: async.when(
          loading: SdmStateView.loading,
          error: (e, _) => SdmStateView(
            icon: Icons.error_outline,
            message: '$e',
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: (p) => _ProfileForm(key: ValueKey(p.id), profile: p),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  final ProfileModel profile;
  const _ProfileForm({super.key, required this.profile});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _address = TextEditingController(text: widget.profile.address ?? '');
  late final _ecName = TextEditingController(text: widget.profile.emergencyContactName ?? '');
  late final _ecPhone = TextEditingController(text: widget.profile.emergencyContactPhone ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _ecName.dispose();
    _ecPhone.dispose();
    super.dispose();
  }

  Map<String, String> get _changes {
    final p = widget.profile;
    final out = <String, String>{};
    void diff(String key, TextEditingController c, String? before) {
      if (c.text.trim() != (before ?? '')) out[key] = c.text.trim();
    }

    diff('phone', _phone, p.phone);
    diff('address', _address, p.address);
    diff('emergency_contact_name', _ecName, p.emergencyContactName);
    diff('emergency_contact_phone', _ecPhone, p.emergencyContactPhone);
    return out;
  }

  Future<void> _save() async {
    final changes = _changes;
    if (changes.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updateMine(changes);
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      _snack('Profil tersimpan.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
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
    if (source == null || !mounted) return;
    final photo = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 75, // batas server 5 MB
      maxWidth: 1080,
    );
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updatePhoto(photo.path);
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      _snack('Foto profil diganti.');
    } catch (e) {
      if (mounted) _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.brandBlue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomInset),
          children: [
            SdmCard(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _busy ? null : _changePhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppTheme.bgLight,
                          foregroundImage: p.photoUrl == null ? null : NetworkImage(p.photoUrl!),
                          child: const Icon(Icons.person, size: 34, color: AppTheme.textSecondary),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: AppTheme.brandBlue, shape: BoxShape.circle),
                            child: const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(p.email, style: const TextStyle(color: AppTheme.textSecondary)),
                        if (p.roles.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(p.roles.join(', '),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const MyAllowanceCard(),
            const SizedBox(height: 12),
            const NotificationReadinessCard(),
            const SizedBox(height: 20),
            const _Heading('Kontak'),
            const SizedBox(height: 8),
            SdmCard(
              child: Column(
                children: [
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Nomor HP'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ecName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Kontak darurat (nama)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ecPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Kontak darurat (nomor HP)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy || _changes.isEmpty ? null : _save,
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Heading('Data kerja'),
            const SizedBox(height: 8),
            SdmCard(
              child: Column(
                children: [
                  _Row('NIK', p.nik ?? '-'),
                  _Row('Tanggal lahir', _date(p.birthDate)),
                  _Row('Mulai kerja', _date(p.joinedAt)),
                  if (p.leadBranchName != null) _Row('Cabang yang dipimpin', p.leadBranchName!),
                  _Row('Bank', p.bankName ?? '-'),
                  _Row('No. rekening', p.bankAccount ?? '-'),
                  const SizedBox(height: 8),
                  const Text('Salah? Minta owner atau SPV mengubahnya.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                      ),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Ganti password'),
            ),
          ],
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary));
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Ganti password. Server mengeluarkan semua sesi akun ini, termasuk HP ini,
/// jadi sesudahnya langsung ke layar login.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  bool _show = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_old.text.isEmpty || _new.text.isEmpty) return null;
    if (_new.text.length < 8) return 'Password baru minimal 8 karakter.';
    if (_again.text.isNotEmpty && _again.text != _new.text) return 'Ulangi password baru belum sama.';
    return null;
  }

  bool get _ready =>
      _old.text.isNotEmpty && _new.text.length >= 8 && _again.text == _new.text;

  Future<void> _submit() async {
    // Penjualan offline yang belum terkirim butuh sesi ini; ganti password
    // mengeluarkan sesi, jadi kirim dulu.
    if (!await ensureNothingUnsent(context, ref, action: 'Ganti password')) return;
    if (!mounted) return;
    final yakin = await confirmAction(
      context,
      title: 'Ganti password?',
      message: 'Semua HP yang memakai akun ini akan keluar, termasuk HP ini. '
          'Sesudahnya masuk lagi dengan password baru.',
      confirmLabel: 'Ya, ganti',
    );
    if (!yakin || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(oldPassword: _old.text, newPassword: _new.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Password diganti'),
          content: const Text('Silakan masuk lagi dengan password baru.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Masuk lagi')),
          ],
        ),
      );
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _show = !_show),
          ),
        );
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Ganti Password'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SdmCard(
            child: Column(
              children: [
                TextField(
                  controller: _old,
                  obscureText: !_show,
                  decoration: deco('Password lama'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _new,
                  obscureText: !_show,
                  decoration: deco('Password baru (minimal 8 karakter)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _again,
                  obscureText: !_show,
                  decoration: deco('Ulangi password baru'),
                  onChanged: (_) => setState(() {}),
                ),
                if (_problem != null) ...[
                  const SizedBox(height: 12),
                  Text(_problem!, style: const TextStyle(color: AppTheme.danger)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SdmNote(
            icon: Icons.info_outline,
            text: 'Sesudah password diganti, semua HP yang memakai akun ini keluar '
                'dan harus masuk lagi.',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy || !_ready ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Ganti password'),
          ),
        ],
      ),
    );
  }
}
