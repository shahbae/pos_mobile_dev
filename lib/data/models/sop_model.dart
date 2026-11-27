/// SOP (revisi owner 26 Nov 2026): foto atau PDF yang diunggah owner/SPV dari
/// web dan dibaca semua akun di app.
class Sop {
  final int id;
  final String title;
  final String description;

  /// `image` | `pdf`.
  final String fileType;
  final String fileUrl;
  final int sortOrder;

  const Sop({
    required this.id,
    required this.title,
    this.description = '',
    this.fileType = 'image',
    required this.fileUrl,
    this.sortOrder = 0,
  });

  bool get isPdf => fileType == 'pdf';

  factory Sop.fromJson(Map<String, dynamic> j) => Sop(
        id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        fileType: '${j['file_type'] ?? 'image'}',
        fileUrl: '${j['file_url'] ?? ''}',
        sortOrder: j['sort_order'] is num ? (j['sort_order'] as num).toInt() : 0,
      );
}
