# Edit & Hapus Pengeluaran — Panduan FE Mobile (Flutter)

Tanggal: 2026-08-01
Target: `pos_mobile` (Flutter + dio + riverpod)
Referensi API lengkap: `docs/api-expense-edit-fe.md`

---

## TL;DR — kenapa "Error edit pengeluaran" muncul

Di BE **endpoint `PUT /expenses/:id` belum pernah ada**. Yang terdaftar cuma `POST /expenses`, `GET /expenses`, dan `GET /expenses/:id`. Jadi `repo.updateExpense()` selalu kena **404**, dan `_submit()` di `expense_form_edit_page.dart` jatuh ke `catch` → snackbar "Gagal: ...". Sama halnya dengan `deleteExpense()`.

Sekarang BE sudah menambahkan `PUT /expenses/:id` dan `DELETE /expenses/:id`.

**Yang harus diubah di mobile:** hanya **satu method** — `updateExpense()` di `lib/data/repositories/expense_repository.dart` sekarang harus mengirim **`multipart/form-data`**, bukan JSON. Kalau tetap mengirim JSON, hasilnya berubah dari `404` menjadi **`400 failed to parse form`**.

`deleteExpense()` **tidak perlu diubah sama sekali** — begitu route-nya ada, kode yang sekarang langsung jalan.

---

## 1. Perbaikan wajib: `updateExpense` → multipart

### Sebelum (rusak — kirim JSON)

```dart
Future<Map<String, dynamic>> updateExpense(int id, Map<String, dynamic> data) async {
  final res = await api.dio.put('/expenses/$id', data: data);
  return res.data;
}
```

### Sesudah (drop-in replacement)

```dart
/// Update pengeluaran — multipart/form-data, sama seperti create.
/// Partial update: hanya field di [data] yang dikirim yang diubah BE.
/// [photoPath] opsional — kalau null, foto bukti lama dipertahankan.
Future<Map<String, dynamic>> updateExpense(
  int id,
  Map<String, dynamic> data, {
  String? photoPath,
}) async {
  try {
    final map = <String, dynamic>{...data};
    if (photoPath != null) {
      final filename = photoPath.split(RegExp(r'[\\/]')).last;
      map['photo'] = await MultipartFile.fromFile(photoPath, filename: filename);
    }
    final res = await api.dio.put(
      '/expenses/$id',
      data: FormData.fromMap(map),
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data;
  } on DioException catch (e) {
    throw _mapExpenseError(e);
  }
}
```

Catatan implementasi:

- `photoPath` dibuat **named optional**, jadi pemanggilan lama `repo.updateExpense(id, payload)` tetap kompile tanpa perubahan.
- Pola `filename:` di `MultipartFile.fromFile` **wajib dipertahankan** — BE memvalidasi ekstensi dari nama file. Kalau `filename` tidak diisi, dio mengirim nama seadanya dan bisa kena `only jpg, jpeg, png, webp are allowed`.
- `FormData` hanya boleh dipakai sekali. Kalau nanti mau menambah retry otomatis, bangun ulang `FormData`-nya tiap percobaan (jangan simpan di variabel lalu kirim dua kali).

### Error mapping

`_mapCreateError` yang sudah ada tinggal dipakai ulang — rename jadi `_mapExpenseError` (dipakai create + update), lalu tambahkan dua kasus baru yang khusus muncul di update/delete:

```dart
String _mapExpenseError(DioException e) {
  final status = e.response?.statusCode;
  if (status == 404) return 'Pengeluaran tidak ditemukan atau sudah dihapus.';
  if (status == 403) return 'Pengeluaran ini milik cabang lain.';

  // ... sisanya sama persis dengan _mapCreateError yang sekarang ...
}
```

Sekalian bungkus `deleteExpense` dengan mapping yang sama, supaya `expense_detail_page.dart` tidak lagi menampilkan `Gagal hapus: DioException [bad response]...` mentah ke user:

```dart
Future<Map<String, dynamic>> deleteExpense(int id) async {
  try {
    final res = await api.dio.delete('/expenses/$id');
    return res.data;
  } on DioException catch (e) {
    throw _mapExpenseError(e);
  }
}
```

---

## 2. `expense_form_edit_page.dart` — tidak wajib diubah

Payload yang dikirim sekarang sudah cocok 1:1 dengan yang diterima BE:

```dart
final payload = {
  'amount': _amountController.text.replaceAll('.', '').replaceAll(',', ''),
  'category': _selectedCategory,
  'description': _descController.text,
  'expense_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
};
```

Semua nilainya `String`, dan BE menerima keempatnya sebagai field opsional. Karena halaman edit belum punya picker foto, `photo` tidak dikirim → **foto bukti lama otomatis dipertahankan**. Itu perilaku yang benar, tidak akan menghapus bukti.

Dua hal kecil yang layak dirapikan:

- **`description` kosong = mengosongkan keterangan.** Kalau user menghapus isi field, `''` tetap dikirim dan BE akan menyimpan string kosong. Ini memang yang diharapkan, cuma pastikan itu memang niat produknya.
- **Jangan kirim field yang tidak berubah** kalau mau lebih hemat. Opsional — mengirim semuanya juga aman karena BE menimpa dengan nilai yang sama.

Setelah sukses, halaman sudah `Navigator.pop(context, true)`. Pastikan pemanggilnya melakukan `ref.invalidate(expenseListProvider)` (dan provider detail kalau ada) supaya daftar ikut segar — `expense_detail_page.dart` sudah melakukan ini di alur delete.

---

## 3. Opsional: tambah ganti foto di halaman edit

Kalau mau user bisa mengganti bukti foto saat edit, tinggal salin pola `_pickPhoto` dari `expense_form_page.dart` (create) — validasinya identik:

```dart
static const _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};
static const _maxBytes = 2 * 1024 * 1024;

Future<void> _pickPhoto(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 80,   // penting: jaga tetap di bawah 2 MB
    maxWidth: 1600,
  );
  if (picked == null) return;

  final ext = picked.name.split('.').last.toLowerCase();
  if (!_allowedExt.contains(ext)) {
    _snack('Format foto harus JPG, PNG, atau WEBP.', error: true);
    return;
  }
  if (await picked.length() > _maxBytes) {
    _snack('Ukuran foto maksimal 2 MB.', error: true);
    return;
  }
  setState(() => _newPhoto = picked);
}
```

lalu di `_submit()`:

```dart
await repo.updateExpense(
  widget.expense.id!,
  payload,
  photoPath: _newPhoto?.path,   // null = foto lama dipertahankan
);
```

UX yang perlu diperhatikan:

- **Foto tidak bisa dihapus, hanya diganti.** Foto bukti wajib ada di BE, jadi jangan sediakan tombol "hapus foto" di halaman edit — cukup "ganti foto".
- **Tampilkan foto lama** dari `photo_url` sebagai preview awal, dan baru timpa dengan preview file lokal setelah user memilih yang baru.
- **`photo_url` berubah setelah foto diganti** (nama file di server di-generate acak), dan file lama langsung dihapus server. Jadi cache gambar tidak perlu di-invalidate manual — URL-nya sudah beda. Tapi kalau foto **tidak** diganti, `photo_url` tetap sama, jadi jangan andalkan perubahan URL sebagai penanda "data sudah ter-update".
- **iOS HEIC:** `image_picker` dengan `imageQuality` di bawah 100 sudah mengonversi ke JPEG, jadi ekstensi `.heic` tidak akan lolos ke server. Jangan set `imageQuality: 100` di halaman edit, karena selain HEIC bisa lolos, ukurannya juga gampang tembus 2 MB.

---

## 4. Hak akses & cabang

- **Role yang boleh edit/hapus: Owner, Supervisor, Finance, Leader** — persis sama dengan yang boleh create. Kalau `role_access.dart` sudah punya gate untuk tombol "Tambah Pengeluaran", pakai gate yang sama untuk tombol Edit dan Hapus.
- **Non-owner terkunci ke cabangnya sendiri.** Kalau id-nya milik cabang lain → `403 expense belongs to another branch`.
- ⚠️ **Perubahan perilaku pada `GET /expenses/:id`:** dulu endpoint ini sama sekali tidak memfilter cabang, sekarang ikut dikunci. `getExpenseDetail()` sekarang bisa mengembalikan `null` (karena `catch` menelan errornya) untuk expense cabang lain. Praktiknya tidak terpengaruh selama detail hanya dibuka dari list — dan list memang selalu sudah difilter per cabang.

---

## 5. Ringkas: tabel error → pesan user

| HTTP | `message` dari BE | Saran pesan di app |
|---|---|---|
| `400` | `invalid request` | "Data tidak valid — periksa nominal, kategori, dan tanggal." |
| `400` | `failed to parse form` | "Gagal mengunggah formulir." — kalau ini muncul saat edit, kemungkinan besar masih mengirim JSON (lihat bagian 1). |
| `400` | `photo must be ≤ 2MB` | "Ukuran foto maksimal 2 MB." |
| `400` | `only jpg, jpeg, png, webp are allowed` | "Format foto harus JPG, PNG, atau WEBP." |
| `403` | `expense belongs to another branch` | "Pengeluaran ini milik cabang lain." |
| `403` | `no branch assigned: ...` | "Akun belum di-assign ke cabang." |
| `404` | `expense not found` | "Pengeluaran tidak ditemukan atau sudah dihapus." |
| `500` | `failed to update expense` / `failed to delete expense` | "Terjadi kesalahan di server, coba lagi." |

---

## 6. Checklist QA

- [ ] Edit hanya nominal → tersimpan, foto & kategori lama tidak berubah.
- [ ] Edit hanya kategori → nominal tidak berubah.
- [ ] Edit tanpa menyentuh foto → `photo_url` di detail tetap sama dan gambarnya masih tampil (file lama tidak terhapus).
- [ ] Edit sambil ganti foto → `photo_url` berubah, foto baru tampil.
- [ ] Kirim foto > 2 MB → pesan "maksimal 2 MB", data lain tidak ikut tersimpan.
- [ ] Hapus pengeluaran → hilang dari list, buka detail via id lama → "tidak ditemukan".
- [ ] Login sebagai Leader cabang A, coba edit id milik cabang B → "milik cabang lain".
- [ ] Edit pengeluaran dari shift yang sudah tutup → tetap berhasil, dan **laporan leader per-shift tidak berpindah shift** (BE mengunci `shift_id` di waktu create).
