# Perubahan API untuk Frontend — 2026-06-29

Ringkasan perubahan backend `be-pos` yang berdampak ke FE pada sesi ini. Lima area:

1. [Cabang & assignment user](#1-cabang--assignment-user)
2. [Kategori produk: toggle `freeable` (item gratis promo)](#2-kategori-produk-toggle-freeable)
3. [Pembelian pakai template (tanpa input harga)](#3-pembelian-pakai-template)
4. [Master topping: field harga beli baru](#4-master-topping-field-harga-beli)
5. [Role `produksi` dibatasi hanya absensi](#5-role-produksi-hanya-absensi)

> Format response standar: sukses `{"success": true, "data": ...}`, gagal `{"success": false, "message": "..."}`.

---

## 1. Cabang & assignment user

### Konsep
- Tiap user (selain **owner**) sekarang **di-assign ke satu/lebih cabang**. User hanya bisa melihat & beroperasi di cabang yang di-assign.
- **Owner** bypass: akses semua cabang; tanpa memilih cabang = tampilan konsolidasi (semua cabang).
- Konteks cabang dibawa di JWT. Pindah cabang via `switch-branch`.

### Endpoint baru — assign cabang ke karyawan
Akses: **Owner, Supervisor**.

**GET `/employees/:id/branches`** → daftar id cabang yang di-assign.
```json
{ "success": true, "data": { "branch_ids": [1, 2] } }
```

**PUT `/employees/:id/branches`**
```json
// request
{ "branch_ids": [1, 2] }
```
```json
// response
{ "success": true, "data": { "message": "ok", "branch_ids": [1, 2] } }
```
- `branch_ids: []` → mengosongkan assignment (user jadi tidak punya cabang).
- Error `400` bila ada id cabang tak dikenal; `404` bila karyawan tidak ditemukan.

### `POST /auth/switch-branch` — perilaku baru
```json
// request
{ "branch_id": 2 }
```
```json
// response 200
{
  "success": true,
  "data": {
    "access_token": "…token-baru-bawa-cabang-2…",
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": { "user_id": 5, "branch_id": 2, "role": "kasir", "email": "andi@toko.com", "name": "Andi" }
  }
}
```
- **Baru:** non-owner yang switch ke cabang **bukan assignment-nya** → `403 "branch not assigned to this user"`.
- FE wajib **mengganti** access token dengan yang baru dari response.

### `GET /branches` — sekarang ter-scope
- Owner → semua cabang. Non-owner → **hanya cabang yang di-assign**.
- Field Branch: `id, name, address, footer_note, logo_path, latitude, longitude, attendance_radius, status, created_at`.

### Guard baru: non-owner wajib punya cabang
Endpoint operasional & laporan (transaksi POS, transactions, expenses, purchases, shifts, dashboard, reports/*, absensi scan) sekarang menolak non-owner yang tokennya **tanpa cabang**:
```json
// 403
{ "success": false, "message": "no branch assigned: please contact the owner to assign a branch" }
```
**Implikasi FE:** user non-owner yang belum di-assign cabang akan ke-block dari menu operasional. Tangani 403 ini (mis. tampilkan "hubungi owner untuk assign cabang"). Saat login, non-owner otomatis diarahkan ke salah satu cabang assigned-nya bila ada.

### Absensi diperketat
- `POST /attendance/check-in`: untuk non-owner, **branch diambil dari token** (field `branch_id` di form diabaikan untuk non-owner). Owner masih boleh kirim `branch_id`.
- `GET /attendance`, `/attendance/summary`, `/attendance/:id`: non-owner otomatis ter-filter ke cabangnya.

---

## 2. Kategori produk: toggle `freeable`

### Konsep
Kategori produk punya flag **`freeable`** (on/off). Hanya produk dari kategori yang `freeable = true` yang boleh dijadikan **item gratis** pada promo.

### Field baru
`ProductCategory` kini punya `freeable` (boolean, default `true`).

**POST `/product-categories`** / **PUT `/product-categories/:id`**
```json
// request (freeable opsional; default true saat create)
{ "name": "Minuman", "freeable": true }
```
**GET `/product-categories`** → tiap item kini menyertakan `freeable`:
```json
{ "id": 3, "name": "Minuman", "freeable": true, "created_at": "…" }
```

### Dampak ke POS (picker item gratis)
- FE picker item gratis sebaiknya **hanya menampilkan item di keranjang yang `product.category.freeable === true`**.
- `GET /products` & `GET /products/:id` menyertakan objek `category` (termasuk `freeable`), jadi FE bisa filter dari sana.
- Validasi backend saat checkout: jika item gratis dari kategori non-freeable → `422`:
```json
{ "success": false, "message": "free item category is not eligible for free items" }
```
(Aturan lama tetap: item gratis harus ada di keranjang, qty/harga tidak melebihi batas.)

---

## 3. Pembelian pakai template

### Konsep (perubahan besar pada form pembelian)
- Saat pembelian, user **tidak lagi mengetik harga maupun jumlah gram**. User **memilih template** (mis. "Pack" = 500 gram, "Lusin" = 1200 gram) dan **berapa banyak**.
- Harga diambil dari **master** (harga acuan tunggal per base unit). Template hanya konversi jumlah.

### Master material/topping kini punya `purchase_templates`
Dikelola **menyatu** saat create/update material/topping.

**POST `/materials`** / **PUT `/materials/:id`** (dan sama untuk `/toppings`)
```json
// request — tambahkan purchase_templates
{
  "name": "Teh",
  "unit": "gram",
  "purchase_qty": "500",        // isi 1 paket acuan (untuk harga)
  "purchase_price": "150000",   // harga paket acuan
  "purchase_templates": [
    { "name": "Pack",  "base_qty": "500" },
    { "name": "Lusin", "base_qty": "1200" }
  ]
}
```
- Pada **PUT**, jika `purchase_templates` dikirim → **ganti penuh** seluruh template. Jika **tidak dikirim** → template lama dibiarkan.
- `GET /materials`, `/materials/:id`, `/toppings`, `/toppings/:id` kini menyertakan:
```json
"purchase_templates": [
  { "id": 10, "material_id": 7, "name": "Pack",  "base_qty": "500" },
  { "id": 11, "material_id": 7, "name": "Lusin", "base_qty": "1200" }
]
```
- Data lama otomatis dapat 1 template **"Default"** (dari `purchase_qty` master).

### `POST /purchases` — request berubah
```json
// SEBELUM (lama): { material_id / topping_id, quantity, total_cost }
// SEKARANG:
{
  "supplier_id": 3,
  "items": [
    { "template_id": 11, "qty": 2 }
  ],
  "note": "restok mingguan"
}
```
- `template_id` = template yang dipilih; `qty` = jumlah template (**integer ≥ 1**).
- Backend menghitung sendiri: `base_unit = base_qty × qty` (masuk stok, dalam gram/ml), `total = base_unit × harga_per_unit_master`.
- Tidak ada lagi field `material_id`/`topping_id`/`quantity`/`total_cost` di request item.

Error baru: `404 "purchase template not found"` bila `template_id` tak dikenal.

### Response `GET /purchases/:id` — item kini menyertakan template & pack
```json
"items": [
  {
    "id": 50,
    "material_id": 7,
    "material": { "id": 7, "name": "Teh", "unit": "gram", … },
    "template_id": 11,
    "template": { "id": 11, "name": "Lusin", "base_qty": "1200" },
    "pack_qty": 2,            // berapa template dibeli
    "quantity": "2400.0000",  // hasil konversi ke base unit (gram)
    "unit_cost": "300.00",
    "subtotal": "720000.00"
  }
]
```
**Saran tampilan FE:** "2 Lusin (= 2400 gram)" dari `pack_qty` + `template.name` + `quantity`.

---

## 4. Master topping: field harga beli

`Topping` kini punya field harga beli (mirror material), dipakai untuk COGS topping & valuasi stok:

**POST `/toppings`** / **PUT `/toppings/:id`**
```json
{
  "name": "Oreo",
  "price": 3000,            // harga JUAL ke pelanggan (lama)
  "unit": "gram",
  "purchase_qty": "500",    // BARU: isi 1 paket beli
  "purchase_price": "150000", // BARU: harga 1 paket beli
  "usage_qty": "10",        // gram terpakai per 1 serving
  "purchase_templates": [ { "name": "Pack", "base_qty": "500" } ]
}
```
- `GET /toppings` kini menyertakan `purchase_qty`, `purchase_price`, dan `purchase_templates`.
- Pada PUT, `purchase_qty`/`purchase_price` **opsional** — hanya diubah bila dikirim (string non-kosong).

**Dampak FE:** tambahkan input `purchase_qty` & `purchase_price` di form master topping. Tanpa ini, COGS/laba topping = 0.

---

## 5. Role `produksi` hanya absensi

Role **`produksi`** sekarang **hanya** boleh mengakses endpoint absensi:
- ✅ `/attendance/check-in`, `/attendance/check-out`, `/attendance/me`, `/attendance/me/today`
- ✅ `/me`
- ❌ Semua endpoint lain → `403`:
```json
{ "success": false, "message": "forbidden: produksi role is limited to attendance" }
```

**Dampak FE:** untuk user role `produksi`, tampilkan **hanya menu absensi** (+ profil). Sembunyikan menu lain. (produksi tetap perlu di-assign cabang agar bisa check-in.)

---

## 6. Dashboard adaptif per role (`GET /dashboard`)

Satu endpoint, **isi menyesuaikan role** dari token. Data ter-scope cabang token (owner tanpa cabang = konsolidasi).

**`GET /dashboard?from=YYYY-MM-DD&to=YYYY-MM-DD`** (rentang opsional, default hari ini).

Response selalu memuat `role`, `from`, `to`, dan `branch_id` (jika ada), plus **section sesuai role**:

| Role | Section yang dikembalikan |
|---|---|
| `owner` | `operational`, `profit`, `top_products`, `per_branch[]` |
| `supervisor` | `operational`, `top_products`, `current_shift`, `team_attendance` |
| `finance` | `profit`, `payments`, `operational` |
| `leader` | `operational`, `top_products`, `team_attendance` |
| `kasir` | `current_shift` (omzet/transaksi/pembayaran shift), `recent_transactions` |
| `karyawan` | `operational`, `recent_transactions`, `attendance_today` + `attendance_history` |
| `produksi` | `attendance_today` + `attendance_history` |

Contoh (kasir):
```json
{
  "success": true,
  "data": {
    "role": "kasir",
    "from": "2026-06-29",
    "to": "2026-06-29",
    "branch_id": 2,
    "current_shift": {
      "id": 42, "cashier_name": "Andi", "opening_cash": 200000,
      "total_sales": 73000, "expected_cash": 255000, "status": "open",
      "payments": [ { "payment_method": "cash", "total": 55000 } ],
      "top_products": [ … ]
    },
    "recent_transactions": [ … ]
  }
}
```

Catatan:
- `operational` = struktur sama dengan `GET /dashboard/operational` (sales/purchases/expenses/net/chart/stock_alerts).
- `profit`, `payments`, `top_products` = struktur sama dengan endpoint `/reports/*` terkait.
- Non-owner (selain produksi) tanpa cabang → `403 "no branch assigned…"`.
- `produksi` hanya boleh endpoint ini + absensi (lihat §5).
- Endpoint lama `GET /dashboard/operational` masih ada (tidak dihapus).

---

## Checklist FE

- [ ] Tangani `403` "branch not assigned" pada switch-branch & "no branch assigned" pada menu operasional.
- [ ] Halaman assign cabang karyawan (`GET/PUT /employees/:id/branches`).
- [ ] Form kategori produk: tambah toggle `freeable`.
- [ ] Picker item gratis: filter hanya kategori `freeable`.
- [ ] Form master material & topping: kelola `purchase_templates` (nama + base_qty).
- [ ] Form master topping: tambah `purchase_qty` & `purchase_price`.
- [ ] Form pembelian: ganti input gram/harga → pilih template + qty.
- [ ] Tampilan riwayat pembelian: pakai `pack_qty` + `template.name` + `quantity`.
- [ ] Menu untuk role `produksi`: hanya absensi.
- [ ] Halaman dashboard: panggil `GET /dashboard` (1 endpoint), render section sesuai role + filter rentang tanggal.
