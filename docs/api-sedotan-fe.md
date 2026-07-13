# API: Sedotan (FE Guide)

Tanggal: 2026-07-11

## Ringkasan

Fitur **Sedotan** untuk mencatat sedotan (mis. "Sedotan Kecil", "Sedotan Jumbo") yang **dipilih manual oleh kasir saat transaksi POS**. Konsepnya **identik dengan Plastik**.

Karakteristik penting:

- **Gratis** — sedotan **tidak menambah total** yang dibayar pelanggan. Tidak ada harga jual.
- **Per transaksi** — dipilih sekali untuk seluruh pesanan (bukan menempel per item seperti topping).
- **Kurangi stok per cabang** — sedotan adalah barang inventori: punya stok per cabang, direstock via pembelian, dan berkurang tiap transaksi.
- **Punya COGS** — biaya sedotan (dari harga beli) ikut mengurangi laba di laporan, walaupun tidak dijual.

Secara struktur, sedotan mirror **Plastik** persis: tanpa harga jual dan dipilih di level transaksi.

> **Envelope response** semua endpoint: `{ "success": true, "data": ... }` untuk sukses, `{ "success": false, "message": "..." }` untuk error. Semua butuh header `Authorization: Bearer <token>`.

---

## Konsep Angka

- `purchase_qty` + `purchase_price` = harga beli master (1 paket berisi `purchase_qty` unit seharga `purchase_price`).
- **COGS per unit** = `purchase_price / purchase_qty`. Satu sedotan yang dipilih = 1 unit stok berkurang (tidak ada faktor pemakaian seperti `usage_qty` topping).
- Field decimal dikirim/diterima sebagai **string** (mis. `"1500.00"`), konsisten dengan material/topping/plastik.

---

## A. Master Sedotan — CRUD

### 1. List

```
GET /sedotans
```
Role: Owner, Supervisor, Leader, Finance, Kasir, Karyawan (kasir perlu ini untuk pilihan di POS).

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Sedotan Kecil",
      "unit": "pcs",
      "purchase_qty": "50.0000",
      "purchase_price": "15000.00",
      "is_active": true,
      "purchase_templates": [
        { "id": 10, "sedotan_id": 1, "name": "Default", "base_qty": "50.0000" }
      ],
      "created_at": "2026-07-11T00:00:00Z"
    }
  ]
}
```

### 2. Create

```
POST /sedotans
```
Role: Owner, Supervisor, Leader.

**Request:**
```json
{
  "name": "Sedotan Jumbo",
  "unit": "pcs",
  "purchase_qty": "100",
  "purchase_price": "28000",
  "purchase_templates": [
    { "name": "Pack 100", "base_qty": "100" }
  ]
}
```
- `name`, `unit` — wajib. `name` unik (duplikat → `409`).
- `purchase_qty` — opsional, default `"1"`, harus > 0.
- `purchase_price` — opsional, default `"0"`, harus ≥ 0.
- `purchase_templates` — opsional. Kalau tidak dikirim, sistem otomatis membuat template "Default" dari `purchase_qty`. Kalau dikirim, mengganti penuh daftar template.

**Response:** `201` dengan objek sedotan (termasuk `id` dan `purchase_templates`).

### 3. Get / Update / Delete

```
GET    /sedotans/:id      (Owner, Supervisor, Leader, Finance)
PUT    /sedotans/:id      (Owner, Supervisor, Leader)
DELETE /sedotans/:id      (Owner, Supervisor, Leader)
```
- `PUT` body sama seperti Create. `purchase_qty`/`purchase_price` boleh dikosongkan → tidak diubah. `purchase_templates` kalau `null`/tidak dikirim → tidak diubah; kalau array → diganti penuh.
- Catatan: `is_active` **belum bisa di-toggle** lewat API saat ini (konsisten dengan plastik) — untuk menghilangkan sedotan dari daftar gunakan `DELETE`. Kalau butuh toggle aktif/nonaktif, minta ke BE.

**Error umum:** `400` invalid input, `404` not found, `409` nama sudah ada.

---

## B. Stok Sedotan (per cabang)

### 1. List stok

```
GET /sedotan-stock
```
Role: Owner, Supervisor, Leader, Finance. Branch-scoped dari token (owner tanpa cabang → agregat semua cabang).

**Response:** tiap baris = level stok + `incoming_today` (jumlah barang masuk hari ini) + `packs` (breakdown kemasan):
```json
{
  "success": true,
  "data": [
    {
      "id": 3,
      "sedotan_id": 1,
      "branch_id": 2,
      "sedotan": { "id": 1, "name": "Sedotan Kecil", "unit": "pcs" },
      "qty": "480.0000",
      "name": "Sedotan Kecil",
      "unit": "pcs",
      "incoming_today": "100.0000",
      "packs": [ { "name": "Default", "packs": "9.6000", "base_qty": "50.0000" } ]
    }
  ]
}
```

### 2. Riwayat pergerakan stok

```
GET /sedotan-stock/movements?sedotan_id=1
```
Role: Owner, Supervisor, Leader, Finance. `sedotan_id` opsional (filter).

**Response:** array movement `{ id, sedotan_id, branch_id, sedotan, type, quantity, reference_type, reference_id, created_at }`. `type` = `IN` | `OUT` | `ADJUST`. `reference_type` = `purchase` | `sale` | `audit` | `return` | `manual` dll.

### 3. Penyesuaian stok manual (opname cepat)

```
POST /sedotan-stock/adjust
```
Role: Owner, Supervisor.

**Request:**
```json
{ "sedotan_id": 1, "branch_id": 2, "new_qty": "500", "reference_type": "manual" }
```
- `new_qty` = nilai absolut baru (bukan delta).
- `branch_id` — non-owner boleh dikosongkan (ambil dari token); owner wajib menentukan cabang.

> Untuk stock opname penuh dengan approval, gunakan **Stock Audit** (bagian E), bukan endpoint adjust ini.

---

## C. Restock Sedotan via Pembelian

Sedotan direstock lewat endpoint pembelian yang sama seperti material/topping/plastik. Item pembelian memilih **purchase template** milik sedotan.

```
POST /purchases
```
```json
{
  "supplier_id": 3,
  "note": "beli sedotan",
  "items": [
    { "template_id": 10, "qty": 5 }
  ]
}
```
- `template_id` = id template sedotan (lihat `purchase_templates` di master sedotan).
- `qty` = jumlah paket. Stok bertambah `template.base_qty × qty`.
- Biaya dihitung otomatis dari master (`purchase_price / purchase_qty`), FE tidak input harga.
- Di response purchase, `items[].sedotan` akan terisi untuk baris sedotan.

---

## D. Integrasi POS (Transaksi)

Saat membuat transaksi, tambahkan field **top-level** `sedotans` (opsional). Ini **terpisah** dari `items` dan `plastics`.

```
POST /product-transactions
```
```json
{
  "payment_method": "cash",
  "paid": 20000,
  "items": [
    { "product_id": 5, "variant_id": 2, "qty": 1 }
  ],
  "plastics": [
    { "plastic_id": 1, "qty": 1 }
  ],
  "sedotans": [
    { "sedotan_id": 1, "qty": 1 },
    { "sedotan_id": 3, "qty": 2 }
  ]
}
```

Aturan:
- `sedotans` boleh kosong / tidak dikirim.
- Tiap entri: `sedotan_id` (wajib) + `qty` (wajib, min 1).
- Sedotan **tidak mempengaruhi** `subtotal`, `total`, maupun `paid` — murni pencatatan.
- Sedotan non-aktif / tidak ada → `422` (`sedotan not found` / `sedotan is not active`).
- **Stok sedotan habis tidak memblokir penjualan** — transaksi tetap sukses, kekurangan stok hanya dicatat (boleh minus). Berbeda dari bahan produk yang memblokir (`product not ready`).

**Response (receipt)** akan memuat array `sedotans` (tanpa harga):
```json
{
  "success": true,
  "data": {
    "invoice_no": "INV-20260711-0001",
    "items": [ ... ],
    "plastics": [ { "name": "Plastik Cup 1", "qty": 1 } ],
    "sedotans": [
      { "name": "Sedotan Kecil", "qty": 1 },
      { "name": "Sedotan Jumbo", "qty": 2 }
    ],
    "subtotal": 20000,
    "total": 20000
  }
}
```
`GET /product-transactions/:invoice_no` juga mengembalikan `sedotans` yang sama.

**Saran UI kasir:** tampilkan daftar sedotan aktif (dari `GET /sedotans`) sebagai pilihan cepat + input qty, terpisah dari keranjang produk. Karena gratis, tidak perlu tampil di ringkasan harga — cukup di struk sebagai info.

---

## E. Integrasi Stock Audit (Opname)

Item audit sekarang bisa berupa material **atau** topping **atau** plastik **atau** sedotan. Setiap item audit mengisi **tepat satu** dari `material_id` / `topping_id` / `plastic_id` / `sedotan_id`.

```
POST /stock-audits
PUT  /stock-audits/:id
```
```json
{
  "branch_id": 2,
  "notes": "opname sore",
  "items": [
    { "sedotan_id": 1, "physical_qty": "475", "returned_qty": "0" },
    { "topping_id": 4, "physical_qty": "12.5" }
  ]
}
```
- Sedotan memakai **desimal** (boleh pecahan), sama seperti topping/plastik (material tetap harus bilangan bulat).
- `physical_qty` = hasil hitung fisik. `returned_qty` = stok yang keluar cabang sah (dikembalikan), dikecualikan dari selisih.
- Selisih `diff = physical − (system − returned)`.
- Duplikat sedotan dalam satu audit → `400`.

Saat **approve** (`POST /stock-audits/:id/approve`), stok sedotan disesuaikan (return + variance). Selisih negatif sedotan otomatis masuk **laporan kerugian** (loss) dan dashboard, dinilai dengan `purchase_price / purchase_qty`.

---

## F. Dampak ke Laporan

- **`GET /reports/profit`** dan **`GET /reports/ledger`**: COGS total kini mencakup biaya sedotan (`Σ cogs_per_unit × qty` dari transaksi). Sedotan gratis (tak menambah revenue) tapi menambah COGS → menekan gross/net profit.
- **`GET /dashboard`**: ikut ter-update karena memakai profit report yang sama.
- FE tidak perlu perubahan khusus untuk laporan — angka COGS/profit sudah otomatis benar.

---

## Ringkasan Endpoint Baru

| Method | Path | Role |
|---|---|---|
| GET | `/sedotans` | Owner, Supervisor, Leader, Finance, Kasir, Karyawan |
| POST | `/sedotans` | Owner, Supervisor, Leader |
| GET | `/sedotans/:id` | Owner, Supervisor, Leader, Finance |
| PUT | `/sedotans/:id` | Owner, Supervisor, Leader |
| DELETE | `/sedotans/:id` | Owner, Supervisor, Leader |
| GET | `/sedotan-stock` | Owner, Supervisor, Leader, Finance |
| GET | `/sedotan-stock/movements` | Owner, Supervisor, Leader, Finance |
| POST | `/sedotan-stock/adjust` | Owner, Supervisor |

Field baru pada endpoint existing: `sedotans[]` di `POST /product-transactions` (+ receipt), `sedotan_id` di item `POST/PUT /stock-audits`, `template_id` sedotan di `POST /purchases`.
