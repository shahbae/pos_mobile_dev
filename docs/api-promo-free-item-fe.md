# API: Item Gratis (Promo Buy X Get Y) — Panduan FE Mobile

## Ringkasan

Fitur **item gratis** memungkinkan kasir menggratiskan salah satu item **yang ada di keranjang** ketika sebuah promo aktif. Secara teknis:

> **Item gratis = barang yang tetap ada di keranjang, tetapi harganya dipotong jadi 0** (lewat `promo_discount`).

Item gratis **selalu** salah satu item yang dibeli pelanggan — bukan menambah barang baru di luar order. Stok & modal (COGS) item itu tetap tercatat normal karena ia tetap baris di order.

---

## Konsep Dasar

**"Beli 2 Gratis 1"** = pelanggan membayar **2 item**, lalu kasir memilih **1 menu lagi** sebagai item gratis → pelanggan dapat **3 item, bayar 2**. Item gratis bisa menu yang **berbeda** (selama kategorinya `freeable`).

```
Promo "Beli 2 Gratis 1" (aktif hari ini)
Keranjang (kasir tambahkan semua, termasuk item gratisnya):
  Kopi Susu     x2   @18.000   (dibayar)
  Original Tea  x1   @10.000   (dipilih sebagai gratis)

Kasir tandai Original Tea sebagai item gratis:
  Subtotal              46.000
  Promo (gratis)       -10.000
  ----------------------------
  Total                 36.000   (= bayar 2 Kopi Susu)
```

> Item gratis **tetap ditambahkan ke keranjang** (`items`) oleh kasir, lalu didaftarkan di `promo_free_items` agar harganya dipotong jadi 0. Pelanggan tetap menerima 3 barang.

Syarat sebuah item boleh dijadikan gratis:
1. **Item ada di keranjang** (qty gratis ≤ qty item itu di keranjang).
2. **Kategori produk `freeable = true`**.
3. **Ada promo yang aktif hari ini**, dan jumlah gratis **tidak melebihi quota**: tiap `buy_qty` item **dibayar** memberi `free_qty` gratis (berulang) → `(qty_dibayar ÷ buy_qty) × free_qty`, di mana `qty_dibayar = total item di keranjang − item gratis`.

> ⚠️ **Catatan:** Tidak ada lagi pembatasan "harga item gratis harus ≤ item termahal". Item gratis boleh berupa item apa pun di keranjang selama kategorinya `freeable` dan masih dalam quota.

---

## Alur di FE Mobile

```
1. GET /promos/active
   → kalau list TIDAK kosong, ada promo valid hari ini → aktifkan fitur item gratis.
     Server yang menentukan aktif/tidaknya (cek hari otomatis), FE tidak perlu hitung sendiri.

2. GET /products
   → tiap produk punya `category.freeable`.
     Item yang boleh digratiskan = item di keranjang yang `category.freeable == true`.

3. Saat checkout, kirim pilihan item gratis lewat field `promo_free_items`
   pada POST /product-transactions.
```

---

## Endpoints

### 1. Cek Promo Aktif Hari Ini

```
GET /promos/active
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Beli 2 Gratis 1",
      "buy_qty": 2,
      "free_qty": 1,
      "is_active": true,
      "days": [
        { "id": 5, "promo_id": 1, "day_of_week": 1 },
        { "id": 6, "promo_id": 1, "day_of_week": 5 }
      ],
      "created_at": "2026-06-01T08:00:00Z"
    }
  ]
}
```

- `day_of_week`: 0=Minggu … 6=Sabtu (mengikuti `time.Weekday` Go).
- Endpoint ini **hanya** mengembalikan promo yang aktif **hari ini** — kalau kosong, jangan tampilkan tombol item gratis.
- `buy_qty` & `free_qty` dipakai FE untuk menghitung **berapa item gratis yang boleh** (lihat rumus quota di bawah).

---

### 2. List Produk (sumber flag `freeable`)

```
GET /products
Authorization: Bearer <token>
```

**Response (potongan):**
```json
{
  "data": [
    {
      "id": 10,
      "name": "Original Tea",
      "selling_price": "10000.00",
      "category": { "id": 1, "name": "Tea", "freeable": true },
      "has_variants": false,
      "variants": []
    },
    {
      "id": 20,
      "name": "Kopi Susu",
      "selling_price": "18000.00",
      "category": { "id": 2, "name": "Coffee", "freeable": false },
      "has_variants": true,
      "variants": [ { "id": 99, "name": "Hot M", "selling_price": "18000.00" } ]
    }
  ]
}
```

> 🆕 **Field baru:** `category.freeable` (boolean) kini tersedia langsung di response produk.
> FE **tidak perlu** lagi join manual ke `/product-categories`.
> Produk tanpa kategori (`category` null) **tidak bisa** dijadikan item gratis.

---

### 3. Buat Transaksi dengan Item Gratis

```
POST /product-transactions
Authorization: Bearer <token>
```

**Request body:**
```json
{
  "payment_method": "cash",
  "paid": 20000,
  "items": [
    { "product_id": 10, "qty": 3 }
  ],
  "promo_free_items": [
    {
      "promo_id": 1,
      "product_id": 10,
      "variant_id": null,
      "qty": 1,
      "extra_toppings": []
    }
  ],
  "idempotency_key": "optional-unique-key"
}
```

**Field `promo_free_items[]`:**

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `promo_id` | uint | ✅ | ID promo aktif (dari `GET /promos/active`) |
| `product_id` | uint | ✅ | Produk yang digratiskan — **harus ada di `items`** |
| `variant_id` | uint/null | ➖ | Isi kalau produk pakai variant; harus salah satu variant yang ada di order |
| `qty` | int (min 1) | ✅ | Jumlah yang digratiskan — **≤ qty yang dibeli** & **≤ quota promo** |
| `extra_toppings` | array | ➖ | Topping tambahan dari item gratis yang ikut digratiskan (opsional) |

**Rumus quota (validasi di server):**
```
qty_dibayar = total item di keranjang − item gratis
maks_gratis = (qty_dibayar ÷ buy_qty) × free_qty
```
Item gratis adalah **tambahan** di atas item yang dibayar. Tiap `buy_qty` item dibayar memberi `free_qty` gratis, berlaku **berulang**.

Contoh promo **Beli 2 Gratis 1** (`buy_qty=2`, `free_qty=1`):

| Item dibayar | Maks gratis | Total item |
|---|---|---|
| 2 | 1 | 3 |
| 3 | 1 | 4 |
| 4 | 2 | 6 |
| 6 | 3 | 9 |

> **Untuk FE:** saat kasir baru menaruh item (belum pilih gratis), `qty_dibayar` = jumlah item di keranjang. Jadi 2 item di keranjang → langsung tampilkan "1 item gratis tersedia".

**Response (struk):**
```json
{
  "data": {
    "invoice_no": "INV-20260630-0001",
    "items": [
      { "name": "Original Tea", "qty": 3, "price": 10000 }
    ],
    "subtotal": 30000,
    "discount": 0,
    "promo_discount": 10000,
    "promos": [
      { "name": "Beli 2 Gratis 1", "discount": 10000 }
    ],
    "tax": 0,
    "total": 20000,
    "paid": 20000,
    "change": 0,
    "payment_method": "cash"
  }
}
```

- `promo_discount` = total potongan dari semua item gratis.
- `promos[]` = rincian per promo (nama + nominal) untuk ditampilkan di struk.

---

## Daftar Error (HTTP 422)

| Pesan | Penyebab |
|---|---|
| `promo not applicable today` | Promo tidak ada / tidak aktif / tidak berlaku hari ini |
| `free item product must be in the order` | `product_id` item gratis tidak ada di `items` |
| `free item category is not eligible for free items` | Kategori produk `freeable = false` atau produk tanpa kategori |
| `free qty exceeds allowed amount` | `qty` gratis melebihi quota promo atau melebihi qty yang dibeli |

> Validasi **"harga ≤ item termahal" sudah dihapus** — error terkait harga item gratis tidak ada lagi.

---

## Checklist Implementasi FE

- [ ] Panggil `GET /promos/active` saat masuk halaman kasir → simpan `buy_qty`/`free_qty`.
- [ ] Tampilkan tombol/opsi "Gratiskan" hanya untuk item di keranjang yang `category.freeable == true`.
- [ ] Batasi jumlah item gratis sesuai rumus quota di sisi FE (UX), server tetap validasi ulang.
- [ ] Kirim pilihan via `promo_free_items` saat `POST /product-transactions`.
- [ ] Tampilkan `promo_discount` & `promos[]` di ringkasan + struk.
