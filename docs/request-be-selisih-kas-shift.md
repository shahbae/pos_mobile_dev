# Request ke BE: Selisih Kas saat Tutup Shift — 2026-07-03

Permintaan dari tim **aplikasi (FE)** ke tim **backend (BE)**.

Saat kasir menutup shift, aplikasi ingin menampilkan **selisih kas** (uang fisik di laci vs. kas yang seharusnya ada). Mohon BE menambahkan field selisih pada objek shift agar angkanya otoritatif dari server.

Envelope response standar tetap: sukses `{ "success": true, "data": ... }`, error `{ "success": false, "message": "..." }`.

---

## Konsep singkat

- **Kas Seharusnya** (`expected_cash`) = `opening_cash` + total penjualan **tunai** (metode `CASH` saja; non-tunai seperti TRANSFER/QRIS/DEBIT tidak masuk laci). Bila ada kas masuk/keluar manual atau refund tunai, ikut diperhitungkan di sini.
- **Selisih** (`difference`) = `closing_cash` − `expected_cash`.
  - **Positif = lebih** (uang fisik di laci lebih banyak dari seharusnya).
  - **Negatif = kurang** (uang fisik kurang).
  - **0 = sesuai**.

---

## 1. Field baru pada objek shift

Mohon tambahkan 2 field berikut:

| Field | Tipe | Arti |
|---|---|---|
| `expected_cash` | number (rupiah) | Kas seharusnya = `opening_cash` + penjualan tunai (+ kas masuk/keluar manual bila ada). |
| `difference` | number (rupiah) | Selisih = `closing_cash` − `expected_cash`. Positif = lebih, negatif = kurang. |

Alternatif nama `cash_difference` juga diterima aplikasi (app sudah handle kedua nama). Format boleh `number` atau `string` — parsing di app sudah defensif.

---

## 2. Endpoint yang perlu memuat field ini

- [ ] `PUT /shifts/current/close` — **prioritas utama** (dipakai untuk dialog ringkasan tutup shift).
- [ ] `GET /shifts` — **WAJIB kirim `difference`** (dan `expected_cash`). Halaman Riwayat Shift menampilkan selisih per shift, dan fallback hitung-lokal **tidak bisa dipakai di list** karena item list umumnya tidak memuat breakdown `payments` (lihat ⚠️ di bawah).
- [ ] `GET /shifts/current` — agar bisa tampilkan estimasi selisih pada shift aktif (opsional).
- [ ] Objek shift di `GET /dashboard` (`current_shift`) — agar kartu shift di dashboard konsisten.

> ⚠️ **Kenapa `difference` wajib di `GET /shifts`:** fallback lokal menghitung selisih dari `opening_cash + penjualan tunai` (penjualan tunai diambil dari breakdown `payments`). Kalau response list **tidak** menyertakan `payments`, app menganggap penjualan tunai = 0 sehingga selisih di riwayat jadi **salah** (hanya `closing_cash − opening_cash`). Agar riwayat akurat, BE harus mengirim `difference` langsung — **atau** ikut menyertakan `payments` per item pada `GET /shifts`.

---

## 3. Contoh response yang diharapkan

`PUT /shifts/current/close`:

```json
{
  "success": true,
  "data": {
    "id": 12,
    "opening_cash": 200000,
    "closing_cash": 1495000,
    "total_sales": 1500000,
    "expected_cash": 1500000,
    "difference": -5000,
    "net_cash": 1300000,
    "payments": [
      { "payment_method": "cash", "total": 1300000, "count": 18 },
      { "payment_method": "qris", "total": 200000, "count": 3 }
    ],
    "status": "closed",
    "opened_at": "2026-07-03T08:00:00+07:00",
    "closed_at": "2026-07-03T17:00:00+07:00"
  }
}
```

Pada contoh di atas: kas seharusnya `1.500.000` (kas awal 200rb + penjualan tunai 1.3jt), kas fisik `1.495.000`, jadi **selisih −5.000 (kurang)**.

---

## Catatan

- Aplikasi **sudah menghitung selisih secara lokal** sebagai fallback: `expected_cash = opening_cash + penjualan tunai (dari breakdown payments)` dan `difference = closing_cash − expected_cash`. Namun perhitungan lokal ini tidak tahu soal kas masuk/keluar manual maupun refund, jadi **angka dari BE yang jadi acuan resmi**. Begitu field BE tersedia, app otomatis pakai nilai server tanpa perubahan kode.
- Definisi "penjualan tunai" harus konsisten dengan yang dipakai `net_cash` supaya tidak membingungkan kasir.
