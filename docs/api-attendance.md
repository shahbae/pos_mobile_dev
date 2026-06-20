# API — Absensi (Attendance)

Dokumen ini mencakup endpoint absensi karyawan: check-in/check-out dari mobile app, monitoring dari web FE Owner, koreksi manual oleh Owner, dan laporan ringkas.

Model data: **satu row per karyawan per hari** (`UNIQUE(user_id, attendance_date)`). Check-in membuat row baru, check-out meng-update row yang sama.

---

## Konsep penting

### Status check-in / check-out (geofence)

Disimpan di `check_in_status` dan `check_out_status`.

| Status | Arti |
|---|---|
| `valid` | Koordinat GPS user berada dalam radius `Branch.attendance_radius` dari titik cabang. |
| `outside_radius` | Di luar radius. Data tetap diterima (geofence lunak), Owner bisa lihat & verifikasi manual. |
| `no_branch_geo` | Cabang tidak punya koordinat (`latitude`/`longitude` null) — geofence dilewati. |

### Branch context

Branch tidak di-pre-assign ke karyawan. Setiap karyawan boleh absen di cabang mana pun selama statusnya `active`. Cukup kirim `branch_id` di body check-in. Saat check-out, `branch_id` diambil otomatis dari record check-in hari itu.

### Shift label

Setiap row absensi punya `shift` (string) untuk menandai shift karyawan hari itu. **Statis dari input** — bukan referensi ke model `Shift` POS, hanya label.

| Value | Arti |
|---|---|
| `shift_1` | Shift 1 (pagi) |
| `shift_2` | Shift 2 (sore) |
| `middle` | Middle (overlap antar-shift) |

Wajib dikirim saat check-in. Owner bisa koreksi via PATCH kalau salah pilih.

---

## 1. `POST /attendance/check-in` — Karyawan masuk

**Akses:** semua role kecuali Owner (Supervisor, Leader, Finance, Kasir, Karyawan, Produksi).

**Content-Type:** `multipart/form-data`

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `photo` | file | Ya | Selfie. Max 5 MB. Format: `jpg`, `jpeg`, `png`. |
| `branch_id` | int | Ya | ID cabang aktif yang dipilih user. |
| `shift` | string | Ya | Salah satu: `shift_1`, `shift_2`, `middle`. |
| `latitude` | float | Ya | GPS user saat scan. |
| `longitude` | float | Ya | GPS user saat scan. |

**Response 201:**
```json
{
  "data": {
    "id": 12,
    "user_id": 5,
    "branch_id": 1,
    "attendance_date": "2026-06-18",
    "shift": "shift_1",
    "check_in_at": "2026-06-18T08:14:23+07:00",
    "check_in_photo_url": "http://localhost:8080/uploads/attendance/5/2026-06-18-in-a1b2c3d4.jpg",
    "check_in_lat": -6.200012,
    "check_in_lng": 106.816720,
    "check_in_status": "valid",
    "created_at": "2026-06-18T08:14:23+07:00"
  }
}
```

**Error case:**

| Kode | Ketika |
|---|---|
| `400` | Field kurang/invalid, `branch_id` tidak ada, foto bukan jpg/png, ukuran > 5MB. |
| `400` | `branch is not active`. |
| `409` | Sudah ada record check-in hari ini untuk user yang sama. |

---

## 2. `POST /attendance/check-out` — Karyawan pulang

**Akses:** sama seperti check-in.

**Content-Type:** `multipart/form-data`

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `photo` | file | Ya | Selfie pulang. Spec sama dengan check-in. |
| `latitude` | float | Ya | GPS user saat scan pulang. |
| `longitude` | float | Ya | GPS user saat scan pulang. |

> `branch_id` **tidak** perlu — diambil otomatis dari record check-in hari ini.

**Response 200:** sama shape dengan check-in, tapi sudah terisi `check_out_*` fields:
```json
{
  "data": {
    "id": 12,
    "check_in_at": "2026-06-18T08:14:23+07:00",
    "check_in_status": "valid",
    "check_out_at": "2026-06-18T17:05:11+07:00",
    "check_out_photo_url": "http://localhost:8080/uploads/attendance/5/2026-06-18-out-e5f6g7h8.jpg",
    "check_out_lat": -6.200015,
    "check_out_lng": 106.816725,
    "check_out_status": "valid",
    ...
  }
}
```

**Error case:**

| Kode | Ketika |
|---|---|
| `400` | `not checked in yet` — tidak ada record check-in hari ini. |
| `409` | `already checked out today` — sudah pernah check-out. |

---

## 3. `GET /attendance/me/today` — Status absensi hari ini (self)

**Akses:** semua user authenticated.

**Response 200 (sudah check-in):** sama shape dengan check-in.

**Response 200 (belum check-in hari ini):**
```json
{ "data": null }
```

FE mobile bisa pakai endpoint ini saat app dibuka untuk tahu harus tampilkan tombol "Check-in" atau "Check-out".

---

## 4. `GET /attendance/me` — Riwayat absensi self

**Akses:** semua user authenticated.

**Query params:**

| Field | Tipe | Default | Keterangan |
|---|---|---|---|
| `from` | `YYYY-MM-DD` | — | Filter `attendance_date >= from`. |
| `to` | `YYYY-MM-DD` | — | Filter `attendance_date <= to`. |
| `page` | int | `1` | Pagination. |
| `limit` | int | `20` | Max `100`. |

**Response 200:**
```json
{
  "data": {
    "items": [/* attendance shape */],
    "total": 22,
    "page": 1,
    "limit": 20
  }
}
```

---

## 5. `GET /attendance` — List semua (Owner / Supervisor)

**Akses:** Owner + Supervisor.

**Query params:**

| Field | Tipe | Keterangan |
|---|---|---|
| `branch_id` | int | Filter per cabang. |
| `user_id` | int | Filter per karyawan. |
| `shift` | string | Filter `shift_1` / `shift_2` / `middle`. Invalid → 400. |
| `from` | `YYYY-MM-DD` | Inklusif. |
| `to` | `YYYY-MM-DD` | Inklusif. |
| `page` | int | Default `1`. |
| `limit` | int | Default `20`, max `100`. |

Response sama shape dengan `/attendance/me`.

---

## 6. `GET /attendance/:id` — Detail satu record

**Akses:** Owner + Supervisor.

**Response 200:** attendance shape lengkap.
**404:** kalau ID tidak ada.

---

## 7. `GET /attendance/summary` — Laporan agregat

**Akses:** Owner + Supervisor.

Agregasi per karyawan dalam rentang tanggal — cocok untuk dashboard mingguan/bulanan tanpa harus loop semua row di FE.

**Query params:**

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `from` | `YYYY-MM-DD` | Ya | Tanggal awal (inklusif). |
| `to` | `YYYY-MM-DD` | Ya | Tanggal akhir (inklusif). |
| `branch_id` | int | Tidak | Filter per cabang. |
| `user_id` | int | Tidak | Filter satu karyawan. |
| `shift` | string | Tidak | Filter `shift_1` / `shift_2` / `middle`. Invalid → 400. |

**Response 200:**
```json
{
  "data": {
    "from": "2026-06-01",
    "to": "2026-06-30",
    "items": [
      {
        "user_id": 5,
        "user_name": "Alam",
        "user_role": "kasir",
        "total_days": 22,
        "shift_1_days": 15,
        "shift_2_days": 5,
        "middle_days": 2,
        "no_checkout_days": 1,
        "outside_radius_days": 0
      }
    ]
  }
}
```

| Field | Arti |
|---|---|
| `total_days` | Jumlah hari karyawan tercatat check-in dalam rentang. |
| `shift_1_days` | Jumlah hari dengan `shift = "shift_1"`. |
| `shift_2_days` | Jumlah hari dengan `shift = "shift_2"`. |
| `middle_days` | Jumlah hari dengan `shift = "middle"`. |
| `no_checkout_days` | Jumlah hari di mana karyawan check-in tapi tidak check-out. |
| `outside_radius_days` | Jumlah hari dengan `check_in_status = outside_radius`. |

> **Catatan:** kalau pakai filter `?shift=shift_1`, breakdown tetap muncul tapi cuma `shift_1_days` yang terisi (lainnya `0`). `total_days` ikut menyusut sesuai filter.

---

## 8. `PATCH /attendance/:id` — Owner koreksi

**Akses:** Owner saja.

Dipakai untuk koreksi manual: karyawan lupa check-out, salah waktu, perlu update notes, dll.

**Body** — semua field opsional, hanya field yang **ada di JSON** yang di-apply (PATCH semantics):

| Field | Tipe | Keterangan |
|---|---|---|
| `check_in_at` | RFC3339 datetime | Override waktu check-in. |
| `check_out_at` | RFC3339 datetime | Set/override waktu check-out. |
| `check_in_status` | string | `valid` / `outside_radius` / `no_branch_geo`. |
| `check_out_status` | string | Sama. |
| `shift` | string | `shift_1` / `shift_2` / `middle`. |
| `notes` | string | Catatan koreksi (alasan, sumber verifikasi, dll). |

**Audit trail:** setiap PATCH otomatis mengisi `corrected_by` (user_id Owner) dan `corrected_at` (timestamp). Field ini muncul di response.

**Contoh — karyawan lupa check-out, Owner isi manual:**
```json
{
  "check_out_at": "2026-06-18T17:00:00+07:00",
  "check_out_status": "valid",
  "notes": "Lupa check-out, dikonfirmasi via CCTV"
}
```

**Response 200:** attendance shape lengkap, dengan `corrected_by` dan `corrected_at` terisi.

**Error case:**

| Kode | Ketika |
|---|---|
| `400` | Tidak ada field yang dikirim. Status tidak valid. |
| `404` | Record tidak ditemukan. |

> **Limitasi sekarang:** PATCH hanya bisa **set** value, **tidak bisa null-kan** field via `null` JSON (karena pointer ke time.Time tidak bisa bedakan null vs missing). Kalau perlu hapus check-out, butuh endpoint terpisah di masa depan.

---

## Shape lengkap response `attendance`

```json
{
  "id": 12,
  "user_id": 5,
  "branch_id": 1,
  "attendance_date": "2026-06-18",
  "shift": "shift_1",

  "check_in_at": "2026-06-18T08:14:23+07:00",
  "check_in_photo_url": "http://.../uploads/attendance/5/2026-06-18-in-a1b2c3d4.jpg",
  "check_in_lat": -6.200012,
  "check_in_lng": 106.816720,
  "check_in_status": "valid",

  "check_out_at": "2026-06-18T17:05:11+07:00",
  "check_out_photo_url": "http://.../uploads/attendance/5/2026-06-18-out-e5f6g7h8.jpg",
  "check_out_lat": -6.200015,
  "check_out_lng": 106.816725,
  "check_out_status": "valid",

  "notes": null,
  "corrected_by": null,
  "corrected_at": null,
  "created_at": "2026-06-18T08:14:23+07:00"
}
```

---

## Catatan implementasi

- **Foto disimpan** di `{UPLOAD_DIR}/attendance/{user_id}/{YYYY-MM-DD}-{in|out}-{random}.{ext}`, di-serve via static `/uploads`.
- **Timezone**: semua "hari ini" dihitung dari `APP_TIMEZONE` (default WIB). Late/early juga dihitung dengan timezone yang sama.
- **Tidak ada cron** untuk cleanup foto — kalau perlu retention policy, akan jadi phase berikutnya.
- **Shift overnight** (mis. 22:00–06:00) belum di-handle khusus — bisa jadi 2 row terpisah tanpa pair. Avoid kalau memungkinkan, atau buka issue baru kalau jadi kebutuhan rutin.
