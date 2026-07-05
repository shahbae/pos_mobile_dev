# API: Plastik / Kemasan (FE Guide)

Tanggal: 2026-07-05

## Ringkasan

Fitur **Plastik** untuk mencatat kemasan (mis. "Plastik Cup 1", "Plastik Cup 2", "Plastik Cup 4") yang **dipilih manual oleh kasir saat transaksi POS**.

Karakteristik penting:

- **Gratis** — plastik **tidak menambah total** yang dibayar pelanggan. Tidak ada harga jual.
- **Per transaksi** — dipilih sekali untuk seluruh pesanan (bukan menempel per item seperti topping).
- **Kurangi stok per cabang** — plastik adalah barang inventori: punya stok per cabang, direstock via pembelian, dan berkurang tiap transaksi.
- **Punya COGS** — biaya plastik (dari harga beli) ikut mengurangi laba di laporan, walaupun tidak dijual.

Secara struktur, plastik mirip **Topping** tetapi tanpa harga jual dan dipilih di level transaksi.

> **Envelope response** semua endpoint: `{ "success": true, "data": ... }` untuk sukses, `{ "success": false, "message": "..." }` untuk error. Semua butuh header `Authorization: Bearer <token>`.

---

## Konsep Angka

- `purchase_qty` + `purchase_price` = harga beli master (1 paket berisi `purchase_qty` unit seharga `purchase_price`).
- **COGS per unit** = `purchase_price / purchase_qty`. Satu plastik yang dipilih = 1 unit stok berkurang (tidak ada faktor pemakaian seperti `usage_qty` topping).
- Field decimal dikirim/diterima sebagai **string** (mis. `"1500.00"`), konsisten dengan material & topping.

---

## A. Master Plastik — CRUD

### 1. List

```
GET /plastics
```
Role: Owner, Supervisor, Leader, Finance, Kasir, Karyawan (kasir perlu ini untuk pilihan di POS).

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Plastik Cup 1",
      "unit": "pcs",
      "purchase_qty": "50.0000",
      "purchase_price": "15000.00",
      "is_active": true,
      "purchase_templates": [
        { "id": 10, "plastic_id": 1, "name": "Default", "base_qty": "50.0000" }
      ],
      "created_at": "2026-07-05T00:00:00Z"
    }
  ]
}
```

### 2. Create

```
POST /plastics
```
Role: Owner, Supervisor, Leader.

**Request:**
```json
{
  "name": "Plastik Cup 2",
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

**Response:** `201` dengan objek plastik (termasuk `id` dan `purchase_templates`).

### 3. Get / Update / Delete

```
GET    /plastics/:id      (Owner, Supervisor, Leader, Finance)
PUT    /plastics/:id      (Owner, Supervisor, Leader)
DELETE /plastics/:id      (Owner, Supervisor, Leader)
```
- `PUT` body sama seperti Create. `purchase_qty`/`purchase_price` boleh dikosongkan → tidak diubah. `purchase_templates` kalau `null`/tidak dikirim → tidak diubah; kalau array → diganti penuh.
- Catatan: `is_active` **belum bisa di-toggle** lewat API saat ini (konsisten dengan topping) — untuk menghilangkan plastik dari daftar gunakan `DELETE`. Kalau butuh toggle aktif/nonaktif, minta ke BE.

**Error umum:** `400` invalid input, `404` not found, `409` nama sudah ada.

---

## B. Stok Plastik (per cabang)

### 1. List stok

```
GET /plastic-stock
```
Role: Owner, Supervisor, Leader, Finance. Branch-scoped dari token (owner tanpa cabang → agregat semua cabang).

**Response:** tiap baris = level stok + `incoming_today` (jumlah barang masuk hari ini):
```json
{
  "success": true,
  "data": [
    {
      "id": 3,
      "plastic_id": 1,
      "branch_id": 2,
      "plastic": { "id": 1, "name": "Plastik Cup 1", "unit": "pcs", ... },
      "qty": "480.0000",
      "incoming_today": "100.0000"
    }
  ]
}
```

### 2. Riwayat pergerakan stok

```
GET /plastic-stock/movements?plastic_id=1
```
Role: Owner, Supervisor, Leader, Finance. `plastic_id` opsional (filter).

**Response:** array movement `{ id, plastic_id, branch_id, plastic, type, quantity, reference_type, reference_id, created_at }`. `type` = `IN` | `OUT` | `ADJUST`. `reference_type` = `purchase` | `sale` | `audit` | `return` | `manual` dll.

### 3. Penyesuaian stok manual (opname cepat)

```
POST /plastic-stock/adjust
```
Role: Owner, Supervisor.

**Request:**
```json
{ "plastic_id": 1, "branch_id": 2, "new_qty": "500", "reference_type": "manual" }
```
- `new_qty` = nilai absolut baru (bukan delta).
- `branch_id` — non-owner boleh dikosongkan (ambil dari token); owner wajib menentukan cabang.

> Untuk stock opname penuh dengan approval, gunakan **Stock Audit** (bagian E), bukan endpoint adjust ini.

---

## C. Restock Plastik via Pembelian

Plastik direstock lewat endpoint pembelian yang sama seperti material/topping. Item pembelian memilih **purchase template** milik plastik.

```
POST /purchases
```
```json
{
  "supplier_id": 3,
  "note": "beli plastik",
  "items": [
    { "template_id": 10, "qty": 5 }
  ]
}
```
- `template_id` = id template plastik (lihat `purchase_templates` di master plastik).
- `qty` = jumlah paket. Stok bertambah `template.base_qty × qty`.
- Biaya dihitung otomatis dari master (`purchase_price / purchase_qty`), FE tidak input harga.
- Di response purchase, `items[].plastic` akan terisi untuk baris plastik.

---

## D. Integrasi POS (Transaksi)

Saat membuat transaksi, tambahkan field **top-level** `plastics` (opsional). Ini **terpisah** dari `items`.

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
    { "plastic_id": 1, "qty": 1 },
    { "plastic_id": 3, "qty": 2 }
  ]
}
```

Aturan:
- `plastics` boleh kosong / tidak dikirim.
- Tiap entri: `plastic_id` (wajib) + `qty` (wajib, min 1).
- Plastik **tidak mempengaruhi** `subtotal`, `total`, maupun `paid` — murni pencatatan kemasan.
- Plastik non-aktif / tidak ada → `422` (`plastic not found` / `plastic is not active`).
- **Stok plastik habis tidak memblokir penjualan** — transaksi tetap sukses, kekurangan stok hanya dicatat (boleh minus). Berbeda dari bahan produk yang memblokir (`product not ready`).

**Response (receipt)** akan memuat array `plastics` (tanpa harga):
```json
{
  "success": true,
  "data": {
    "invoice_no": "INV-20260705-0001",
    "items": [ ... ],
    "plastics": [
      { "name": "Plastik Cup 1", "qty": 1 },
      { "name": "Plastik Cup 4", "qty": 2 }
    ],
    "subtotal": 20000,
    "total": 20000,
    ...
  }
}
```
`GET /product-transactions/:invoice_no` juga mengembalikan `plastics` yang sama.

**Saran UI kasir:** tampilkan daftar plastik aktif (dari `GET /plastics`) sebagai pilihan cepat + input qty, terpisah dari keranjang produk. Karena gratis, tidak perlu tampil di ringkasan harga — cukup di struk sebagai info kemasan.

---

## E. Integrasi Stock Audit (Opname)

Item audit sekarang bisa berupa material **atau** topping **atau** plastik. Setiap item audit mengisi **tepat satu** dari `material_id` / `topping_id` / `plastic_id`.

```
POST /stock-audits
PUT  /stock-audits/:id
```
```json
{
  "branch_id": 2,
  "notes": "opname sore",
  "items": [
    { "plastic_id": 1, "physical_qty": "475", "returned_qty": "0" },
    { "topping_id": 4, "physical_qty": "12.5" }
  ]
}
```
- Plastik memakai **desimal** (boleh pecahan), sama seperti topping (material tetap harus bilangan bulat).
- `physical_qty` = hasil hitung fisik. `returned_qty` = stok yang keluar cabang sah (dikembalikan), dikecualikan dari selisih.
- Selisih `diff = physical − (system − returned)`.
- Duplikat plastik dalam satu audit → `400`.

Saat **approve** (`POST /stock-audits/:id/approve`), stok plastik disesuaikan (return + variance). Selisih negatif plastik otomatis masuk **laporan kerugian** (loss) dan dashboard, dinilai dengan `purchase_price / purchase_qty`.

---

## F. Dampak ke Laporan

- **`GET /reports/profit`** dan **`GET /reports/ledger`**: COGS total kini mencakup biaya plastik (`Σ cogs_per_unit × qty` dari transaksi). Plastik gratis (tak menambah revenue) tapi menambah COGS → menekan gross/net profit.
- **`GET /dashboard`**: ikut ter-update karena memakai profit report yang sama.
- FE tidak perlu perubahan khusus untuk laporan — angka COGS/profit sudah otomatis benar. Cukup pahami bahwa margin bisa turun karena biaya kemasan kini dihitung.

---

## Ringkasan Endpoint Baru

| Method | Path | Role |
|---|---|---|
| GET | `/plastics` | Owner, Supervisor, Leader, Finance, Kasir, Karyawan |
| POST | `/plastics` | Owner, Supervisor, Leader |
| GET | `/plastics/:id` | Owner, Supervisor, Leader, Finance |
| PUT | `/plastics/:id` | Owner, Supervisor, Leader |
| DELETE | `/plastics/:id` | Owner, Supervisor, Leader |
| GET | `/plastic-stock` | Owner, Supervisor, Leader, Finance |
| GET | `/plastic-stock/movements` | Owner, Supervisor, Leader, Finance |
| POST | `/plastic-stock/adjust` | Owner, Supervisor |

Field baru pada endpoint existing: `plastics[]` di `POST /product-transactions` (+ receipt), `plastic_id` di item `POST/PUT /stock-audits`, `template_id` plastik di `POST /purchases`.
