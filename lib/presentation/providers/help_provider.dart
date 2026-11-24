import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/data/repositories/help_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';

final helpRepositoryProvider = Provider<HelpRepository>((ref) {
  return HelpRepository(ref.watch(apiProvider));
});

final myHelpTicketsProvider = FutureProvider.autoDispose<List<HelpTicket>>((ref) {
  return ref.watch(helpRepositoryProvider).mine();
});

final helpCategoriesProvider = FutureProvider.autoDispose<List<HelpCategory>>((ref) {
  return ref.watch(helpRepositoryProvider).categories();
});

/// Mengambil satu foto dan langsung membaca isinya ke memori (kamera atau
/// galeri). Null = dibatalkan. Dipisah jadi provider supaya tes tak butuh kamera.
typedef HelpPhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _pickHelpPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1280);
  return file?.readAsBytes();
}

final helpPhotoPickerProvider = Provider<HelpPhotoPicker>((ref) => _pickHelpPhoto);
