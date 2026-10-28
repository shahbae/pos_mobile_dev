/// Jatah karyawan (Tahap 3, F7): fasilitas minum harian. Absen masuk satu
/// shift memberi saldo, ditandai lembur menambah, pesanan jatah mengurangi.
/// Saldo dihitung per tanggal WIB — lewat 00.00 sisanya hangus.

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

/// Orang yang bisa dipesankan jatah: sudah absen masuk hari ini di lokasi
/// mana pun (`GET /allowance/recipients`).
class AllowanceRecipient {
  final int userId;
  final String name;
  final int balance;
  final String locationName;

  /// Absen terakhirnya hari ini di outlet ini — ditampilkan paling atas.
  final bool atThisBranch;

  const AllowanceRecipient({
    required this.userId,
    required this.name,
    required this.balance,
    this.locationName = '',
    this.atThisBranch = false,
  });

  factory AllowanceRecipient.fromJson(Map<String, dynamic> j) => AllowanceRecipient(
        userId: _int(j['user_id']),
        name: j['name']?.toString() ?? '',
        balance: _int(j['balance']),
        locationName: j['location_name']?.toString() ?? '',
        atThisBranch: j['at_this_branch'] == true,
      );
}

/// Satu mutasi saldo jatah hari ini.
class AllowanceEntry {
  static const shift = 'shift';
  static const overtime = 'overtime';
  static const overtimeCancel = 'overtime_cancel';
  static const order = 'order';

  final String kind;

  /// Kredit positif, debit negatif.
  final int amount;
  final String? invoiceNo;
  final DateTime? createdAt;

  const AllowanceEntry({required this.kind, required this.amount, this.invoiceNo, this.createdAt});

  factory AllowanceEntry.fromJson(Map<String, dynamic> j) => AllowanceEntry(
        kind: j['kind']?.toString() ?? '',
        amount: _int(j['amount']),
        invoiceNo: j['invoice_no']?.toString(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
      );

  String get label => switch (kind) {
        shift => 'Absen masuk',
        overtime => 'Lembur',
        overtimeCancel => 'Lembur dibatalkan',
        order => 'Pesanan jatah',
        _ => kind,
      };
}

/// Saldo jatah hari ini beserta mutasinya (`GET /me/allowance`).
class MyAllowance {
  final String date;
  final int balance;
  final List<AllowanceEntry> entries;

  const MyAllowance({required this.date, required this.balance, this.entries = const []});

  factory MyAllowance.fromJson(Map<String, dynamic> j) => MyAllowance(
        date: j['date']?.toString() ?? '',
        balance: _int(j['balance']),
        entries: [
          for (final e in (j['entries'] as List? ?? const []))
            if (e is Map) AllowanceEntry.fromJson(Map<String, dynamic>.from(e)),
        ],
      );
}

class AllowanceOrderItem {
  final String name;
  final String? variantName;
  final int qty;
  final List<String> toppings;

  const AllowanceOrderItem({required this.name, this.variantName, required this.qty, this.toppings = const []});

  factory AllowanceOrderItem.fromJson(Map<String, dynamic> j) {
    final variant = j['variant_name']?.toString();
    return AllowanceOrderItem(
      name: j['name']?.toString() ?? '',
      variantName: (variant == null || variant.isEmpty) ? null : variant,
      qty: _int(j['qty']),
      toppings: [
        for (final t in (j['toppings'] as List? ?? const []))
          if (t is Map) t['name']?.toString() ?? '' else t.toString(),
      ],
    );
  }

  String get displayName => variantName == null ? name : '$name - $variantName';
}

/// Pesanan jatah yang diterima (`GET /me/allowance/orders`).
class AllowanceOrder {
  final int id;
  final String invoiceNo;
  final DateTime? createdAt;
  final String branchName;
  final String cashierName;
  final int total;
  final List<AllowanceOrderItem> items;

  const AllowanceOrder({
    required this.id,
    required this.invoiceNo,
    this.createdAt,
    this.branchName = '',
    this.cashierName = '',
    required this.total,
    this.items = const [],
  });

  factory AllowanceOrder.fromJson(Map<String, dynamic> j) => AllowanceOrder(
        id: _int(j['id']),
        invoiceNo: j['invoice_no']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal(),
        branchName: j['branch_name']?.toString() ?? '',
        cashierName: j['cashier_name']?.toString() ?? '',
        total: _int(j['total']),
        items: [
          for (final i in (j['items'] as List? ?? const []))
            if (i is Map) AllowanceOrderItem.fromJson(Map<String, dynamic>.from(i)),
        ],
      );
}
