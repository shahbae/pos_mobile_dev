# API: Uang Laci Otomatis dari Master Cabang — Panduan FE

Tanggal: 2026-07-03

## Ringkasan

**Uang laci (opening cash)** saat buka shift kini **otomatis** diambil dari master cabang, dan **bisa beda per cabang**. Ada field baru `default_opening_cash` di master cabang. Saat buka shift, FE **tidak lagi mengirim** `opening_cash` — nilainya di-set backend dari master cabang, dan kasir **tidak bisa meng-override**.

> Format response standar: sukses `{"success": true, "data": ...}`, gagal `{"success": false, "message": "..."}`.

Dampak ke FE — dua area:

1. [Master cabang: field `default_opening_cash`](#1-master-cabang-field-default_opening_cash)
2. [Buka shift: `opening_cash` dihapus dari request](#2-buka-shift-opening_cash-dihapus-dari-request)

---

## 1. Master cabang: field `default_opening_cash`

Field baru di objek cabang, nilai rupiah (integer), `>= 0`, default `0`.

| Field | Tipe | Keterangan |
|---|---|---|
| `default_opening_cash` | integer (rupiah) | Uang laci awal yang dipakai otomatis saat buka shift di cabang ini. `>= 0`, default `0`. |

### Muncul di semua response cabang

`GET /branches`, `GET /branches/:id`, dan response create/update sekarang memuat `default_opening_cash`.

```json
{
  "success": true,
  "data": {
    "id": 2,
    "name": "Cabang Bekasi",
    "address": "Jl. ...",
    "attendance_radius": 100,
    "default_opening_cash": 200000,
    "status": "active",
    "created_at": "2026-07-03T10:00:00Z"
  }
}
```

### POST `/branches` — create cabang
Akses: **Owner, Supervisor** (sesuai izin cabang existing).

```json
// request
{
  "name": "Cabang Bekasi",
  "address": "Jl. ...",
  "default_opening_cash": 200000
}
```
- `default_opening_cash` **opsional**. Jika tidak dikirim → `0`.
- Nilai `< 0` → `400 { "success": false, "message": "invalid input" }`.

### PUT `/branches/:id` — update cabang
```json
// request
{
  "name": "Cabang Bekasi",
  "default_opening_cash": 250000
}
```
- **Partial**: `default_opening_cash` hanya diubah bila field dikirim. Kalau field tidak disertakan, nilai lama dipertahankan.
- Nilai `< 0` → `400 invalid input`.

### Yang perlu FE lakukan
- Tambahkan input **"Uang laci default"** (`default_opening_cash`) di form master cabang (create & edit).
- Tampilkan nilai per cabang di list/detail cabang bila perlu.

---

## 2. Buka shift: `opening_cash` dihapus dari request

### POST `/shifts` — buka shift
Yang berubah di sini **hanya** soal `opening_cash`. FE **tidak perlu mengirim apa pun** untuk uang laci.

```json
// request — body boleh kosong
{}
```
- `opening_cash` yang dikirim FE **diabaikan** (bukan error, tapi tidak berpengaruh) — hapus saja dari request.
- Backend meng-set `opening_cash` shift = `default_opening_cash` cabang aktif saat itu.
- Body **opsional**: kirim `{}` atau bahkan tanpa body sama sekali — keduanya valid. Hanya JSON rusak yang → `400`.
- `shift_name` **opsional**. Kalau FE tidak mengirimnya, **BE mengisi otomatis** berdasarkan jam buka (waktu lokal cabang). Operasional 10:00–22:00, dua shift:

  | Jam buka | `shift_name` |
  |---|---|
  | 10:00–15:59 | `Shift 1` |
  | 16:00–21:59 | `Shift 2` |

  Kalau FE **mengirim** `shift_name` (mis. `"Shift 1"`), nilai itu yang dipakai (override). FE mobile tidak perlu menambah input — cukup biarkan kosong dan BE yang menamai.

```json
// response 201
{
  "success": true,
  "data": {
    "id": 12,
    "branch_id": 2,
    "cashier_id": 5,
    "shift_date": "2026-07-03T00:00:00Z",
    "shift_name": "Shift 1",
    "opening_cash": 200000,
    "closing_cash": null,
    "total_sales": 0,
    "status": "open",
    "opened_at": "2026-07-03T08:00:00+07:00",
    "closed_at": null
  }
}
```

| Status | Pesan | Penyebab |
|---|---|---|
| 201 | — | Shift terbuka, `opening_cash` terisi dari master cabang |
| 409 | `shift already open for this branch` | Sudah ada shift open di cabang tsb |
| 400 | `branch context required: please select a branch first` | Konteks cabang belum dipilih |

### Response GET `/shifts/current`, `/shifts/:id`, list
Tidak berubah bentuknya. `opening_cash` tetap ada dan sekarang berasal dari master cabang.

### Yang perlu FE lakukan
- **Hapus input uang laci** di modal buka shift. Cukup tampilkan nilai `default_opening_cash` cabang (read-only) bila ingin diperlihatkan ke kasir.
- Kirim `POST /shifts` tanpa `opening_cash`.

---

## Catatan migrasi
- Kolom `default_opening_cash` ditambahkan otomatis saat backend start. Cabang lama terisi `0` — set nilainya via master cabang bila perlu.
- Perubahan `opening_cash` di buka shift bersifat **breaking** untuk FE lama: nilai yang dikirim tidak lagi dipakai. Pastikan FE diperbarui agar kasir tidak bingung melihat uang laci berbeda dari yang diinput.
