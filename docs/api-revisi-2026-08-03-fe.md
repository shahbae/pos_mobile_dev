# Revisi API — 2026-08-03 (Panduan FE)

Lima revisi: filter tanggal pembelian, selisih + filter tanggal di laporan leader,
top produk tampil semua, hak akses stok opname (karyawan input / SPV approve), dan
hapus cabang (soft delete).

Envelope standar tetap: sukses `{ "success": true, "data": ... }`, error `{ "success": false, "message": "..." }`.

**Breaking:** hanya §3 (default `limit` pada top produk berubah). Sisanya aditif.

---

## 1. Filter tanggal di Pembelian — **diperbaiki**

`GET /purchases` sebenarnya sudah punya `from` & `to`, tapi tanggalnya **di-parse
sebagai UTC** sementara `created_at` tersimpan di timezone app (Asia/Jakarta).
Akibatnya jendela filter geser 7 jam: pembelian jam 00:00–07:00 tidak ikut ke-filter
di harinya sendiri, dan malah nyangkut ke hari sebelumnya.

Sekarang `from`/`to` dibaca sebagai **tanggal kalender di timezone app**, dan `to`
bersifat **inklusif** (mencakup satu hari penuh).

**Query param:**

| Param | Format | Arti |
|---|---|---|
| `from` | `YYYY-MM-DD` | Tanggal awal, inklusif. |
| `to` | `YYYY-MM-DD` | Tanggal akhir, **inklusif** (sampai 23:59:59 hari itu). |
| `date` | `YYYY-MM-DD` | 🆕 Pintasan satu hari — sama dengan `from=date&to=date`. Diabaikan bila `from`/`to` dikirim. |
| `supplier_id`, `page`, `limit` | — | Tidak berubah. |

```
GET /purchases?from=2026-08-01&to=2026-08-03
GET /purchases?date=2026-08-03
```

`to` lebih kecil dari `from` → **400 `"invalid request"`**.

**Yang perlu FE lakukan:**
- [ ] Tidak ada perubahan kode kalau sudah kirim `from`/`to` — angkanya sekarang benar.
- [ ] Boleh pakai `date` untuk filter "hari ini / pilih 1 tanggal" biar lebih ringkas.

---

## 2. Laporan Leader — selisih kas + filter rentang tanggal

`GET /reports/leader/daily`

### 2a. Field selisih (aditif)

Tiap baris shift kini memuat angka laci, **rumusnya sama persis** dengan `GET /shifts`
sehingga laporan leader dan riwayat shift tidak pernah beda angka:

| Field | Tipe | Arti |
|---|---|---|
| `closing_cash` | number \| `null` | Kas fisik saat tutup shift. `null` selama shift masih `open`. |
| `expected_cash` | number | Kas seharusnya = `opening_cash + cash_sales − expenses`. |
| `difference` | number \| `null` | **Selisih** = `closing_cash − expected_cash`. Positif = lebih, negatif = kurang. `null` selama shift `open`. |
| `shift_date` | string | 🆕 `YYYY-MM-DD` — berguna saat rentang lebih dari 1 hari. |

Di `totals` ditambahkan `opening_cash`, `closing_cash`, `expected_cash`, dan
`difference`. `closing_cash` & `difference` pada totals **hanya menjumlahkan shift
yang sudah ditutup** (shift open tidak punya angka fisik).

### 2b. Filter tanggal

| Param | Format | Arti |
|---|---|---|
| `date` | `YYYY-MM-DD` | Satu hari (perilaku lama, default hari ini). |
| `from` | `YYYY-MM-DD` | 🆕 Awal rentang, inklusif. |
| `to` | `YYYY-MM-DD` | 🆕 Akhir rentang, **inklusif**. |

Kirim salah satu saja dari `from`/`to` → ujung yang kosong ikut tanggal yang dikirim
(jadi satu hari). `to` < `from` → **400**.

Response menambah `from` & `to`; field `date` **tetap ada** (= `from`) supaya
integrasi lama tidak pecah.

```json
{
  "success": true,
  "data": {
    "date": "2026-08-01",
    "from": "2026-08-01",
    "to": "2026-08-03",
    "branch_id": 2,
    "branch_name": "Pusat",
    "shifts": [
      {
        "shift_id": 12,
        "shift_date": "2026-08-03",
        "shift_name": "Shift 1",
        "cashier_name": "Rina",
        "status": "closed",
        "opening_cash": 200000,
        "total_sales": 1500000,
        "total_items": 87,
        "transaction_count": 21,
        "cash_sales": 1300000,
        "expenses": 50000,
        "net": 1450000,
        "closing_cash": 1445000,
        "expected_cash": 1450000,
        "difference": -5000
      }
    ],
    "totals": {
      "total_sales": 1500000,
      "total_items": 87,
      "transaction_count": 21,
      "expenses": 50000,
      "net": 1450000,
      "total_cash": 1300000,
      "opening_cash": 200000,
      "closing_cash": 1445000,
      "expected_cash": 1450000,
      "difference": -5000
    },
    "chart": { "interval": "1hour", "points": [] }
  }
}
```

**Yang perlu FE lakukan:**
- [ ] Tampilkan kolom **Selisih** per shift dari `difference` (merah bila negatif/kurang, hijau bila positif/lebih, netral bila 0).
- [ ] Shift yang masih `open` → `difference` `null`, tampilkan `-` (jangan dianggap 0).
- [ ] Tambah date-range picker yang mengirim `from` & `to`; saat rentang > 1 hari, tampilkan `shift_date` di tiap baris.

---

## 3. ⚠️ Top Produk — tampil semua

`GET /reports/top-products` dulu **selalu** dipotong 10 teratas (dan di-cap keras 100
di layer DB). Sekarang **default-nya mengembalikan semua produk** yang terjual di
rentang tersebut, tanpa batas.

| Param | Perilaku baru |
|---|---|
| `limit` tidak dikirim | **Semua** produk (dulu: 10). |
| `limit=0` | Semua produk (eksplisit). |
| `limit=N` | Ambil N teratas. Cap 100 **dihapus**, `limit=250` sekarang benar-benar 250. |
| `limit` negatif / bukan angka | **400 `"invalid request"`**. |

Urutan tetap **revenue desc**. Struktur baris tidak berubah.

`top_products` di `GET /dashboard` **tidak berubah** — tetap 5 teratas.

**Yang perlu FE lakukan:**
- [ ] Halaman laporan top produk: siapkan list yang bisa panjang (scroll/paginasi di sisi FE), jangan asumsikan 10 baris.
- [ ] Kalau ada widget yang memang mau 10 besar saja, kirim `?limit=10` secara eksplisit.

---

## 4. Hak akses Stok Opname — karyawan input, SPV approve

Dulu hanya Owner & Supervisor yang bisa create/update/delete/approve; Finance read-only.
Sekarang dipisah antara **input** dan **persetujuan**:

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /stock-audits` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `GET /stock-audits/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `POST /stock-audits` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `PUT /stock-audits/:id` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `DELETE /stock-audits/:id` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `POST /stock-audits/:id/approve` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

Alur: **karyawan hitung fisik → simpan draft → supervisor/owner approve** (baru saat
itu stok berubah). Aturan lama tetap berlaku: draft bisa diedit/dihapus, audit
`approved` **immutable** (409), approve pakai apply-delta dan bisa gagal 409 kalau
stok kurang.

### Batas cabang (baru)

Role non-owner **terkunci ke cabang di token**:
- Draft cabang lain → `404 "not found"` untuk get/update/delete (bukan 403, supaya keberadaannya tidak bocor).
- `GET /stock-audits` untuk role non-owner **wajib punya konteks cabang**; kalau belum pilih cabang → `400 "branch context required: please select a branch first"`.
- Owner & supervisor tetap bebas: `?branch_id=<id>` atau `?branch_id=all`.

**Yang perlu FE lakukan:**
- [ ] Buka menu Stok Opname untuk kasir/karyawan/leader — tombol **Approve** hanya untuk owner & supervisor.
- [ ] Untuk role non-owner, pastikan cabang sudah dipilih sebelum membuka menu ini.
- [ ] Handle `404` saat membuka audit yang bukan milik cabang aktif.

---

## 5. Hapus Cabang (soft delete) — endpoint baru

`DELETE /branches/:id` — akses **Owner & Supervisor**.

```json
{ "success": true, "data": { "message": "deleted" } }
```

Error: `404 "branch not found"`, `400 "invalid request"` (id tidak valid).

**Soft delete**, artinya:
- Baris cabang tidak benar-benar dibuang. Transaksi, shift, dan pembelian lama tetap punya `branch_id`-nya sehingga **laporan historis tidak rusak**.
- Cabang langsung **hilang dari `GET /branches`** dan dari semua lookup cabang.
- Semua **assignment karyawan** ke cabang itu dihapus, dan user yang cabang terakhirnya adalah cabang tsb di-unpin — jadi tidak ada yang login ke cabang yang sudah dihapus.
- Nama cabang **dibebaskan**: nama yang sama boleh dipakai lagi untuk cabang baru.
- Belum ada endpoint restore. Kalau perlu, buat cabang baru.

Bedanya dengan `PUT /branches/:id/status` (`disabled`): status `disabled` **masih terlihat** di `GET /branches` (bisa di-filter `?status=`) dan bisa diaktifkan lagi — pakai itu untuk cabang yang cuma tutup sementara. `DELETE` untuk cabang yang memang sudah tidak dipakai.

**Yang perlu FE lakukan:**
- [ ] Tambah aksi Hapus di manajemen cabang (owner/supervisor), dengan konfirmasi.
- [ ] Setelah sukses, refresh daftar cabang; kalau cabang aktif user yang dihapus, arahkan untuk memilih cabang lagi.
