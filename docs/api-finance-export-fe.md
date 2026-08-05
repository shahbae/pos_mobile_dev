# FE — Export Excel Laporan Keuangan (`.xlsx`)

**Status:** endpoint baru, sudah ada di backend. Tidak ada breaking change pada endpoint lain.

File Excel **di-generate penuh oleh backend**. FE tidak perlu SheetJS/exceljs/`excel` package, tidak perlu menyusun sheet, tidak perlu menghitung ulang apa pun — cukup download lalu simpan/buka filenya. Angkanya berasal dari service yang sama dengan endpoint laporan JSON (`/reports/ledger`, `/reports/profit`, dst), jadi isi Excel dijamin sama dengan yang tampil di dashboard.

---

## 1. Endpoint

```
GET /reports/finance/export?from=YYYY-MM-DD&to=YYYY-MM-DD&branch_id=<id|all>
Authorization: Bearer <access_token>
```

**Akses:** `owner`, `supervisor`, `finance`. Role lain → `403 forbidden`.

**Query params:**

| Param | Wajib | Default | Keterangan |
|---|---|---|---|
| `from` | Tidak | Tanggal 1 bulan berjalan | Format `YYYY-MM-DD`. |
| `to` | Tidak | Hari ini | Format `YYYY-MM-DD`, **inklusif** (data tanggal itu ikut). |
| `branch_id` | Tidak | Cabang aktif di token | **Hanya dibaca untuk owner & supervisor.** Isi `all` untuk konsolidasi semua cabang. Finance selalu terkunci ke cabangnya sendiri — parameter ini diabaikan. |

**Response sukses `200`:**

```
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="laporan-keuangan_cabang-pusat_2026-08-01_2026-08-31.xlsx"
Cache-Control: no-store
X-Content-Type-Options: nosniff

<binary .xlsx>
```

Body adalah **binary**, bukan JSON. Jangan panggil `.json()` di response ini.

---

## 2. Isi workbook

9 sheet, urutannya tetap:

| # | Sheet | Isi |
|---|---|---|
| 1 | **Ringkasan** | Identitas file (cabang, periode, dibuat oleh, waktu, metode COGS) + Pendapatan, COGS, Laba Kotor, Biaya Operasional, Laba Operasional, Rekonsiliasi Kas, Pembelian vs COGS, Kerugian Stok. Kalau konsolidasi (`branch_id=all`), ada tabel ringkasan per cabang di bawahnya. |
| 2 | **Laba Rugi** | Pendapatan, COGS, Laba Kotor, Pengeluaran, Laba Bersih, Margin Kotor. |
| 3 | **Metode Pembayaran** | Per metode: jumlah transaksi, total dibayar, total kembalian, + baris TOTAL. |
| 4 | **Penjualan** | Rincian per transaksi POS: tanggal, no. invoice, cabang, metode bayar, kasir, total. |
| 5 | **Pengeluaran** | Rincian: tanggal, cabang, kategori, keterangan, dibuat oleh, jumlah. |
| 6 | **Pembelian** | Rincian: tanggal, cabang, supplier, catatan, dibuat oleh, total. |
| 7 | **Pembelian per Supplier** | Total order & nilai, breakdown bahan vs topping, lalu tabel per supplier. |
| 8 | **Produk Terlaris** | Produk, varian, SKU, qty terjual, pendapatan, + TOTAL. |
| 9 | **Topping Terlaris** | Topping, qty dipesan, pendapatan, + TOTAL. |

Catatan isi:
- Nominal ditulis sebagai **angka**, bukan teks — finance bisa langsung `SUM`, filter, dan pivot. Format tampilan `#,##0.00`, angka negatif merah.
- Tanggal ditulis sebagai **date cell** dalam WIB, format `dd/mm/yyyy hh:mm`.
- Sheet rincian (4, 5, 6) punya **header beku** (freeze pane) dan diakhiri baris TOTAL + jumlah baris.
- Sheet 8 & 9 hanya memuat item yang **terjual** dalam rentang itu. Produk/topping yang nol penjualan tidak diikutkan — beda dengan `GET /reports/top-products` & `/reports/top-toppings` yang selalu menambahkan item tak laku di baris bawah dengan qty 0.

---

## 3. Cara download

### 3.1 Web FE (fetch + blob)

Perlu `fetch`, bukan `<a href>` biasa, karena endpoint butuh header `Authorization`.

```js
async function downloadFinanceReport({ from, to, branchId }) {
  const params = new URLSearchParams({ from, to });
  if (branchId) params.set("branch_id", String(branchId));

  const res = await fetch(`${API_BASE}/reports/finance/export?${params}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    // Error selalu JSON: { "error": "..." }
    const { error } = await res.json().catch(() => ({ error: "Gagal mengunduh laporan" }));
    throw new Error(error);
  }

  const blob = await res.blob();
  const filename =
    parseFilename(res.headers.get("Content-Disposition")) ?? "laporan-keuangan.xlsx";

  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function parseFilename(contentDisposition) {
  if (!contentDisposition) return null;
  const m = /filename="?([^"]+)"?/.exec(contentDisposition);
  return m ? m[1] : null;
}
```

> Backend sudah mengirim `Access-Control-Expose-Headers: Content-Disposition`, jadi `res.headers.get("Content-Disposition")` **bisa dibaca** dari browser. Kalau nilainya `null`, cek `CORS_ALLOWED_ORIGINS` di server sudah memuat origin FE.

### 3.2 Mobile (Flutter)

```dart
final res = await dio.get(
  '/reports/finance/export',
  queryParameters: {'from': from, 'to': to},
  options: Options(
    responseType: ResponseType.bytes,
    headers: {'Authorization': 'Bearer $accessToken'},
    // biar 4xx tidak dilempar sebagai DioException, supaya body JSON-nya bisa dibaca
    validateStatus: (s) => s != null && s < 500,
  ),
);

if (res.statusCode != 200) {
  final msg = jsonDecode(utf8.decode(res.data))['error'];
  throw Exception(msg);
}

final dir = await getTemporaryDirectory();
final name = _filenameFrom(res.headers.value('content-disposition'))
    ?? 'laporan-keuangan.xlsx';
final file = File('${dir.path}/$name');
await file.writeAsBytes(res.data);
await OpenFilex.open(file.path); // atau Share.shareXFiles untuk kirim ke WA
```

Poin penting mobile:
- `responseType: bytes` — wajib, kalau tidak Dio akan mencoba mem-parsing binary sebagai string dan file jadi rusak.
- Simpan ke temporary/documents directory, lalu buka dengan `open_filex` atau bagikan lewat `share_plus`. Android 13+ tidak butuh izin storage untuk pola ini.
- Ukuran file untuk sebulan data biasanya puluhan–ratusan KB, aman untuk memori HP.

---

## 4. UX yang disarankan

- Tombol "Export Excel" di halaman laporan keuangan, memakai **rentang tanggal yang sedang aktif di layar** — jangan bikin filter terpisah, biar isi file selalu cocok dengan yang dilihat user.
- Tampilkan loading/spinner selama request. Untuk rentang panjang (mis. setahun penuh dengan ribuan transaksi) generate bisa memakan beberapa detik. **Disable tombolnya selama proses** supaya user tidak menembak request berkali-kali.
- Set timeout klien longgar (saran: **60 detik**) untuk endpoint ini saja, jangan pakai timeout default 10–15 detik.
- Untuk owner/supervisor, sediakan pilihan cabang termasuk opsi "Semua Cabang" (`branch_id=all`) — hasilnya menambah tabel ringkasan per cabang di sheet Ringkasan.

---

## 5. Tabel error

Semua error dikembalikan sebagai **JSON** (`{ "error": "..." }`) dengan `Content-Type: application/json`, bukan file. Cek `res.ok`/status sebelum memperlakukan body sebagai blob.

| Kode | `error` | Penyebab | Aksi FE |
|---|---|---|---|
| `400` | `invalid from date, expected YYYY-MM-DD` | Format `from` salah. | Kirim dari date picker, jangan free text. |
| `400` | `invalid to date, expected YYYY-MM-DD` | Format `to` salah. | Sama. |
| `400` | `invalid date range: to must not be earlier than from` | `to` < `from`. | Validasi di UI sebelum kirim. |
| `400` | `date range too wide, max 366 days` | Rentang > 366 hari. | Batasi date picker maksimal 1 tahun; tampilkan pesan "Rentang maksimal 1 tahun". |
| `400` | `invalid branch_id` | `branch_id` bukan angka/`all`. | — |
| `401` | `unauthorized` | Token invalid/expired. | Refresh token lalu retry sekali. |
| `403` | `forbidden` | Role bukan owner/supervisor/finance. | Sembunyikan tombol export untuk role lain. |
| `403` | `no branch assigned: please contact the owner...` | User non-owner belum di-assign cabang. | Pesan "Akun belum ditugaskan ke cabang". |
| `500` | `failed to build report` | Kegagalan di server. | Pesan generik + tombol coba lagi. |

---

## 6. Batasan yang perlu diketahui

- **Rentang maksimal 366 hari** per request. Untuk data multi-tahun, download per tahun.
- **Maksimal 200.000 baris per sheet rincian.** Kalau terlampaui, sheet dipotong dan diberi catatan di baris terakhir ("Data dipotong pada ... baris"). Praktisnya tidak akan tercapai dalam rentang 1 tahun.
- Sheet **Penjualan** hanya memuat transaksi ber-status **paid** — QRIS pending/expired/cancelled tidak ikut, konsisten dengan `GET /transactions`.
- File **tidak disimpan di server**. Setiap request men-generate ulang, tidak ada URL permanen yang bisa dibagikan. Ini disengaja: laporan keuangan tidak boleh berada di direktori statis `/uploads` yang bisa diakses tanpa auth.

---

## 7. Checklist QA

- [ ] Login finance → tombol export muncul; login kasir/leader → tombol tidak muncul, dan kalau endpoint dipanggil langsung dapat `403`.
- [ ] Export tanpa `from`/`to` → file berisi periode tanggal 1 bulan berjalan s/d hari ini.
- [ ] Nama file terunduh mengikuti `Content-Disposition` (bukan nama acak / bukan `export`).
- [ ] Buka di Excel/Google Sheets: 9 sheet ada, kolom nominal bisa di-`SUM` (bukan teks).
- [ ] Jam pada sheet Penjualan sama dengan jam di layar transaksi (WIB), tidak mundur 7 jam.
- [ ] Angka "Laba Operasional" di sheet Ringkasan sama dengan `GET /reports/ledger` untuk rentang yang sama.
- [ ] Rentang > 366 hari → `400` dengan pesan yang tampil ke user, bukan crash.
- [ ] Owner pilih "Semua Cabang" → sheet Ringkasan punya tabel per cabang.
- [ ] Mobile: file tersimpan dan bisa dibuka/di-share; ukuran file > 0 byte.
