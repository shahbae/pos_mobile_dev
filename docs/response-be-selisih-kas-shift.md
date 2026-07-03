# Balasan BE: Selisih Kas saat Tutup Shift — 2026-07-03

Menanggapi `docs/request-be-selisih-kas-shift.md`. **Semua sudah tersedia.** Field kas (`expected_cash`, `difference`, plus `cash_sales`) kini konsisten di seluruh objek shift.

> **✅ Sudah disinkronkan di app (2026-07-03).** `ShiftModel` membaca `cash_sales` (fallback `net_cash`), `expected_cash`, dan `difference`. Dialog tutup shift + Riwayat Shift + kartu shift aktif menampilkan Kas Seharusnya & Selisih (Lebih/Kurang/Sesuai). Kartu shift dashboard (`DashboardShift`) sudah lebih dulu memuat field ini.

Envelope standar tetap: sukses `{ "success": true, "data": ... }`, error `{ "success": false, "message": "..." }`.

---

## Definisi field

| Field | Tipe | Arti |
|---|---|---|
| `cash_sales` | number (rupiah) | Tunai bersih masuk laci = `SUM(paid − change_amount)` dari transaksi metode `cash`. |
| `expected_cash` | number (rupiah) | Kas seharusnya = `opening_cash + cash_sales`. |
| `difference` | number \| `null` | Selisih = `closing_cash − expected_cash`. Positif = lebih, negatif = kurang. **`null` selama shift masih `open`** (belum ada `closing_cash`). |

> Catatan penamaan: di contoh request FE ada `net_cash`; di response BE namanya **`cash_sales`** (nilai/konsep sama). Silakan baca `cash_sales`.

---

## Status per endpoint (checklist FE)

| Endpoint | Status |
|---|---|
| `PUT /shifts/current/close` | ✅ tersedia (`expected_cash`, `difference`, `cash_sales`) |
| `GET /shifts` (list) | ✅ **ditambahkan** — tiap item kini punya `cash_sales`, `expected_cash`, `difference` |
| `GET /shifts/current` | ✅ **ditambahkan** — aditif: semua field lama tetap ada, plus 3 field kas |
| `GET /shifts/:id` | ✅ tersedia |
| `GET /dashboard` → `current_shift` | ✅ tersedia |

**Konsistensi:** `difference` di `GET /shifts` dihitung dengan rumus yang sama seperti dialog tutup shift (`paid − change_amount`), jadi angka riwayat **cocok** dengan yang muncul saat shift ditutup. FE tidak perlu lagi fallback hitung-lokal di list.

---

## Contoh response

### `GET /shifts` (list)
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 12,
        "branch_id": 2,
        "cashier_id": 5,
        "shift_date": "2026-07-03",
        "shift_name": "Pagi",
        "opening_cash": 200000,
        "closing_cash": 1495000,
        "total_sales": 1500000,
        "cash_sales": 1300000,
        "expected_cash": 1500000,
        "difference": -5000,
        "status": "closed",
        "opened_at": "2026-07-03T08:00:00+07:00",
        "closed_at": "2026-07-03T17:00:00+07:00"
      }
    ],
    "total": 1,
    "page": 1,
    "limit": 20
  }
}
```
Shift yang masih `open`: `closing_cash` null dan `difference` **null**.

### `GET /shifts/current` (aditif — field lama tetap ada)
```json
{
  "success": true,
  "data": {
    "id": 12,
    "branch_id": 2,
    "cashier_id": 5,
    "shift_date": "2026-07-03T00:00:00Z",
    "shift_name": "Pagi",
    "opening_cash": 200000,
    "closing_cash": null,
    "total_sales": 0,
    "status": "open",
    "opened_at": "2026-07-03T08:00:00+07:00",
    "cash_sales": 1300000,
    "expected_cash": 1500000,
    "difference": null
  }
}
```
`difference` selalu `null` di `/shifts/current` karena shift belum ditutup — `expected_cash`/`cash_sales` berguna untuk estimasi laci berjalan.

---

## Catatan

- Angka BE adalah acuan resmi. Definisi "penjualan tunai" konsisten dengan `net_cash`/`cash_sales` yang dipakai dialog tutup shift.
- Belum dimodelkan: kas masuk/keluar manual & refund tunai terpisah. Saat ini `cash_sales` murni dari transaksi POS `cash` (`paid − change`). Jika nanti butuh, bisa ditambah sebagai fase berikutnya.
