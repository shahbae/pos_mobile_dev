# API — Waktu Pembuatan, Estimasi Siap di Nota, & Reset KDS saat Tutup Shift

Kontrak untuk tim Flutter (POS, master data, dan tablet dapur).

Dua perubahan yang rilis bersamaan:

1. **Waktu pembuatan produk** → nota menampilkan estimasi kapan pesanan jadi.
2. **Reset layar dapur saat tutup shift** → shift berikutnya mulai dengan layar
   bersih.

> Dokumen ini **berdiri sendiri** dan memuat semua perubahan kontrak dari dua
> fitur di atas, termasuk yang menyentuh `/kds/*`. `api-kds-fe.md` sengaja tidak
> diubah, jadi untuk hal-hal di bawah ini dokumen inilah yang berlaku.

Semua perubahan bersifat **non-breaking** — hanya penambahan field. Produk lama
otomatis `prep_minutes = 0`, transaksi lama tidak punya estimasi.

---

# BAGIAN 1 — Waktu pembuatan & estimasi siap

## 1.1 Aturan perhitungan

```
prep per unit  = variant.prep_minutes bila diisi, kalau tidak product.prep_minutes
total mentah   = Σ (prep per unit × qty)          ← dijumlah, bukan diambil yang terbesar
prep_minutes   = total mentah dibulatkan KE ATAS ke kelipatan 5
estimated_ready_at = waktu pembayaran + prep_minutes
```

Yang perlu diketahui:

- **Dijumlah, bukan max.** Asumsinya satu station kerja berurutan. 2 kopi @3 menit
  = 6 menit, bukan 3.
- **Dibulatkan ke atas ke kelipatan 5.** 13 menit → 15 menit. Nota tidak pernah
  menjanjikan angka yang lebih cepat dari perhitungan.
- **Topping, plastik, sedotan tidak menambah waktu.**
- **Titik hitungnya adalah saat LUNAS**, bukan saat order dibuat. Untuk QRIS,
  estimasi baru terisi ketika pembayaran settle/dikonfirmasi kasir — karena dapur
  memang baru mulai saat itu.
- **Dibekukan sekali, tidak pernah dihitung ulang.** Nota yang dicetak ulang bulan
  depan tetap menampilkan angka yang dulu dijanjikan ke pelanggan, walaupun
  `prep_minutes` di master sudah diubah.

## 1.2 Master data produk

### `POST /products` dan `PUT /products/:id`

Tambahan field, **opsional**:

| Field | Tipe | Keterangan |
|---|---|---|
| `prep_minutes` | int | 0–240 menit. Tidak dikirim = 0 = tidak ikut estimasi. |

```json
{
  "name": "Kopi Susu",
  "selling_price": "18000",
  "prep_minutes": 3
}
```

Di luar rentang 0–240 → `400 invalid input`.

### `GET /products` dan `GET /products/:id`

```json
{
  "id": 12,
  "name": "Kopi Susu",
  "selling_price": "18000",
  "prep_minutes": 3,
  "variants": [
    {
      "id": 40,
      "name": "Regular",
      "prep_minutes": null,
      "effective_prep_minutes": 3
    },
    {
      "id": 41,
      "name": "Large",
      "prep_minutes": 5,
      "effective_prep_minutes": 5
    }
  ]
}
```

Dua field berbeda, jangan tertukar:

- `prep_minutes` — override milik varian itu sendiri. `null` = ikut produk.
  **Ini yang dipakai form edit varian**, supaya bisa membedakan "ikut produk"
  dari "diisi manual dengan angka yang kebetulan sama".
- `effective_prep_minutes` — hasil akhir yang dipakai POS. Ini yang ditampilkan
  kalau cuma mau memberi info ke kasir.

### `POST /products/:id/variants` dan `PUT /products/:id/variants/:vid`

| Field | Tipe | Keterangan |
|---|---|---|
| `prep_minutes` | int / null | null atau tidak dikirim = ikut produk induk. 0–240. |

> **Perhatian:** PUT varian bersifat *full replace* seperti field lainnya. Kalau
> `prep_minutes` tidak dikirim saat update, override yang sudah ada **akan
> terhapus** dan varian kembali ikut produk. Form edit harus selalu mengirim ulang
> nilai yang sedang tampil.

Response `GET`/`POST`/`PUT` varian memuat `prep_minutes` (nullable) apa adanya.

## 1.3 Nota

Berlaku untuk ketiga jalur yang mengembalikan nota:

- `POST /product-transactions` — penjualan tunai/kartu
- `GET /qris-payments/:ref` — nota QRIS setelah statusnya `paid`
- `GET /product-transactions/:invoice_no` — cetak ulang

```json
{
  "invoice_no": "INV-20260811-0031",
  "created_at": "2026-08-11T14:22:37+07:00",
  "items": [ ... ],
  "total": 39000,
  "estimated_prep_minutes": 15,
  "estimated_ready_at": "2026-08-11T14:37:00+07:00",
  "store": { ... }
}
```

| Field | Tipe | Keterangan |
|---|---|---|
| `estimated_prep_minutes` | int | Sudah dibulatkan. `0` = tidak ada estimasi. |
| `estimated_ready_at` | string / null | ISO-8601 zona outlet. `null` = tidak ada estimasi. |

**Aturan cetak:**

- Kalau `estimated_ready_at` **null** atau `estimated_prep_minutes` **0**, jangan
  cetak baris estimasi sama sekali. Jangan cetak "0 menit" atau "siap sekarang" —
  itu terjadi karena produknya memang belum diisi waktu pembuatan, bukan karena
  pesanannya instan.
- Kalau ada, cetak **jam absolutnya**, bukan hitungan mundur — kertas tidak ikut
  berjalan:

  ```
  Estimasi siap : 14:37  (±15 menit)
  ```

- Antrean dapur **belum** diperhitungkan. Angka ini murni waktu pembuatan pesanan
  itu sendiri, seolah dapur langsung mengerjakannya.

## 1.4 Dua field baru di payload KDS

> Melengkapi `api-kds-fe.md` bagian 2 & 3 — dokumen itu belum memuat dua field ini.

Setiap objek pesanan di `GET /kds/orders` **dan** di frame SSE sekarang membawa:

```json
{
  "id": 8412,
  "invoice_no": "INV-20260806-0014",
  "status": "queued",
  "paid_at": "2026-08-06T17:12:44+07:00",
  "cashier_name": "Dewi",
  "prep_minutes": 15,
  "estimated_ready_at": "2026-08-06T17:27:00+07:00"
}
```

Nilainya **sama persis** dengan yang tercetak di nota pelanggan. Pakai untuk
menandai pesanan yang sudah lewat janji (`now > estimated_ready_at`). Kalau
`estimated_ready_at` **null**, jangan tampilkan penanda telat — artinya produknya
memang belum diisi waktu pembuatan, bukan berarti tepat waktu.

---

# BAGIAN 2 — Reset layar dapur saat tutup shift

> Melengkapi `api-kds-fe.md` bagian 1, 3 & 4.

## 2.1 Perilaku

Begitu kasir menutup shift, **semua pesanan cabang itu yang masih di layar**
(`queued`/`preparing`/`ready`) langsung disapu ke status **`closed`**. Shift
berikutnya mulai dengan layar bersih, tidak mewarisi kartu yang lupa ditekan
"served".

Sebelum ini layar dapur tidak pernah bersih: query KDS tidak ada kaitannya dengan
shift, jadi kartu yang lupa di-"served" nempel selamanya.

Kenapa `closed`, bukan `served`: tidak ada yang memastikan pesanan itu benar-benar
sampai ke pelanggan. Menandainya "sudah diantar" akan menyembunyikan seberapa
sering pesanan menggantung saat tutup toko.

## 2.2 Status dapur bertambah satu

Status dapur di `api-kds-fe.md` tertulis `queued` → `preparing` → `ready` →
`served`. Sekarang ada status kelima:

| Status | Siapa yang membuat |
|---|---|
| `queued`, `preparing`, `ready`, `served` | dapur, lewat `PATCH /kds/orders/:id/status` |
| **`closed`** | **hanya sistem**, saat shift ditutup |

## 2.3 Yang perlu dikerjakan Flutter

- **WAJIB: tangani `closed` di handler `order.status_changed`** — perlakukan sama
  seperti `served`, yaitu **hapus kartunya**.

  Tabel event di `api-kds-fe.md` bagian 3 tertulis "hapus jika `served`"; yang
  berlaku sekarang adalah "hapus jika `served` **atau** `closed`". Tanpa perubahan
  ini kartu akan berubah ke status yang tidak dikenali dan baru hilang saat tablet
  mengambil snapshot berikutnya.

- **Tidak perlu** mengubah pemanggilan `GET /kds/orders`: filter defaultnya tetap
  `queued,preparing,ready`, jadi pesanan tersapu tidak akan pernah muncul lagi.

- `PATCH /kds/orders/:id/status` **menolak** `closed` dengan `400`. Status ini
  hanya lahir dari tutup shift. Kalau butuh melihat riwayatnya, pakai
  `GET /kds/orders?status=closed`.

## 2.4 Catatan perilaku

- Penyapuan dijalankan **setelah** shift benar-benar tersimpan tertutup, dan
  bersifat best-effort — kalau gagal, tutup shift tetap berhasil dan kartu sisa
  akan hilang saat tutup shift berikutnya.
- Response tutup shift **tidak berubah**: tidak ada informasi berapa pesanan yang
  tersapu. Penyapuan berjalan diam-diam sesuai keputusan produk.
- Satu pengecualian yang disengaja: QRIS Midtrans yang masih `pending` dari shift
  lama bisa settle setelah shift ditutup. Pesanannya **tetap** masuk antrean dapur,
  karena uangnya sudah masuk dan minumannya memang harus dibuat.

---

# Migrasi

Kolom baru ditambahkan otomatis oleh AutoMigrate:

| Tabel | Kolom |
|---|---|
| `products` | `prep_minutes` int not null default 0 |
| `product_variants` | `prep_minutes` int null |
| `pos_transaction_items` | `prep_minutes` int not null default 0 (snapshot per unit) |
| `pos_transactions` | `prep_minutes` int not null default 0, `estimated_ready_at` datetime null |

Tidak ada kolom baru untuk reset KDS — hanya nilai baru (`closed`) di
`pos_transactions.kitchen_status` yang sudah ada.

Transaksi lama punya `estimated_ready_at` NULL → cetak ulang notanya tidak
menampilkan baris estimasi. Tidak ada backfill.
