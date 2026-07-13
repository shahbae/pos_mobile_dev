# Auth & Refresh Token — Panduan Frontend

Tujuan: user **tidak perlu login ulang** selama refresh token masih berlaku. Tanggal: 2026-07-11.

## Durasi token

| Token | Durasi | Keterangan |
|---|---|---|
| Access token (JWT) | **60 menit** | Dari env `JWT_ACCESS_TTL_MINUTES`. Field `expires_in` (detik) di response. |
| Refresh token — biasa | 7 hari | Saat login dengan `remember_me: false`. |
| Refresh token — remember me | 30 hari | Default (jika `remember_me` tidak dikirim, dianggap `true`). |

Catatan: expiry refresh token **tidak diperpanjang** saat refresh — tetap dihitung sejak login pertama. Jadi setelah 7/30 hari user tetap harus login ulang (wajar).

## Login

`POST /auth/login`

```json
{ "email": "user@mail.com", "password": "secret", "remember_me": true, "device_id": "optional" }
```

Response (data):

```json
{
  "access_token": "…",
  "refresh_token": "…",
  "token_type": "Bearer",
  "expires_in": 3600,
  "user": { "user_id": 1, "branch_id": 1, "role": "cashier", "email": "…", "name": "…" }
}
```

Simpan `access_token` **dan** `refresh_token`.

## Memakai access token

Kirim di setiap request:

```
Authorization: Bearer <access_token>
```

## Refresh saat access token expired

`POST /auth/refresh`

```json
{ "refresh_token": "<refresh_token_tersimpan>" }
```

Response: **sama** dengan login (`access_token`, `refresh_token`, `expires_in`, `user` termasuk `branch_id`).

### ⚠️ Wajib diperhatikan

1. **Refresh token dirotasi.** Setiap refresh mengembalikan `refresh_token` **baru** dan me-*revoke* yang lama. FE **harus menimpa** refresh token tersimpan dengan yang baru. Jika tetap memakai yang lama → `401 invalid refresh token` → user terpaksa login ulang.
2. **`branch_id` ikut terbawa** setelah refresh (dipulihkan otomatis di backend dari cabang terakhir user). FE tidak perlu switch-branch lagi setelah refresh.
3. **Single-flight.** Kalau banyak request kena `401` bersamaan, panggil `/auth/refresh` **hanya sekali** (pakai mutex/antrian). Kalau tidak, request kedua memakai refresh token yang sudah dirotasi → gagal.

## Pola interceptor (pseudocode)

```
let refreshing = null   // promise tunggal (single-flight)

onResponse(res, req):
  if res.status != 401 or req._retried:
    return res

  if refreshing == null:
    refreshing = POST /auth/refresh { refresh_token: storage.refresh_token }
      .then(r => {
        storage.access_token  = r.access_token
        storage.refresh_token = r.refresh_token   // WAJIB timpa
        return r
      })
      .catch(e => { storage.clear(); goToLogin(); throw e })
      .finally(() => { refreshing = null })

  await refreshing
  req._retried = true
  req.headers.Authorization = "Bearer " + storage.access_token
  return retry(req)
```

## Logout

`POST /auth/logout` (butuh Authorization). Me-*revoke* semua refresh token user + meng-invalidasi access token yang ada. Setelah logout, FE hapus token lokal.

## Endpoint terkait

| Method | Path | Auth | Fungsi |
|---|---|---|---|
| POST | `/auth/login` | — | Login, dapat access + refresh token |
| POST | `/auth/refresh` | — | Tukar refresh token → token baru (rotasi) |
| POST | `/auth/logout` | Bearer | Revoke semua sesi user |
| GET  | `/me` | Bearer | Profil user + `branch_id` aktif |
| POST | `/auth/switch-branch` | Bearer | Ganti cabang aktif (non-owner: harus di-assign) |

## Error refresh

| Status | Arti | Aksi FE |
|---|---|---|
| 400 | request tidak valid | perbaiki payload |
| 401 | refresh token invalid/expired/revoked | hapus token, arahkan ke login |
| 500 | error server | tampilkan error, jangan auto-logout |
