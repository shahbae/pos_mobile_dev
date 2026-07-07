# API: Revisi 2026-07-07 — Panduan FE

Rangkuman tiga perubahan pada revisi ini:

1. [Dashboard: blok `shifts_summary`](#1-dashboard-shifts_summary-kasir--leader) — total item & jumlah transaksi per shift (kasir & leader)
2. [Pengeluaran: foto bukti wajib](#2-pengeluaran-foto-bukti-wajib) — `POST /expenses` jadi multipart (**breaking**)
3. [Master Cabang: catatan komplain](#3-master-cabang-catatan-komplain) — field baru `complaint_note`

---

# 1. Dashboard: `shifts_summary` (Kasir & Leader)

Rekap penjualan **per shift** dalam satu hari: total item terjual + jumlah transaksi. Untuk membandingkan performa **Shift 1 vs Shift 2**. Bagian dari response **`GET /dashboard`** (bukan endpoint baru), muncul untuk role **Kasir** dan **Leader**.

```
GET /dashboard?from=YYYY-MM-DD&to=YYYY-MM-DD
Authorization: Bearer <token>
```

## Bentuk data

```json
"shifts_summary": [
  { "shift_id": 87, "shift_name": "Shift 1", "total_items": 145, "transaction_count": 28 },
  { "shift_id": 88, "shift_name": "Shift 2", "total_items": 132, "transaction_count": 22 }
]
```

| Field | Tipe | Keterangan |
|---|---|---|
| `shift_id` | `int` | ID shift (unik) |
| `shift_name` | `string` | `"Shift 1"` / `"Shift 2"` |
| `total_items` | `int` | Total item terjual = `Σ qty` semua baris transaksi di shift itu |
| `transaction_count` | `int` | Jumlah transaksi POS di shift itu |

> **Tipe angka:** `total_items` & `transaction_count` = **integer** (bukan string desimal).

## Aturan tampil (WAJIB dibaca)

1. **Hanya untuk rentang 1 hari.** Blok ini **hanya ada** kalau `from == to`.
   - `from == to` → key `shifts_summary` **ada** (array isi atau `[]`).
   - `from != to` → key **tidak ada sama sekali** di JSON.
   ```js
   if (Array.isArray(data.shifts_summary)) {
     renderShiftsSummary(data.shifts_summary);
   } else {
     // rentang >1 hari — sembunyikan komponen per-shift
   }
   ```
2. **Semua shift hari itu terisi, bukan hanya yang sedang jalan.** Termasuk shift yang sudah ditutup. Jangan samakan dengan `current_shift` (itu hanya 1 shift `open`).
3. **Urutan** naik berdasarkan jam buka → Shift 1 dulu, lalu Shift 2.
4. **Shift tanpa transaksi tetap muncul** dengan angka `0`.

## Contoh per kondisi

Dua shift (Shift 1 tutup, Shift 2 jalan):
```json
"shifts_summary": [
  { "shift_id": 87, "shift_name": "Shift 1", "total_items": 145, "transaction_count": 28 },
  { "shift_id": 88, "shift_name": "Shift 2", "total_items": 132, "transaction_count": 22 }
]
```
Baru Shift 1 saja:
```json
"shifts_summary": [ { "shift_id": 87, "shift_name": "Shift 1", "total_items": 145, "transaction_count": 28 } ]
```
Shift dibuka, belum ada transaksi:
```json
"shifts_summary": [ { "shift_id": 87, "shift_name": "Shift 1", "total_items": 0, "transaction_count": 0 } ]
```
Belum ada shift hari itu (tapi `from == to`):
```json
"shifts_summary": []
```
Rentang >1 hari (`from != to`): key tidak ada.

## Saran tampilan

| Shift | Item Terjual | Transaksi |
|---|---:|---:|
| Shift 1 | 145 | 28 |
| Shift 2 | 132 | 22 |
| **Total** | **277** | **50** |

Baris **Total** dihitung sendiri di FE (jumlahkan semua elemen array).

## Ketersediaan per role

| Role | Dapat `shifts_summary`? |
|---|:--:|
| Kasir | ✅ |
| Leader | ✅ |
| Supervisor / Finance / Owner / Karyawan / Produksi | ❌ |

---

# 2. Pengeluaran: Foto Bukti Wajib

Setiap pengeluaran (expense) kini **wajib menyertakan foto bukti** (mis. nota/struk), dikirim **sekaligus** saat create dalam satu request `multipart/form-data`.

## Create — `POST /expenses`

**Content-Type: `multipart/form-data`** (bukan JSON lagi — **breaking change**).

| Field | Tipe | Wajib | Keterangan |
|---|---|:--:|---|
| `amount` | text | ✅ | Nominal, mis. `"15000.00"` (> 0) |
| `category` | text | ✅ | Kategori, mis. `"operational"` |
| `description` | text | — | Keterangan (boleh kosong) |
| `expense_date` | text | ✅ | `YYYY-MM-DD` |
| `photo` | file | ✅ | Foto bukti. **jpg/jpeg/png/webp**, maks **2 MB** |

> `branch_id` & `shift_id` **tidak** dikirim FE — diambil otomatis dari token (cabang) & shift open.

### Contoh (JavaScript)

```js
const form = new FormData();
form.append("amount", "15000.00");
form.append("category", "operational");
form.append("description", "gas delivery");
form.append("expense_date", "2026-02-18");
form.append("photo", fileInput.files[0]);

await fetch(`${baseUrl}/expenses`, {
  method: "POST",
  headers: { Authorization: `Bearer ${token}` }, // JANGAN set Content-Type manual
  body: form,
});
```

### Response `201 Created`

```json
{
  "data": {
    "id": 91,
    "branch_id": 2,
    "shift_id": 88,
    "amount": "15000.00",
    "category": "operational",
    "description": "gas delivery",
    "expense_date": "2026-02-18T00:00:00Z",
    "created_by": 21,
    "created_at": "2026-07-07T10:12:00Z",
    "photo_url": "https://api.example.com/uploads/expenses/ab12cd34ef56.jpg"
  }
}
```

Field baru **`photo_url`** = URL penuh, siap dipakai di `<img src>`.

### Error

| Status | Pesan | Penyebab |
|---|---|---|
| 400 | `photo is required` | Field `photo` tidak dikirim |
| 400 | `photo must be ≤ 2MB` | Ukuran file > 2 MB |
| 400 | `only jpg, jpeg, png, webp are allowed` | Ekstensi tidak didukung |
| 400 | `invalid request` | `amount`/`category`/`expense_date` kosong/salah format |
| 400 | `failed to parse form` | Body bukan `multipart/form-data` valid |
| 401 | `unauthorized` | Token tidak valid |

## Get & List

`GET /expenses/:id` dan tiap item `GET /expenses` kini memuat `photo_url`:

```json
{
  "data": {
    "items": [
      { "id": 91, "amount": "15000.00", "category": "operational", "photo_url": "https://api.example.com/uploads/expenses/ab12cd34ef56.jpg" }
    ],
    "total": 1, "page": 1, "limit": 20
  }
}
```

## Catatan

1. **Breaking:** `POST /expenses` tidak lagi menerima JSON — harus `multipart/form-data`.
2. **Foto wajib** — validasi tipe & ukuran (≤ 2 MB) di FE sebelum submit.
3. `photo_url` selalu ada untuk pengeluaran baru; **data lama** (sebelum fitur) bisa `null` → tetap handle null saat render.
4. Tipe file: `jpg`, `jpeg`, `png`, `webp`. Maks **2 MB**.
5. `amount` di response tetap **string desimal** (`"15000.00"`).

---

# 3. Master Cabang: Catatan Komplain

Master cabang punya field baru **`complaint_note`** (catatan komplain), sejenis `footer_note` (catatan struk). Keduanya teks bebas per cabang yang ikut dicetak di struk POS.

## Field

| Field | Tipe | Wajib | Keterangan |
|---|---|:--:|---|
| `footer_note` | `string \| null` | — | Catatan bawah struk (sudah ada) |
| `complaint_note` | `string \| null` | — | **Baru.** Catatan komplain, mis. "Komplain? Hubungi 0812-xxxx" |

- **Opsional**, maks **500 karakter**.

## Create / Update — `POST /branches`, `PUT /branches/:id`

```json
{
  "name": "Cabang Bekasi",
  "address": "Jl. Merdeka No. 1",
  "footer_note": "Simpan struk sebagai bukti pembayaran",
  "complaint_note": "Komplain? Hubungi WA 0812-3456-7890",
  "logo_path": null,
  "latitude": -6.2,
  "longitude": 106.9,
  "attendance_radius": 100
}
```

Kirim `null`/`""` pada `complaint_note` untuk mengosongkan.

## Response cabang (Create / Update / List / Get)

```json
{
  "data": {
    "id": 2,
    "name": "Cabang Bekasi",
    "footer_note": "Simpan struk sebagai bukti pembayaran",
    "complaint_note": "Komplain? Hubungi WA 0812-3456-7890",
    "attendance_radius": 100,
    "status": "active"
  }
}
```

> `footer_note` & `complaint_note` memakai `omitempty` — kalau `null` di DB, key bisa **tidak muncul**. Treat opsional.

## Tampil di struk POS

Blok `store` pada response struk POS kini memuat `complaint_note`:

```json
"store": {
  "name": "Cabang Bekasi",
  "address": "Jl. Merdeka No. 1",
  "footer_note": "Simpan struk sebagai bukti pembayaran",
  "complaint_note": "Komplain? Hubungi WA 0812-3456-7890"
}
```

> Berbeda dengan response cabang, di `store` (struk) `complaint_note` **selalu ada** sebagai string — kosong (`""`) kalau belum diisi. Render barisnya hanya bila tidak kosong.

## Ringkas untuk FE

1. Tambahkan input **Catatan Komplain** di form master cabang, di sebelah **Catatan Struk**.
2. Opsional, maks 500 karakter.
3. Response cabang bisa absen kalau null (omitempty); struk POS selalu string.
