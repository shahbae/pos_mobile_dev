# FE Mobile — Role `finance`: Akses Absensi

**Status:** tidak ada perubahan API. Dokumen ini menjelaskan perilaku backend yang **sudah berjalan sekarang**, dipakai FE mobile untuk membangun flow "finance login di HP, akses absen saja".

**Jawaban singkat: YA, user dengan role `finance` bisa check-in & check-out absensi.** Yang **tidak** bisa absen justru **owner**.

---

## 1. Matriks akses absensi per role

| Endpoint | owner | supervisor | leader | **finance** | kasir | karyawan | produksi |
|---|---|---|---|---|---|---|---|
| `POST /attendance/check-in` | ❌ 403 | ✅ | ✅ | **✅** | ✅ | ✅ | ✅ |
| `POST /attendance/check-out` | ❌ 403 | ✅ | ✅ | **✅** | ✅ | ✅ | ✅ |
| `GET /attendance/me/today` | ✅ | ✅ | ✅ | **✅** | ✅ | ✅ | ✅ |
| `GET /attendance/me` | ✅ | ✅ | ✅ | **✅** | ✅ | ✅ | ✅ |
| `GET /attendance` (list semua) | ✅ | ✅ | ❌ | **❌ 403** | ❌ | ❌ | ❌ |
| `GET /attendance/summary` | ✅ | ✅ | ❌ | **❌ 403** | ❌ | ❌ | ❌ |
| `GET /attendance/:id` | ✅ | ✅ | ❌ | **❌ 403** | ❌ | ❌ | ❌ |
| `PATCH /attendance/:id` (koreksi) | ✅ | ✅ | ❌ | **❌ 403** | ❌ | ❌ | ❌ |

Artinya untuk finance: **hanya absensi diri sendiri**. Jangan panggil `GET /attendance`, `/attendance/summary`, `/attendance/:id`, atau `PATCH` — pasti `403 forbidden`.

---

## 2. Prasyarat WAJIB: user finance harus punya cabang

Ini penyebab paling umum absen gagal, dan **bukan** karena rolenya.

- Semua role non-owner (termasuk finance) **wajib** punya konteks cabang.
- `branch_id` **diambil dari JWT**, yang diisi saat login dari assignment cabang user (`user_branches`). FE tidak bisa mengaturnya lewat body.
- Kalau user finance belum di-assign ke cabang oleh owner, check-in/check-out akan gagal:

```json
HTTP 403
{ "error": "no branch assigned: please contact the owner to assign a branch" }
```

**Handling FE:** tampilkan pesan yang bisa ditindaklanjuti user, mis. _"Akun Anda belum ditugaskan ke cabang. Hubungi owner untuk assign cabang."_ — jangan tampilkan "akses ditolak", karena ini bukan masalah role.

**Cek di FE setelah login:** `GET /me` → kalau `branch_id` = `null`, tombol absen sebaiknya di-disable + tampilkan pesan di atas.

```json
GET /me → 200
{
  "data": {
    "id": 7,
    "branch_id": 3,
    "name": "Rina Finance",
    "email": "finance@jaia.id",
    "role": "finance",
    "status": "active",
    "created_at": "2026-05-02T09:00:00+07:00"
  }
}
```

> ⚠️ **Koreksi dokumen lama.** `docs/api-attendance.md` masih menulis "cukup kirim `branch_id` di body check-in, karyawan bebas absen di cabang mana pun". Itu **sudah tidak berlaku** untuk role non-owner. Backend sekarang **mengabaikan** field `branch_id` yang dikirim finance/kasir/leader/dll dan selalu memakai cabang dari token. Field `branch_id` hanya dibaca untuk owner & supervisor.

---

## 3. Flow yang disarankan di app (finance)

```
Login (POST /auth/login)
   └─ simpan access_token + refresh_token
GET /me
   ├─ role == "finance"      → tampilkan menu Absensi saja
   └─ branch_id == null      → disable tombol absen + pesan "belum ditugaskan ke cabang"
GET /attendance/me/today
   ├─ data == null                    → tampilkan tombol "Check-in"
   ├─ data.check_out_at == null       → tampilkan tombol "Check-out"
   └─ data.check_out_at != null       → tampilkan "Absensi hari ini selesai" (kedua tombol disabled)
GET /attendance/me?from=&to=&page=&limit=   → tab Riwayat absensi
```

Login response juga sudah membawa `user.branch_id` dan `user.role`, jadi `GET /me` boleh dilewati kalau FE menyimpan data login:

```json
POST /auth/login → 200
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": { "user_id": 7, "branch_id": 3, "role": "finance", "email": "...", "name": "..." }
  }
}
```

> Beda kecil tapi penting: di response login, `user.branch_id` memakai `omitempty` — kalau user belum punya cabang, **key-nya hilang sama sekali**, bukan `null`. Di `GET /me`, `branch_id` selalu ada dan bernilai `null`. Parser FE harus menganggap "key tidak ada" == "belum punya cabang".

---

## 4. Kontrak endpoint (identik dengan role lain)

### 4.1 `POST /attendance/check-in`

`Content-Type: multipart/form-data`, header `Authorization: Bearer <access_token>`.

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `photo` | file | Ya | Selfie masuk. Max **5 MB**. Ekstensi: `jpg`, `jpeg`, `png` saja. |
| `shift` | string | Ya | Salah satu: `shift_1`, `shift_2`, `middle`. |
| `latitude` | float | Ya | GPS saat absen (mis. `-6.200012`). |
| `longitude` | float | Ya | GPS saat absen. |
| ~~`branch_id`~~ | — | **Jangan kirim** | Diabaikan untuk finance; cabang diambil dari token. |

**Response 201:**

```json
{
  "data": {
    "id": 12,
    "user_id": 7,
    "branch_id": 3,
    "attendance_date": "2026-08-04",
    "shift": "shift_1",
    "check_in_at": "2026-08-04T08:14:23+07:00",
    "check_in_photo_url": "https://api.example.com/uploads/attendance/7/2026-08-04-in-a1b2c3d4.jpg",
    "check_in_lat": -6.200012,
    "check_in_lng": 106.81672,
    "check_in_status": "valid",
    "created_at": "2026-08-04T08:14:23+07:00"
  }
}
```

### 4.2 `POST /attendance/check-out`

`multipart/form-data`. Field: `photo`, `latitude`, `longitude` (semua wajib). **Tanpa** `branch_id` dan **tanpa** `shift` — keduanya diambil dari record check-in hari ini.

**Response 200:** shape sama, sudah terisi `check_out_at`, `check_out_photo_url`, `check_out_lat`, `check_out_lng`, `check_out_status`.

### 4.3 `GET /attendance/me/today`

Response 200 dengan `"data": null` kalau belum check-in hari ini. Ini sumber kebenaran untuk state tombol.

### 4.4 `GET /attendance/me`

Query: `from` (`YYYY-MM-DD`), `to`, `page` (default `1`), `limit` (default `20`, max `100`).

```json
{ "data": { "items": [ /* attendance shape */ ], "total": 22, "page": 1, "limit": 20 } }
```

---

## 5. Status geofence (`check_in_status` / `check_out_status`)

| Value | Arti | Saran tampilan |
|---|---|---|
| `valid` | Dalam radius cabang (`attendance_radius`). | Badge hijau "Dalam area". |
| `outside_radius` | Di luar radius — **absen tetap tersimpan** (geofence lunak), owner yang verifikasi. | Badge kuning "Di luar area", jangan diperlakukan sebagai error. |
| `no_branch_geo` | Cabang belum punya koordinat, geofence dilewati. | Badge netral / tidak usah ditampilkan. |

Penting: `outside_radius` **bukan** kegagalan. Response tetap `201`/`200`. Jangan blokir atau retry.

---

## 6. Tabel error & handling FE

| Kode | Body `error` | Penyebab | Aksi FE |
|---|---|---|---|
| `401` | `unauthorized` | Token invalid/expired. | Refresh token, lalu retry sekali; gagal → logout. |
| `403` | `no branch assigned: please contact the owner...` | Finance belum di-assign cabang. | Pesan khusus (lihat §2), tombol absen disabled. |
| `403` | `forbidden` | Endpoint memang bukan untuk finance (list/summary/detail/patch). | Jangan tampilkan menunya sama sekali. |
| `400` | `photo file is required` | Field `photo` kosong. | Validasi sebelum kirim. |
| `400` | `only jpg, jpeg, png are allowed` | Ekstensi salah (mis. `.heic` dari iPhone). | **Konversi ke JPEG di client.** |
| `400` | `photo must be ≤ 5MB` | File terlalu besar. | Kompres sebelum upload. |
| `400` | `shift is required (shift_1, shift_2, middle)` | `shift` kosong. | Wajib pilih shift di UI check-in. |
| `400` | `latitude is required` / `longitude is required` | GPS belum didapat / permission ditolak. | Minta izin lokasi dulu, blokir tombol sampai fix GPS didapat. |
| `400` | `invalid input` | `shift` di luar 3 nilai valid. | Pakai dropdown, bukan free text. |
| `400` | `branch is not active` | Cabang user statusnya non-aktif. | Pesan "Cabang tidak aktif, hubungi owner". |
| `400` | `not checked in yet` | Check-out tanpa check-in hari ini. | Re-sync `GET /attendance/me/today`. |
| `409` | `already checked in today` | Sudah absen masuk hari ini (1 row per user per hari). | Re-sync `me/today`, alihkan ke state check-out. |
| `409` | `already checked out today` | Sudah absen pulang. | Re-sync `me/today`, kunci tombol. |

Catatan `.heic`: kamera iOS default menghasilkan HEIC dan akan ditolak `400`. Pastikan pipeline foto di app mengeluarkan JPEG.

---

## 7. Catatan gating "akses absen saja"

Pembatasan finance menjadi **absen saja di mobile adalah keputusan FE**. Di backend, hanya role `produksi` yang dikunci hanya-absensi di level middleware. Token finance secara server masih bisa mengakses expense, reports, dashboard finance, dan read-only master data.

Konsekuensi praktis buat FE mobile:

- Sembunyikan seluruh menu selain Absensi untuk `role == "finance"` di app mobile — server tidak akan menolaknya.
- Kalau memang diinginkan hard-lock finance ke absensi-saja di sisi server (mis. supaya token mobile tidak bisa dipakai akses laporan), itu perubahan backend terpisah — ajukan ke tim BE, pola-nya sudah ada (`RestrictProduksiToAttendance`).

---

## 8. Checklist QA

- [ ] Login finance yang **punya** cabang → `GET /me` mengembalikan `branch_id` non-null.
- [ ] Check-in JPEG + GPS valid → `201`, `check_in_status` = `valid`.
- [ ] Check-in kedua kali di hari yang sama → `409 already checked in today`.
- [ ] Check-out → `200`, `check_out_at` terisi; check-out kedua → `409`.
- [ ] Check-out tanpa check-in → `400 not checked in yet`.
- [ ] Absen dari luar radius → tetap `201`, status `outside_radius`, UI tidak menampilkannya sebagai error.
- [ ] Login finance **tanpa** assignment cabang → `403 no branch assigned...`, pesan khusus muncul.
- [ ] Foto `.heic` → ditolak `400`; pastikan app sudah konversi ke JPEG.
- [ ] `GET /attendance` dari akun finance → `403` (dan menunya memang tidak ada di app).
