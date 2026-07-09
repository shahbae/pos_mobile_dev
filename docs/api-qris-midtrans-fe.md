# API: QRIS Dinamis (Midtrans) — Panduan FE

Tanggal: 2026-07-09

## Ringkasan

Pembayaran **QRIS dinamis**: QR dibuat per transaksi dengan **nominal pas** = total belanja, lewat Midtrans. Berbeda dengan metode lain yang **sinkron** (submit → langsung dapat receipt), QRIS bersifat **asinkron**: kasir buat QR → pelanggan scan & bayar → backend konfirmasi lewat webhook → baru lunas.

**Perubahan FE hanya di alur QRIS.** Metode lain (`cash`, `transfer`, `debit`, `credit`, `ewallet`) **tidak berubah sama sekali**.

> Kapan alur dinamis ini aktif: hanya ketika backend sudah dikonfigurasi Midtrans. Kalau belum, `payment_method: "qris"` tetap berjalan seperti dulu (sinkron, kasir konfirmasi manual) dan mengembalikan receipt biasa — jadi FE harus siap menangani **dua bentuk response** pada endpoint charge (lihat di bawah).

> Format response standar: sukses `{"success": true, "data": ...}`, gagal `{"success": false, "message": "..."}`. Semua endpoint (kecuali webhook) butuh `Authorization: Bearer <token>` dan konteks cabang.

---

## Alur lengkap

```
[Bayar QRIS]
   │  POST /product-transactions  (payment_method: "qris")
   ▼
data.qris = { payment_ref, qr_string, qr_url, expires_at, status:"pending" }
   │
   ├─ render QR dari qr_string (atau tampilkan gambar qr_url)
   ├─ tampilkan hitung mundur ke expires_at
   │
   ▼  loop tiap ~3 detik
GET /qris-payments/{payment_ref}
   ├─ status "pending"   → lanjut poll
   ├─ status "paid"      → tampilkan data.receipt, cetak struk, STOP
   ├─ status "expired"   → layar gagal (QR kedaluwarsa), STOP
   └─ status "cancelled" → layar gagal (dibatalkan), STOP

[Tombol Batalkan]  → POST /qris-payments/{payment_ref}/cancel
```

---

## 1. Buat pembayaran (charge)

```
POST /product-transactions
```
Body **sama persis** dengan transaksi biasa, cukup set `payment_method: "qris"`. Field `paid` **tidak perlu dikirim** untuk QRIS (backend memakai total sebagai jumlah bayar).

**Request:**
```json
{
  "payment_method": "qris",
  "customer_name": "Budi",
  "items": [
    { "product_id": 12, "qty": 2, "extra_toppings": [{ "topping_id": 3, "qty": 1 }] }
  ],
  "plastics": [{ "plastic_id": 1, "qty": 1 }],
  "discount": 0
}
```

**Response A — QRIS dinamis aktif (201):** kembalikan **QR**, bukan receipt.
```json
{
  "success": true,
  "data": {
    "payment_ref": "ESC-1-20260709101500-9F3A",
    "status": "pending",
    "gross_amount": 25000,
    "qr_string": "00020101021226610014COM.GO-JEK.WWW...",
    "qr_url": "https://api.sandbox.midtrans.com/v2/qris/xxxx/qr-code",
    "expires_at": "2026-07-09T10:30:00+07:00"
  }
}
```

**Response B — Midtrans belum aktif / metode non-QRIS (201):** receipt biasa (seperti sekarang).
```json
{ "success": true, "data": { "invoice_no": "INV-20260709-0007", "total": 25000, "items": [ ... ], "...": "..." } }
```

**Cara FE membedakan:** jika `data.qr_string` / `data.payment_ref` ada → alur QR (Response A). Jika `data.invoice_no` ada → sudah lunas, langsung cetak (Response B).

Kemungkinan error (422): `product not ready: insufficient material stock` (stok bahan kurang — QR tidak dibuat), `no active shift for this branch`, dll — sama seperti transaksi biasa.

---

## 2. Cek status (polling)

```
GET /qris-payments/{payment_ref}
```
`{payment_ref}` = nilai dari langkah 1. Panggil berkala (**disarankan tiap ~3 detik**) sampai status bukan `pending`.

**Masih menunggu:**
```json
{ "success": true, "data": { "status": "pending", "expires_at": "2026-07-09T10:30:00+07:00" } }
```

**Sudah lunas — sertakan receipt lengkap:**
```json
{
  "success": true,
  "data": {
    "status": "paid",
    "receipt": {
      "invoice_no": "INV-20260709-0007",
      "created_at": "2026-07-09T10:12:03+07:00",
      "cashier_name": "Sari",
      "items": [ ... ],
      "plastics": [ ... ],
      "subtotal": 25000, "discount": 0, "promo_discount": 0,
      "total": 25000, "paid": 25000, "change": 0,
      "payment_method": "qris",
      "payment_ref": "ESC-1-20260709101500-9F3A",
      "store": { "name": "Es Teh Candi", "address": "...", "footer_note": "...", "complaint_note": "..." }
    }
  }
}
```

**Gagal / batal:**
```json
{ "success": true, "data": { "status": "expired" } }
{ "success": true, "data": { "status": "cancelled" } }
```

Nilai `status` yang mungkin: `pending`, `paid`, `expired`, `cancelled`, `denied`, `refunded`.

| status | Arti | Aksi FE |
|---|---|---|
| `pending` | Menunggu pembayaran | Lanjut polling |
| `paid` | Lunas | Tampilkan `receipt`, cetak, stop polling |
| `expired` | QR kedaluwarsa | Layar gagal + opsi ulangi, stop |
| `cancelled` | Dibatalkan kasir | Layar gagal, stop |
| `denied` | Ditolak gateway | Layar gagal, stop |
| `refunded` | Sudah di-refund | (biasanya muncul di riwayat, bukan saat bayar) |

---

## 3. Batalkan (cashier)

```
POST /qris-payments/{payment_ref}/cancel
```
Membatalkan QR yang masih `pending` (mis. pelanggan urung bayar). Backend memerintahkan Midtrans membatalkan QR **dan** mengembalikan stok yang tadi direservasi.

> Aman terhadap race: jika ternyata pelanggan sempat membayar tepat sebelum dibatalkan, backend akan **menghormati pembayaran** (jadi `paid`) alih-alih membatalkan. Karena itu, setelah menekan Batalkan, FE sebaiknya tetap **cek status sekali lagi** untuk memastikan hasil akhir.

**Response (200):**
```json
{ "success": true, "data": { "status": "cancelled" } }
```
Error: `404 payment not found`, `409 payment is not in a cancelable state` (sudah lunas/terminal).

---

## 4. Refund (Owner/Supervisor)

```
POST /qris-payments/{payment_ref}/refund
```
Me-refund transaksi yang sudah **lunas**. Body opsional:
```json
{ "reason": "salah pesanan" }
```
**Response (200):**
```json
{ "success": true, "data": { "status": "refunded" } }
```
Error: `404 payment not found`, `409 payment is not refundable` (belum lunas / bukan QRIS). Setelah refund, stok dikembalikan dan transaksi keluar dari laporan penjualan.

---

## Catatan penting untuk FE

- **`paid` tidak perlu dikirim pada QRIS** (opsional) — nominal QR = total otomatis, kembalian selalu 0. Jangan minta input jumlah bayar. (Untuk metode non-QRIS, `paid` tetap dipakai dan divalidasi `paid >= total`.)
- **Nomor invoice baru ada saat `paid`.** Selama `pending`, referensi transaksi adalah `payment_ref` (order_id). Jangan tampilkan/simpan invoice sebelum lunas.
- **Render QR**: pakai `qr_string` dengan package seperti `qr_flutter` (disarankan, tampil instan & tajam), atau tampilkan gambar dari `qr_url`.
- **Hitung mundur**: pakai `expires_at`. Saat lewat, hentikan polling dan tampilkan layar gagal (backend juga akan menandai `expired`).
- **Interval polling** ~3 detik cukup. Hentikan begitu status ≠ `pending`.
- **Retry pembayaran** (setelah expired/cancelled): buat transaksi baru (charge ulang) — akan menghasilkan `payment_ref` dan QR baru.
- **Idempotency** charge: kirim `idempotency_key` unik per percobaan bila FE menerapkan retry jaringan (opsional, sama seperti transaksi biasa).
```
