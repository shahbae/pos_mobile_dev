# Revisi Audit Stock (Panduan FE) — 2026-07-02

Refactor fitur **Stock Audit** (stok opname). Ada penyesuaian perilaku, kolom baru **`returned_qty`** (barang dikembalikan) + **`incoming_today`**, **2 endpoint baru** (edit & hapus draft), dan `incoming_today` juga muncul di **`GET /stock-levels`** & **`GET /topping-stock`** (§6). Sebagian besar payload lama tetap jalan, tapi ada beberapa aturan validasi baru yang bikin request lama bisa kena error — baca bagian ⚠️.

Envelope response standar: sukses `{ "success": true, "data": ... }`, error `{ "success": false, "message": "..." }`.

---

## Konsep singkat

Audit = hitung stok fisik lalu bandingkan dengan stok sistem.

- **Draft** dibuat (`POST`) → belum mengubah stok, hanya menyimpan snapshot `system_qty`, `physical_qty`, `returned_qty`, `incoming_today`, `diff`, `unit_value` per item.
- **Approve** (`POST .../approve`) → menerapkan selisih (+ return) ke stok, status jadi `approved`.
- Draft bisa **diedit/dihapus**; audit yang sudah `approved` **immutable**.

Akses: `Owner` & `Supervisor` untuk create/update/delete/approve; `Finance` ikut bisa read (list & get).

---

## 1. ⚠️ `physical_qty` bahan (material) HARUS bilangan bulat

Stok **bahan** disimpan sebagai integer, sedangkan **topping** boleh desimal.

- Item **material** dengan `physical_qty` desimal (mis. `"1.5"`) → ditolak **400 `"invalid input"`**.
- Item **topping** tetap boleh desimal (mis. `"1.5"`, `"0.25"`).

**Yang perlu FE lakukan:**
- [ ] Untuk input hitung fisik **bahan**, batasi ke bilangan bulat (step 1, tanpa desimal).
- [ ] Untuk **topping**, izinkan desimal.

Alasan: dulu desimal untuk bahan diterima tapi saat approve dibulatkan ke bawah diam-diam → stok & laporan selisih jadi tidak konsisten.

---

## 2. ⚠️ Item tidak boleh duplikat dalam satu audit

Material atau topping yang sama muncul lebih dari sekali dalam `items` → ditolak **400 `"duplicate item in audit"`**.

**Yang perlu FE lakukan:**
- [ ] Cegah user menambahkan baris bahan/topping yang sama dua kali (gabungkan jadi satu baris).

---

## 3. ⚠️ Approve kini "apply-delta", bukan "set-absolut"

Saat approve, stok **tidak** lagi ditimpa jadi persis `physical_qty`. Yang diterapkan adalah **selisih** hasil hitung (`diff = physical − system` saat hitung), ditambahkan ke stok terkini.

Efeknya: penjualan/pembelian yang terjadi **antara** hitung fisik dan approve **tetap terjaga**.

Contoh: hitung fisik = 8, stok sistem saat hitung = 10 → `diff = -2`. Lalu 3 terjual → stok = 7. Saat approve: `7 + (-2) = 5` (bukan 8).

**Konsekuensi baru:** kalau stok saat approve **kurang** dari jumlah yang harus dikurangi, approve gagal **409 `"insufficient stock to apply audit adjustment"`**.

**Yang perlu FE lakukan:**
- [ ] Handle error 409 ini di tombol Approve (tampilkan pesan, minta user cek/hitung ulang).
- [ ] (Rekomendasi UX) dorong approve segera setelah hitung fisik agar `diff` masih relevan.

---

## 3b. 🆕 Kolom `returned_qty` (barang dikembalikan) + `incoming_today`

Menangani barang yang **keluar cabang secara sah** — dibalikin/dikirim lagi, **bukan terjual & bukan hilang** — supaya tidak terbaca sebagai selisih/loss.

**Field baru per item:**
- **Input** `returned_qty` (string, opsional, default `"0"`) — jumlah yang dikembalikan. Bahan wajib bulat, topping boleh desimal. Tidak boleh negatif.
- **Output** `incoming_today` (string) — info **jumlah masuk (movement IN) untuk item itu di cabang tsb hari ini**. Read-only, hanya konteks buat auditor. "Hari ini" mengikuti timezone app, di-snapshot saat draft dibuat/di-update.

**Rumus selisih berubah** → `diff = physical_qty − (system_qty − returned_qty)`.
Artinya barang yang dikembalikan tidak lagi dihitung sebagai kekurangan.

**Contoh:** pagi masuk 4, terpakai 3.5, sisa 0.5 dibalikin.
`system_qty=0.5`, `physical_qty=0`, `returned_qty=0.5` → `diff = 0 − (0.5 − 0.5) = 0` (selisih 0, bukan loss 0.5). `incoming_today` akan menampilkan `4`.

**Saat approve**, stok dikurangi dua langkah terpisah (agar terlacak): movement **RETURN** sebesar `returned_qty`, lalu **ADJUST** sebesar `diff`. Return tetap diterapkan **walau `diff = 0`**.

**Yang perlu FE lakukan:**
- [ ] Tambah input opsional **"Dikembalikan"** per baris item (bahan integer, topping desimal).
- [ ] Tampilkan **`incoming_today`** sebagai info "masuk hari ini" di baris item.
- [ ] Tampilkan `diff` sebagai selisih akhir; barang dikembalikan tidak lagi jadi loss.
- [ ] Laporan loss (dashboard) otomatis sudah mengecualikan return — tidak ada aksi khusus.

**Backward-compatible:** kalau `returned_qty` tidak dikirim, dianggap `0` dan `diff` = perilaku lama (`physical − system`).

---

## 4. 🆕 Endpoint edit & hapus draft

Draft yang salah kini bisa diperbaiki tanpa harus bikin baru.

| Method | Path | Role | Keterangan |
|---|---|---|---|
| `PUT` | `/stock-audits/:id` | Owner, Supervisor | Ganti `notes` + `items` draft (snapshot dihitung ulang) |
| `DELETE` | `/stock-audits/:id` | Owner, Supervisor | Hapus draft beserta itemnya |

- Keduanya **hanya untuk draft**. Kalau audit sudah `approved` → **409 `"audit already approved"`**.
- `PUT` **tidak** mengubah `branch_id` (cabang audit tetap seperti saat dibuat). Body tidak perlu `branch_id`.

---

## 6. 🆕 `incoming_today` di endpoint stok (bahan **dan** topping)

Field **`incoming_today`** ditambahkan ke response daftar stok supaya FE bisa menampilkan "masuk hari ini" langsung di halaman stok (tanpa harus buka audit). Tersedia untuk **bahan** dan **topping**.

### 6a. Bahan — `GET /stock-levels`
Role: Owner, Supervisor, Leader, Finance.

**Response (list):**
```json
{
  "success": true,
  "data": [
    {
      "id": 8,
      "material_id": 5,
      "branch_id": 2,
      "qty_on_hand": 48,
      "updated_at": "2026-07-02T16:00:00Z",
      "incoming_today": 10
    }
  ]
}
```

Query 1 bahan (`GET /stock-levels?material_id=5`) → objek tunggal dengan bentuk sama (termasuk `incoming_today`).

- `incoming_today` bertipe **number/integer** (bahan integer).

### 6b. Topping — `GET /topping-stock`
Role: sama seperti akses topping-stock.

**Response (list):**
```json
{
  "success": true,
  "data": [
    {
      "id": 4,
      "topping_id": 3,
      "branch_id": 2,
      "qty": "12.5000",
      "topping": { "id": 3, "name": "Boba" },
      "incoming_today": "5.0000"
    }
  ]
}
```

- `incoming_today` bertipe **string desimal** (topping desimal). Beda tipe dari bahan — FE hati-hati parse.

**Catatan umum (bahan & topping):**
- `incoming_today` = total stok **masuk (movement IN: pembelian/stock-in)** untuk item itu **hari ini** (batas hari mengikuti timezone app). Bukan kolom tersimpan — dihitung per-request.
- **Owner tanpa `branch_id`** (view agregat): `incoming_today` dijumlah lintas semua cabang, konsisten dengan qty.
- Tidak ada stok masuk hari ini → `0` (`"0.0000"` untuk topping).

**Yang perlu FE lakukan:**
- [ ] Tampilkan kolom "Masuk hari ini" di halaman stok bahan (`/stock-levels`) & topping (`/topping-stock`).

**Backward-compatible:** hanya menambah field; struktur lama tidak berubah.

---

## Referensi Endpoint

### `GET /stock-audits`
Role: Owner, Supervisor, Finance. List audit (branch-scoped otomatis; owner bisa lihat semua). Item tidak di-include di list — ambil detail via `GET /stock-audits/:id`.

### `POST /stock-audits`
Role: Owner, Supervisor. Buat draft.

```json
{
  "branch_id": 2,
  "notes": "Opname akhir bulan",
  "items": [
    { "material_id": 5, "physical_qty": "48", "returned_qty": "2" },
    { "topping_id": 3, "physical_qty": "0", "returned_qty": "0.5" }
  ]
}
```

Aturan tiap item: tepat **salah satu** dari `material_id` atau `topping_id` (bukan keduanya, bukan kosong). `physical_qty` = string, tidak boleh negatif; untuk material harus bilangan bulat (lihat §1). `returned_qty` = string opsional (default `"0"`), tidak boleh negatif, bahan wajib bulat (§3b). Minimal 1 item, tanpa duplikat (§2). Sukses → **201**.

### `GET /stock-audits/:id`
Role: Owner, Supervisor, Finance. Detail + `items`.

```json
{
  "success": true,
  "data": {
    "id": 12,
    "branch_id": 2,
    "created_by": 7,
    "status": "draft",
    "notes": "Opname akhir bulan",
    "approved_by": null,
    "approved_at": null,
    "created_at": "2026-07-02T09:00:00Z",
    "items": [
      {
        "id": 30,
        "audit_id": 12,
        "material_id": 5,
        "topping_id": null,
        "item_name": "Gula",
        "system_qty": "50.0000",
        "physical_qty": "48.0000",
        "returned_qty": "2.0000",
        "incoming_today": "10.0000",
        "diff": "0.0000",
        "unit_value": "1200.00"
      }
    ]
  }
}
```

### `PUT /stock-audits/:id` (🆕)
Role: Owner, Supervisor. Body (tanpa `branch_id`):

```json
{
  "notes": "Koreksi angka gula",
  "items": [
    { "material_id": 5, "physical_qty": "49" }
  ]
}
```

Draft-only. Aturan item sama dengan create. Approved → 409.

### `DELETE /stock-audits/:id` (🆕)
Role: Owner, Supervisor. Draft-only. Sukses → `{ "success": true, "data": { "deleted": true } }`. Approved → 409.

### `POST /stock-audits/:id/approve`
Role: Owner, Supervisor. Terapkan selisih ke stok (apply-delta, §3). Idempotent-guard: approve kedua → 409. Sukses → audit dengan `status: "approved"`, `approved_by`, `approved_at` terisi.

---

## Ringkasan kode error

| Kode | Pesan | Kapan |
|---|---|---|
| 400 | `invalid input` | item tak valid / `physical_qty` bahan desimal / dua-duanya id kosong atau terisi |
| 400 | `duplicate item in audit` | material/topping sama muncul >1x |
| 400 | `branch_id is required` | branch tidak terselesaikan saat create |
| 400 | `items cannot be empty` | `items` kosong |
| 422 | `material not found` | `material_id` tidak ada |
| 404 | `not found` | audit id tidak ada |
| 409 | `audit already approved` | edit/hapus/approve pada audit yang sudah approved |
| 409 | `insufficient stock to apply audit adjustment` | apply-delta saat approve melebihi stok terkini |

---

## Checklist FE

- [ ] Input hitung fisik bahan = integer; topping = desimal.
- [ ] Tambah input opsional **`returned_qty`** ("Dikembalikan") per item (bahan integer, topping desimal).
- [ ] Tampilkan **`incoming_today`** ("masuk hari ini") per item sebagai info.
- [ ] Selisih akhir pakai `diff` (sudah memperhitungkan return).
- [ ] Cegah baris item duplikat.
- [ ] Tambah aksi **Edit draft** (`PUT`) & **Hapus draft** (`DELETE`), sembunyikan untuk audit `approved`.
- [ ] Handle 409 `insufficient stock...` di Approve.
- [ ] `physical_qty` & `returned_qty` dikirim sebagai **string**.
- [ ] Tampilkan `incoming_today` di halaman stok bahan (`GET /stock-levels`) & topping (`GET /topping-stock`), §6. Catat beda tipe: bahan integer, topping string desimal.
