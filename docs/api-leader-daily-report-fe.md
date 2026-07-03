# Laporan Harian Leader — API untuk Frontend

Endpoint baru buat **role leader** (juga owner & supervisor) melihat rekap **1 hari** yang dipecah **per shift** (Shift 1 & Shift 2): trafik penjualan, total rupiah, item terjual, pengeluaran, dan bersih per shift.

> Format response standar: sukses `{"success": true, "data": ...}`, gagal `{"success": false, "message": "..."}`.

---

## Endpoint

```
GET /reports/leader/daily
```

- **Role**: `owner`, `supervisor`, `leader`.
- **Branch-scoped**: mengikuti cabang di token (non-owner **wajib** punya cabang). Owner bisa pakai `?branch_id=` untuk memilih cabang.
- **Query opsional** `date=YYYY-MM-DD` — default **hari ini** (timezone app).

Contoh:
```
GET /reports/leader/daily
GET /reports/leader/daily?date=2026-07-03
```

---

## Response

```json
{
  "success": true,
  "data": {
    "date": "2026-07-03",
    "branch_id": 2,
    "branch_name": "Cabang Depok",
    "shifts": [
      {
        "shift_id": 41,
        "shift_name": "Shift 1",
        "cashier_name": "Andi",
        "status": "closed",
        "opening_cash": 200000,
        "total_sales": 1500000,
        "total_items": 87,
        "transaction_count": 40,
        "cash_sales": 900000,
        "expenses": 120000,
        "net": 1380000
      },
      {
        "shift_id": 42,
        "shift_name": "Shift 2",
        "cashier_name": "Budi",
        "status": "open",
        "opening_cash": 200000,
        "total_sales": 1750000,
        "total_items": 95,
        "transaction_count": 48,
        "cash_sales": 1100000,
        "expenses": 50000,
        "net": 1700000
      }
    ],
    "totals": {
      "total_sales": 3250000,
      "total_items": 182,
      "transaction_count": 88,
      "expenses": 170000,
      "net": 3080000,
      "total_cash": 2000000
    },
    "chart": {
      "interval": "1hour",
      "points": [
        { "time": "2026-07-03T10:00:00+07:00", "shift_id": 41, "shift_name": "Shift 1", "revenue_total": 250000, "transactions": 6 },
        { "time": "2026-07-03T11:00:00+07:00", "shift_id": 41, "shift_name": "Shift 1", "revenue_total": 320000, "transactions": 8 },
        { "time": "2026-07-03T16:00:00+07:00", "shift_id": 42, "shift_name": "Shift 2", "revenue_total": 410000, "transactions": 9 }
      ]
    }
  }
}
```

### Field per shift (`shifts[]`)

| Field | Tipe | Arti |
|---|---|---|
| `shift_id` | int | ID shift |
| `shift_name` | string | Nama shift (mis. "Shift 1") |
| `cashier_name` | string | **Nama yang membuka shift** |
| `status` | string | `open` / `closed` |
| `opening_cash` | int (Rp) | **Modal awal** (dari master cabang) |
| `total_sales` | int (Rp) | **Total penjualan rupiah** (semua metode bayar) |
| `total_items` | int | **Total item terjual** (jumlah qty semua line item) |
| `transaction_count` | int | **Trafik**: jumlah transaksi |
| `cash_sales` | int (Rp) | **Cash tanpa modal awal** (uang tunai masuk dari penjualan cash) |
| `expenses` | int (Rp) | Pengeluaran yang tercatat saat shift ini buka |
| `net` | int (Rp) | **Bersih shift** = `total_sales − expenses` |

### Field total harian (`totals`)

| Field | Arti |
|---|---|
| `total_sales` | Jumlah `total_sales` semua shift |
| `total_items` | Jumlah `total_items` semua shift |
| `transaction_count` | Jumlah transaksi semua shift |
| `expenses` | Jumlah pengeluaran semua shift |
| `net` | Jumlah `net` semua shift |
| `total_cash` | **Total cash 2 shift** = Σ `cash_sales` (tanpa modal awal) |

### Grafik trafik penjualan (`chart`)

Time-series penjualan **per jam** sepanjang hari, tiap titik **ditandai shift**-nya. Untuk grafik garis Shift 1 vs Shift 2, FE tinggal group/warnai titik berdasarkan `shift_id` (atau `shift_name`).

| Field | Tipe | Arti |
|---|---|---|
| `interval` | string | Granularitas bucket, saat ini `"1hour"` |
| `points[].time` | string (RFC3339) | Awal jam bucket (timezone app) |
| `points[].shift_id` | int | Shift pemilik bucket ini |
| `points[].shift_name` | string | Nama shift (untuk label/warna) |
| `points[].revenue_total` | int (Rp) | Total penjualan pada jam itu |
| `points[].transactions` | int | Jumlah transaksi pada jam itu |

- Titik diurutkan **berdasarkan waktu**, lalu shift. Jam tanpa transaksi **tidak** menghasilkan titik (bukan 0) — kalau butuh sumbu-X penuh, FE isi jam kosong sendiri.
- Kalau satu jam berisi transaksi dari 2 shift (mis. pergantian shift), akan ada **2 titik** untuk jam itu dengan `shift_id` berbeda.
- `chart.points` = `[]` kalau belum ada transaksi.

---

## Catatan penting

- Kalau di tanggal itu belum ada shift, `shifts` = `[]` dan semua `totals` = `0`.
- **Pengeluaran diatribusikan ke shift** berdasarkan shift yang **sedang buka saat pengeluaran dicatat** (kolom baru `shift_id` di expenses). Pengeluaran yang dicatat saat tidak ada shift buka tidak masuk ke shift manapun (jadi tidak muncul di laporan per-shift ini).
- Semua nilai rupiah berupa **integer** (bukan string desimal), konsisten dengan field kas di endpoint shift.
- `total_cash` sengaja **tidak** memasukkan modal awal — hanya uang cash hasil penjualan kedua shift.
