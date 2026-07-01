# API: Product Variant (Variasi & Ukuran Menu)

## Ringkasan

Fitur ini memungkinkan satu produk memiliki banyak **variasi** (contoh: "Hot S", "Hot M", "Ice S", "Ice M"). Setiap variasi punya harga sendiri dan bisa punya resep bahan baku sendiri.

**Backward-compatible:** Produk yang sudah ada **tanpa variasi** tetap bisa dibeli di POS — perilaku lama tidak berubah.

---

## Konsep Dasar

```
Product: "Kopi Susu"
├── Variant: "Hot S"  → Rp 15.000
├── Variant: "Hot M"  → Rp 18.000
├── Variant: "Ice S"  → Rp 16.000
└── Variant: "Ice M"  → Rp 20.000
```

- Variant **harus** unik namanya per produk (tidak boleh ada dua variant "Hot S" di produk yang sama)
- Variant bisa dinonaktifkan (`is_active: false`) tanpa dihapus
- Setiap variant bisa punya resep bahan baku sendiri (digunakan untuk deduct stok & kalkulasi COGS)
- Setiap variant punya **jumlah slot topping gratis sendiri** (`free_topping_slots`) — misal "Ice M" boleh 2 topping gratis, "Ice S" hanya 1

---

## Endpoints

### 1. List Variants

```
GET /products/:id/variants
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "product_id": 5,
      "name": "Hot S",
      "selling_price": "15000.00",
      "free_topping_slots": 1,
      "is_active": true,
      "created_at": "2026-01-01T00:00:00Z"
    },
    {
      "id": 2,
      "product_id": 5,
      "name": "Hot M",
      "selling_price": "18000.00",
      "free_topping_slots": 2,
      "is_active": true,
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

---

### 2. Create Variant

```
POST /products/:id/variants
Authorization: Bearer <token>
Role: Owner / Supervisor / Leader
```

**Request Body:**
```json
{
  "name": "Ice M",
  "selling_price": "20000",
  "free_topping_slots": 2,
  "is_active": true
}
```

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `name` | string | ✅ | Nama variasi, max 128 karakter. Harus unik per produk. |
| `selling_price` | string | ✅ | Harga jual (format string desimal, contoh: `"20000"` atau `"20000.00"`) |
| `free_topping_slots` | number | ❌ | Jumlah topping gratis yang boleh dipilih untuk variant ini. Default `0` (tidak boleh topping gratis). Tidak boleh negatif. |
| `is_active` | boolean | ❌ | Default `true` |

**Response (201):**
```json
{
  "data": {
    "id": 3,
    "product_id": 5,
    "name": "Ice M",
    "selling_price": "20000.00",
    "free_topping_slots": 2,
    "is_active": true,
    "created_at": "2026-06-16T10:00:00Z"
  }
}
```

**Error Codes:**
| Status | Pesan | Penyebab |
|---|---|---|
| 400 | `invalid input` | `name` kosong atau `selling_price` tidak valid |
| 404 | `product not found` | Product ID tidak ditemukan |
| 409 | `variant name already exists for this product` | Nama variant sudah ada di produk ini |

---

### 3. Get Variant

```
GET /products/:id/variants/:vid
Authorization: Bearer <token>
```

**Response:** sama dengan object di List.

---

### 4. Update Variant

```
PUT /products/:id/variants/:vid
Authorization: Bearer <token>
Role: Owner / Supervisor / Leader
```

**Request Body:** sama dengan Create.

**Notes:**
- Semua field harus dikirim ulang (full replace, bukan patch)
- `is_active: false` untuk menonaktifkan variant

---

### 5. Delete Variant

```
DELETE /products/:id/variants/:vid
Authorization: Bearer <token>
Role: Owner / Supervisor / Leader
```

**Response:**
```json
{ "data": { "message": "deleted" } }
```

---

### 6. Get Variant Recipe (Resep Bahan Baku)

```
GET /products/:id/variants/:vid/recipe
Authorization: Bearer <token>
Role: Owner / Supervisor / Leader / Finance
```

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "variant_id": 3,
      "material_id": 10,
      "material": {
        "id": 10,
        "name": "Susu UHT",
        "unit": "ml"
      },
      "quantity": "200.000"
    }
  ]
}
```

---

### 7. Set Variant Recipe (Replace All)

```
PUT /products/:id/variants/:vid/recipe
Authorization: Bearer <token>
Role: Owner / Supervisor / Leader
```

**Request Body:** array of recipe items (replace semua resep, kirim array kosong `[]` untuk hapus semua).

```json
[
  { "material_id": 10, "quantity": "200" },
  { "material_id": 12, "quantity": "20" }
]
```

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `material_id` | number | ✅ | ID bahan baku yang sudah ada |
| `quantity` | string | ✅ | Jumlah bahan per sajian (desimal, max 4 angka di belakang koma) |

**Response:** array resep terbaru.

---

## Perubahan di POS Transaction

### POST /product-transactions

Field baru di tiap item: **`variant_id`** (opsional).

**Request Body (contoh dengan variant):**
```json
{
  "payment_method": "cash",
  "paid": 56000,
  "items": [
    {
      "product_id": 5,
      "variant_id": 3,
      "qty": 2,
      "extra_toppings": [
        { "topping_id": 1, "qty": 1 }
      ]
    },
    {
      "product_id": 8,
      "qty": 1
    }
  ],
  "idempotency_key": "order-abc-123"
}
```

**Aturan:**
- `variant_id` boleh tidak dikirim atau dikirim `null` → pakai harga & resep dari produk langsung (behavior lama)
- Jika `variant_id` dikirim:
  - Harga yang digunakan adalah `variant.selling_price`, **bukan** `product.selling_price`
  - Stok bahan baku yang dikurangi diambil dari resep variant (bukan resep produk)
  - Variant harus `is_active: true`, dan harus milik `product_id` yang dikirim
- Dua item dengan `product_id` sama tapi `variant_id` berbeda **tidak digabung** — tetap menjadi 2 baris terpisah di struk

### Slot Topping Gratis (per variant)

Jumlah topping gratis (`free_toppings`) yang boleh dipilih per baris item ditentukan oleh:
- **Line dengan `variant_id`** → pakai `variant.free_topping_slots`
- **Line tanpa `variant_id`** → pakai `product.free_topping_slots` (behavior lama, tidak berubah)

Contoh: jika variant "Ice M" punya `free_topping_slots: 2`, maka satu baris item Ice M boleh mengirim maksimal 2 `free_toppings`. Lebih dari itu → error `422 free topping slots exceeded`. Jika `free_topping_slots: 0` tapi kasir tetap mengirim `free_toppings` → error `422 free topping not allowed`.

> ⚠️ Variant yang sudah ada sebelum fitur ini di-set `free_topping_slots: 0` secara default. Set nilainya via Create/Update variant agar topping gratis bisa dipakai.

**Error baru:**
| Status | Pesan | Penyebab |
|---|---|---|
| 422 | `variant not found` | `variant_id` tidak ada |
| 422 | `variant is not active` | Variant sudah dinonaktifkan |
| 422 | `variant does not belong to product` | `variant_id` bukan milik `product_id` yang dikirim |

---

## Response Receipt — Perubahan

Field baru di tiap item di struk: **`variant_name`**.

```json
{
  "data": {
    "invoice_no": "INV-20260616-0001",
    "items": [
      {
        "name": "Kopi Susu",
        "variant_name": "Ice M",
        "qty": 2,
        "price": 20000,
        "toppings": []
      },
      {
        "name": "Pisang Goreng",
        "variant_name": null,
        "qty": 1,
        "price": 8000
      }
    ],
    "subtotal": 48000,
    "total": 48000,
    "paid": 56000,
    "change": 8000
  }
}
```

`variant_name` bernilai `null` jika item tidak menggunakan variant. FE bisa menampilkan nama item sebagai `"${name} - ${variant_name}"` jika variant ada.

---

## Contoh Flow Lengkap

### Setup (Admin)

```
1. Buat produk
   POST /products
   Body: { "name": "Kopi Susu", "selling_price": "0" }
   → product_id: 5

2. Buat variant
   POST /products/5/variants
   Body: { "name": "Hot S", "selling_price": "15000" }
   → variant_id: 1

   POST /products/5/variants
   Body: { "name": "Ice M", "selling_price": "20000" }
   → variant_id: 2

3. Set resep per variant (opsional)
   PUT /products/5/variants/1/recipe
   Body: [{ "material_id": 10, "quantity": "150" }]

   PUT /products/5/variants/2/recipe
   Body: [{ "material_id": 10, "quantity": "200" }, { "material_id": 15, "quantity": "100" }]
```

### Transaksi (Kasir)

```
POST /product-transactions
{
  "payment_method": "cash",
  "paid": 35000,
  "items": [
    { "product_id": 5, "variant_id": 1, "qty": 1 },
    { "product_id": 5, "variant_id": 2, "qty": 1 }
  ],
  "idempotency_key": "kasir-001-20260616-001"
}

→ Subtotal: 15.000 + 20.000 = 35.000
→ Receipt items:
   - Kopi Susu (variant_name: "Hot S") × 1 = 15.000
   - Kopi Susu (variant_name: "Ice M") × 1 = 20.000
```

---

## Dampak ke Report

### GET /reports/top-products

Response tiap row sekarang include `variant_id` dan `variant_name`. Produk yang sama dengan variant berbeda muncul sebagai baris terpisah.

```json
{
  "data": {
    "rows": [
      {
        "product_id": 5,
        "variant_id": 2,
        "name": "Kopi Susu",
        "variant_name": "Ice M",
        "sku": null,
        "qty_sold": 42,
        "revenue": "840000.00"
      },
      {
        "product_id": 5,
        "variant_id": 1,
        "name": "Kopi Susu",
        "variant_name": "Hot S",
        "sku": null,
        "qty_sold": 30,
        "revenue": "450000.00"
      },
      {
        "product_id": 8,
        "variant_id": null,
        "name": "Pisang Goreng",
        "variant_name": null,
        "sku": "PG-001",
        "qty_sold": 25,
        "revenue": "200000.00"
      }
    ]
  }
}
```

Produk tanpa variant: `variant_id` dan `variant_name` bernilai `null`.

---

## Catatan Penting untuk FE

1. **Tampilkan list variant** saat kasir memilih produk yang punya variant. Cek dengan `GET /products/:id/variants` dan filter yang `is_active: true`.

2. **Nama di struk** — gunakan kombinasi `name` + `variant_name`:
   ```
   if (item.variant_name) {
     display = `${item.name} - ${item.variant_name}`
   } else {
     display = item.name
   }
   ```

3. **Harga** di struk sudah final (harga variant, bukan harga produk). Tidak perlu FE melakukan kalkulasi ulang.

4. **Produk tanpa variant** — tetap bisa dipesan tanpa mengirim `variant_id`. Behavior lama tidak berubah.
