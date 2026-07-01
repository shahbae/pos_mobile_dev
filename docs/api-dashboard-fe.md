# API: Dashboard (Adaptif per Role) — Panduan FE

## Ringkasan

Satu endpoint **`GET /dashboard`** yang isinya **menyesuaikan role** pemanggil. Data di-scope ke cabang token (owner tanpa cabang = konsolidasi semua cabang). Semua field bersifat **additive** — FE cukup merender blok yang relevan untuk role-nya.

```
GET /dashboard
Authorization: Bearer <token>
```

### Query Parameters

| Parameter | Tipe | Default | Keterangan |
|---|---|---|---|
| `from` | `YYYY-MM-DD` | Hari ini | Tanggal mulai (inklusif) |
| `to` | `YYYY-MM-DD` | Hari ini | Tanggal akhir (inklusif, dikonversi `to + 1 hari` internal) |

**Contoh:** `GET /dashboard?from=2026-07-01&to=2026-07-07`

### Field umum (selalu ada)

| Field | Keterangan |
|---|---|
| `role` | Role pemanggil |
| `from` / `to` | Rentang tanggal yang dipakai |
| `branch_id` | ID cabang token. Tidak muncul untuk owner konsolidasi. |

### Error

| Status | Pesan | Penyebab |
|---|---|---|
| 403 | `no branch assigned: please contact the owner to assign a branch` | Role non-owner (kecuali produksi) belum di-assign cabang |
| 400 | `invalid request` | Format `from`/`to` salah atau `to` ≤ `from` |

---

## Blok data per role

| Blok | Kasir | Leader | Supervisor | Finance | Owner | Karyawan | Produksi |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `operational` (+`net_sales`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| `current_shift` | ✅ | ✅ | ✅ | — | — | — | — |
| `recent_transactions` | ✅ | ✅ | — | — | — | ✅ | — |
| `top_products` | *(di shift)* | ✅ | ✅ | — | ✅ | — | — |
| `team_attendance` | — | ✅ | ✅ | — | — | — | — |
| `profit` | — | — | — | ✅ | ✅ | — | — |
| `payments` | — | — | — | ✅ | — | — | — |
| `per_branch` | — | — | — | — | ✅ | — | — |
| `attendance_today` / `attendance_history` | — | — | — | — | — | ✅ | ✅ |

> Fokus doc ini: **Kasir** & **Leader** (baru diperkaya). Keduanya kini punya blok inti yang sama: `operational` + `net_sales` + `current_shift` + `recent_transactions`. Leader **plus** `top_products` + `team_attendance`.

---

## Kasir

```json
{
  "data": {
    "role": "kasir",
    "from": "2026-07-01",
    "to": "2026-07-01",
    "branch_id": 2,
    "operational": {
      "date": "2026-07-01",
      "pos_sales": { "count": 50, "total_amount": "1250000.00" },
      "purchases": { "count": 3, "total_amount": "450000.00" },
      "expenses":  { "count": 2, "total_amount": "120000.00" },
      "net": "680000.00",
      "stock_alerts": { "threshold": 5, "rows": [] },
      "chart": {
        "interval": "3hour",
        "points": [
          { "time": "2026-07-01T06:00:00+07:00", "revenue_total": "150000.00", "transactions": 6, "purchases_total": "0.00", "purchases_count": 0 },
          { "time": "2026-07-01T09:00:00+07:00", "revenue_total": "220000.00", "transactions": 9, "purchases_total": "450000.00", "purchases_count": 1 }
        ]
      }
    },
    "net_sales": "1130000.00",
    "current_shift": {
      "id": 88,
      "shift_date": "2026-07-01",
      "shift_name": "Shift 1",
      "branch_name": "Cabang Bekasi",
      "cashier_name": "Siti",
      "opening_cash": 200000,
      "cash_sales": 850000,
      "expected_cash": 1050000,
      "closing_cash": null,
      "difference": null,
      "total_sales": 1250000,
      "status": "open",
      "opened_at": "2026-07-01T08:00:00+07:00",
      "payments": [
        { "payment_method": "cash", "count": 32, "total": 850000 },
        { "payment_method": "qris", "count": 18, "total": 400000 }
      ],
      "top_products": [
        { "product_id": 5, "variant_id": 2, "name": "Kopi Susu", "variant_name": "Ice M", "sku": null, "qty_sold": 24, "revenue": "480000.00" }
      ]
    },
    "recent_transactions": [
      { "id": 4821, "transaction_type": "pos", "amount": "36000.00", "created_at": "2026-07-01T04:32:11Z", "branch_id": 2, "branch_name": "Cabang Bekasi", "invoice_number": "INV-20260701-0042", "payment_method": "cash", "actor_name": "Siti" }
    ]
  }
}
```

### Peta field yang diminta bisnis → JSON

| Tampilan | Field | Contoh |
|---|---|---|
| Di shift berapa | `current_shift.shift_name` | "Shift 1" |
| Nama kasir (akun) | `current_shift.cashier_name` | "Siti" |
| Modal awal | `current_shift.opening_cash` | 200000 |
| **Cash** (tunai masuk) | `current_shift.cash_sales` 🆕 | 850000 |
| Kas seharusnya | `current_shift.expected_cash` | 1050000 (= modal awal + cash) |
| Trafik | `operational.chart.points[]` | grafik per 3 jam |
| Total penjualan | `operational.pos_sales.total_amount` | "1250000.00" |
| Total pengeluaran | `operational.expenses.total_amount` | "120000.00" |
| **Bersih** | `net_sales` 🆕 | "1130000.00" (= penjualan − pengeluaran) |
| Last transaction | `recent_transactions[]` | 5 transaksi POS terakhir |

---

## Leader

Sama seperti kasir (blok inti identik), **ditambah** `top_products` (level cabang, top 5) dan `team_attendance` (rekap absensi tim).

```json
{
  "data": {
    "role": "leader",
    "from": "2026-07-01",
    "to": "2026-07-01",
    "branch_id": 2,
    "operational": { "...": "sama struktur seperti kasir" },
    "net_sales": "1130000.00",
    "current_shift": { "...": "shift yang sedang OPEN di cabang leader (bisa null)" },
    "top_products": {
      "from": "2026-07-01",
      "to": "2026-07-01",
      "rows": [
        { "product_id": 5, "variant_id": 2, "name": "Kopi Susu", "variant_name": "Ice M", "sku": null, "qty_sold": 24, "revenue": "480000.00" },
        { "product_id": 8, "variant_id": null, "name": "Pisang Goreng", "variant_name": null, "sku": "PG-001", "qty_sold": 15, "revenue": "120000.00" }
      ]
    },
    "team_attendance": {
      "from": "2026-07-01",
      "to": "2026-07-01",
      "items": [
        { "user_id": 21, "user_name": "Siti", "user_role": "kasir", "total_days": 1, "shift_1_days": 1, "shift_2_days": 0, "middle_days": 0, "no_checkout_days": 0, "outside_radius_days": 0 }
      ]
    },
    "recent_transactions": [ { "...": "sama struktur seperti kasir" } ]
  }
}
```

> **`current_shift` untuk leader** = shift yang sedang **open** di cabangnya (bisa shift kasir lain). Kalau tidak ada shift open → `null`.

---

## Catatan penting untuk FE

1. **`current_shift` bisa `null`** (belum ada shift dibuka). Handle sebelum baca field di dalamnya.
2. **Beda tipe angka:** field di dalam `current_shift` (`opening_cash`, `cash_sales`, `expected_cash`, `total_sales`, `payments[].total`) adalah **integer rupiah**. Field di `operational`, `net_sales`, `recent_transactions.amount`, `top_products.revenue` adalah **string desimal** (`"1250000.00"`). Jangan campur saat parsing.
3. **`closing_cash` & `difference`** = `null` selama shift `open`; terisi setelah shift ditutup.
4. **`net_sales`** = `operational.pos_sales.total_amount − operational.expenses.total_amount` (penjualan − biaya operasional). **Beda** dari `operational.net` yang juga mengurangi pembelian bahan (`purchases`).
5. **Trafik** = `operational.chart.points[]`, bucket per **3 jam** (`interval: "3hour"`), `time` format RFC3339. Tiap titik punya `revenue_total` + `transactions` (jumlah transaksi).
6. Kasir & leader **wajib** punya cabang → kalau belum di-assign, endpoint balas `403`.

---

## Field baru (changelog)

| Field | Lokasi | Keterangan |
|---|---|---|
| `cash_sales` | `current_shift` (dan semua endpoint yang pakai shift summary) | Tunai masuk dari penjualan cash |
| `net_sales` | top-level dashboard (semua role yang punya `operational`) | Penjualan − biaya operasional |
| `operational`, `net_sales` | dashboard **kasir** | Blok baru untuk kasir (trafik + ringkasan) |
| `current_shift`, `recent_transactions` | dashboard **leader** | Blok baru untuk leader |
