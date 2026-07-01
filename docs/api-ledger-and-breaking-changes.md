# API Changes: Buku Besar Finance & Breaking Changes

Dokumen ini mencakup semua perubahan API yang perlu diketahui tim FE, mencakup:
1. Breaking change pada **Daily Report** (hapus baris `net`)
2. Breaking change pada **POS Transaction** (wajib shift aktif)
3. Perubahan response **Stock Audit** (field baru `unit_value`)
4. Endpoint baru **GET /reports/ledger**

---

## 1. Breaking Change — Daily Report

### `GET /reports/daily`

**Yang berubah:** Baris `"net"` **dihapus** dari array `rows`.

**Response lama:**
```json
{
  "data": {
    "date": "2026-06-17",
    "rows": [
      { "transaction_type": "expense", "count": 3, "total_amount": "120000.00" },
      { "transaction_type": "net",     "count": 1, "total_amount": "3880000.00" },
      { "transaction_type": "pos",     "count": 42, "total_amount": "4500000.00" },
      { "transaction_type": "purchase","count": 2, "total_amount": "500000.00" }
    ]
  }
}
```

**Response baru:**
```json
{
  "data": {
    "date": "2026-06-17",
    "rows": [
      { "transaction_type": "expense",  "count": 3,  "total_amount": "120000.00" },
      { "transaction_type": "pos",      "count": 42, "total_amount": "4500000.00" },
      { "transaction_type": "purchase", "count": 2,  "total_amount": "500000.00" }
    ]
  }
}
```

**Action FE:** Hapus logika yang membaca atau menampilkan row `transaction_type === "net"`. Kalau FE perlu angka net, gunakan endpoint `/reports/ledger` sebagai gantinya.

---

## 2. Breaking Change — Buat Transaksi POS

### `POST /product-transactions`

**Yang berubah:** Transaksi POS sekarang **wajib ada shift aktif** di cabang tersebut. Sebelumnya, transaksi bisa dibuat meskipun shift belum dibuka.

**Error baru (HTTP 422):**
```json
{
  "error": "no active shift for this branch"
}
```

**Action FE:**
- Sebelum membuka halaman kasir / form transaksi, cek dulu apakah ada shift aktif via `GET /shifts/current`.
- Jika tidak ada shift aktif, arahkan user (kasir/leader) ke halaman buka shift terlebih dahulu.
- Tambahkan handling untuk error `"no active shift for this branch"` di form transaksi.

---

## 3. Perubahan Response — Stock Audit Items

### `GET /stock-audits/:id`

**Yang berubah:** Setiap item di dalam `items` sekarang memiliki field baru `unit_value`.

**Response sebelumnya (per item):**
```json
{
  "id": 1,
  "audit_id": 5,
  "material_id": 3,
  "item_name": "Teh Celup",
  "system_qty": "100.0000",
  "physical_qty": "92.0000",
  "diff": "-8.0000"
}
```

**Response sekarang (per item):**
```json
{
  "id": 1,
  "audit_id": 5,
  "material_id": 3,
  "item_name": "Teh Celup",
  "system_qty": "100.0000",
  "physical_qty": "92.0000",
  "diff": "-8.0000",
  "unit_value": "1250.00"
}
```

**Keterangan field `unit_value`:**
- Untuk material: diambil dari `purchase_price` material saat audit dibuat
- Untuk topping: diambil dari `unit_cost` pembelian terakhir topping tersebut
- Nilai `"0.00"` berarti harga belum pernah diinput / tidak ada data pembelian

**Cara hitung nilai kerugian per item:**
```
loss_value = ABS(diff) * unit_value   (hanya jika diff < 0)
```

Contoh: `diff = -8`, `unit_value = 1250` → kerugian Rp 10.000

**Action FE:** Field ini opsional untuk ditampilkan. Bisa digunakan di halaman detail audit untuk menunjukkan estimasi nilai kerugian stok.

---

## 4. Endpoint Baru — Buku Besar Finance

### `GET /reports/ledger`

**Auth:** Bearer Token  
**Akses:** `owner`, `supervisor`, `finance`

#### Query Parameters

| Parameter | Tipe | Default | Keterangan |
|-----------|------|---------|------------|
| `from` | `YYYY-MM-DD` | Hari ini | Tanggal mulai (inklusif) |
| `to` | `YYYY-MM-DD` | Hari ini | Tanggal akhir (inklusif) |
| `branch_id` | `uint` | — | 🆕 **Hanya owner.** Filter ke satu cabang. Tanpa param → konsolidasi semua cabang. Diabaikan untuk user yang sudah terikat cabang. |

> `to` bersifat inklusif di input, dikonversi ke `to + 1 hari` secara internal.

**Contoh:**
```
GET /reports/ledger?from=2026-06-01&to=2026-06-30
GET /reports/ledger?from=2026-06-01&to=2026-06-30&branch_id=2   # owner, fokus 1 cabang
```

---

#### Perilaku Multi-Cabang

- **Owner / Supervisor** (JWT tanpa branch context):
  - **tanpa `?branch_id`** → data **konsolidasi semua cabang** + array `branches` berisi breakdown per cabang.
  - **dengan `?branch_id=X`** → 🆕 data **satu cabang** X saja; field `branches` **tidak muncul** (sama shape-nya dengan view per-cabang). `branch_id` tidak valid / `0` → `400 invalid branch_id`.
- **User dengan branch context** (Leader, Finance per cabang): mendapat **data cabang mereka saja**, field `branches` tidak muncul. `?branch_id` diabaikan (tetap terkunci ke cabang token).

> 🆕 `StockLoss` kini ikut difilter saat `?branch_id` diberikan (hanya kerugian stok cabang tsb). Pada view konsolidasi tetap gabungan semua cabang.

---

#### Response Shape

```json
{
  "data": {
    "from": "2026-06-01",
    "to": "2026-06-30",

    "revenue": {
      "gross": "45000000.00",
      "manual_discount": "1500000.00",
      "promo_discount": "800000.00",
      "net": "42700000.00"
    },

    "cogs": {
      "total": "15000000.00",
      "cogs_method": "recipe_snapshot"
    },

    "gross_profit": "27700000.00",

    "opex": {
      "purchases": {
        "material": "11000000.00",
        "topping": "3500000.00",
        "total": "14500000.00"
      },
      "expenses": [
        { "category": "sewa",    "total": "3000000.00" },
        { "category": "gaji",    "total": "2500000.00" },
        { "category": "listrik", "total": "1500000.00" }
      ],
      "expenses_total": "8000000.00",
      "total": "22500000.00"
    },

    "operating_profit": "5200000.00",

    "cash_reconciliation": {
      "shifts_count": 30,
      "total_opening_cash": "3000000.00",
      "total_closing_cash": "2980000.00",
      "total_difference": "-20000.00"
    },

    "purchase_vs_cogs": {
      "purchases_total": "14500000.00",
      "cogs_total": "15000000.00",
      "difference": "-500000.00"
    },

    "stock_loss": "125000.00",

    "branches": [
      {
        "branch_id": 1,
        "branch_name": "Cabang Utama",
        "revenue": { "gross": "...", "manual_discount": "...", "promo_discount": "...", "net": "..." },
        "cogs": { "total": "...", "cogs_method": "recipe_snapshot" },
        "gross_profit": "...",
        "opex": {
          "purchases": { "material": "...", "topping": "...", "total": "..." },
          "expenses": [ { "category": "sewa", "total": "..." } ],
          "expenses_total": "...",
          "total": "..."
        },
        "operating_profit": "...",
        "cash_reconciliation": {
          "shifts_count": 15,
          "total_opening_cash": "...",
          "total_closing_cash": "...",
          "total_difference": "..."
        },
        "purchase_vs_cogs": {
          "purchases_total": "...",
          "cogs_total": "...",
          "difference": "..."
        }
      }
    ]
  }
}
```

> `branches` hanya ada saat user melihat semua cabang (owner/supervisor tanpa branch context). Untuk user per-cabang, field ini tidak muncul.

---

#### Penjelasan Setiap Section

**`revenue`** — Rincian pendapatan dari transaksi POS

| Field | Keterangan |
|-------|-----------|
| `gross` | Total subtotal sebelum diskon (`SUM(subtotal)`) |
| `manual_discount` | Total diskon manual yang diinput kasir (`SUM(discount)`) |
| `promo_discount` | Total diskon dari promo (`SUM(promo_discount)`) |
| `net` | Pendapatan bersih yang diterima (`SUM(total)`) |

---

**`cogs`** — Harga Pokok Penjualan berdasarkan resep

| Field | Keterangan |
|-------|-----------|
| `total` | Total COGS dari resep semua produk yang terjual |
| `cogs_method` | Selalu `"recipe_snapshot"` — COGS diambil dari snapshot resep saat transaksi terjadi |

---

**`gross_profit`** — `revenue.net - cogs.total`

---

**`opex`** — Beban operasional

| Field | Keterangan |
|-------|-----------|
| `purchases.material` | Total pembelian bahan baku (material) di periode ini |
| `purchases.topping` | Total pembelian topping di periode ini |
| `purchases.total` | `material + topping` |
| `expenses` | Array pengeluaran dikelompokkan per kategori, diurutkan terbesar ke terkecil |
| `expenses_total` | Total semua pengeluaran |
| `total` | `purchases.total + expenses_total` |

---

**`operating_profit`** — `gross_profit - opex.total`

---

**`cash_reconciliation`** — Rekonsiliasi kas dari semua shift yang sudah ditutup di periode ini

| Field | Keterangan |
|-------|-----------|
| `shifts_count` | Jumlah shift yang sudah ditutup (`status = 'closed'`) |
| `total_opening_cash` | Total modal awal kas dari semua shift |
| `total_closing_cash` | Total kas fisik akhir yang dihitung kasir |
| `total_difference` | Selisih total: `closing_cash - (opening_cash + cash_sales)`. Negatif = kurang, positif = lebih |

> Hanya mencakup shift dengan status `closed`. Shift yang masih `open` tidak dihitung.

---

**`purchase_vs_cogs`** — Perbandingan realisasi pembelian vs COGS resep

| Field | Keterangan |
|-------|-----------|
| `purchases_total` | Total yang benar-benar dibeli di periode ini (uang keluar) |
| `cogs_total` | COGS yang dikonsumsi berdasarkan resep (teoritis) |
| `difference` | `purchases_total - cogs_total`. Positif = beli lebih dari yang dijual (stok naik / ada waste). Negatif = jual dari stok lama |

---

**`stock_loss`** — Estimasi nilai kerugian stok dari audit yang disetujui

Total nilai: `SUM(ABS(diff) * unit_value)` untuk item dengan `diff < 0` dari stock audit yang di-approve di periode ini.

Nilai `"0.00"` bisa berarti tidak ada audit di periode ini, atau semua item audit tidak memiliki `unit_value`.

> `stock_loss` selalu di level atas (top-level), tidak ada di dalam array `branches`. Nilainya mengikuti scope: **konsolidasi** = semua cabang; **dengan `?branch_id`** (atau user per-cabang) = cabang tsb saja.

---

#### Catatan Semua Nilai Desimal

Semua field bertipe uang menggunakan **string desimal** (bukan float), format `"0.00"`. Gunakan library desimal di sisi FE untuk operasi aritmatika (misal: `decimal.js`).

#### Error Responses

| Status | Error | Keterangan |
|--------|-------|------------|
| 400 | `"invalid request"` | Parameter `from`/`to` tidak valid atau `from >= to` |
| 401 | `"unauthorized"` | Token tidak valid / expired |
| 403 | `"forbidden"` | Role tidak memiliki akses (harus owner/supervisor/finance) |
| 500 | `"failed to get report"` | Error server |
