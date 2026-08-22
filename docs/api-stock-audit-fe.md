# Stock Audit (Opname) — Perubahan API untuk FE

Ringkasan perubahan backend per 2026-08-08. Ada satu perubahan yang **wajib**
dikerjakan FE (daftar item opname), sisanya tambahan field dan penyesuaian role.

---

## 1. Item yang bisa diaudit sekarang dibatasi

Opname tidak lagi mencakup semua bahan/topping/plastik/sedotan. Hanya item yang
**dicentang owner** yang boleh masuk opname — saat ini teh & gula.

**FE tidak boleh menebak sendiri item mana.** Jangan hardcode nama "teh"/"gula":
daftarnya bisa berubah kapan saja lewat menu owner, tanpa rilis backend maupun
FE. Ambil dari endpoint di bawah.

### `GET /stock-audits/auditable-items`

Role: Owner, Supervisor, Leader, Kasir. Branch-scoped (ikut cabang aktif; owner
tanpa cabang aktif perlu `?branch_id=`).

Response `data` sudah lengkap untuk membangun form opname — tidak perlu
memanggil `/materials`, `/toppings`, `/plastics`, `/sedotans` lagi:

```json
[
  {
    "type": "material",
    "material_id": 7,
    "name": "Gula Pasir",
    "unit": "gram",
    "system_qty": "5000.0000",
    "incoming_today": "0.0000"
  },
  {
    "type": "material",
    "material_id": 9,
    "name": "Teh Tubruk",
    "unit": "gram",
    "system_qty": "1200.0000",
    "incoming_today": "500.0000"
  }
]
```

- `type` — `material` | `topping` | `plastic` | `sedotan`.
- Field id yang terisi mengikuti `type` (`material_id` / `topping_id` /
  `plastic_id` / `sedotan_id`); sisanya tidak dikirim. **Namanya sama persis
  dengan yang diminta `POST /stock-audits`**, jadi bisa diteruskan apa adanya.
- `system_qty` — stok menurut sistem di cabang tsb.
- Daftar bisa **kosong** kalau owner belum mencentang apa pun. Tampilkan pesan
  "belum ada item yang diatur untuk opname", jangan spinner selamanya.

### Kalau mengirim item yang tidak dicentang

`POST`/`PUT /stock-audits` membalas **422** `"item is not auditable"`.

---

## 2. Satu draft terbuka per cabang

`POST /stock-audits` membalas **409** `"branch already has an open draft audit"`
kalau cabang itu masih punya opname berstatus `draft` yang belum disetujui.

Ini mencegah opname tersimpan dobel saat tombol Simpan tertekan dua kali —
sebelumnya itu membuat stok terpotong dua kali. **Tetap pasang guard di FE**
(disable tombol setelah ditekan); 409 adalah jaring pengaman terakhir, bukan
pengganti.

Saran UX: saat kena 409, arahkan user ke draft yang sudah ada (via
`GET /stock-audits`) alih-alih menampilkan error mentah.

Slot terbuka kembali begitu draft disetujui atau dihapus.

---

## 3. Hak akses

| Aksi | Role |
|---|---|
| Lihat daftar & detail | Owner, Supervisor, Finance, Leader, Kasir |
| Buat / ubah / hapus draft | Owner, Supervisor, Leader, Kasir |
| Setujui (approve) | **Owner, Supervisor** |
| Atur item yang diaudit | **Owner, Supervisor** |

**Karyawan tidak lagi punya akses opname sama sekali** (sebelumnya bisa input).
Sembunyikan menunya untuk role tersebut.

### `PUT /stock-audits/auditable-items` — mengatur daftar item

Role: Owner, Supervisor saja. Sengaja lebih ketat daripada endpoint master data
biasa (yang Leader pun boleh), supaya orang yang menghitung tidak bisa
mengeluarkan item dari hitungan.

```json
{ "type": "material", "id": 7, "is_auditable": true }
```

`is_auditable` wajib dikirim eksplisit — `false` untuk melepas centang. Response
mengembalikan nilai yang tersimpan.

Field `is_auditable` juga ikut muncul di response `GET /materials`,
`/toppings`, `/plastics`, `/sedotans`, jadi checkbox di halaman master bisa
langsung diisi dari sana.

---

## 4. Field baru di item audit: `applied_delta` & `shortfall_qty`

Muncul di setiap item pada response `GET /stock-audits/:id` dan
`POST /stock-audits/:id/approve`.

Sejak sekarang approve **tidak pernah gagal karena stok kurang**. Kalau stok
yang tersedia lebih sedikit daripada yang harus dikurangi, stok berhenti di 0
(tidak minus, tidak membatalkan approve), dan sisanya dicatat:

- `applied_delta` — perubahan yang benar-benar masuk ke stok (negatif = keluar).
- `shortfall_qty` — bagian yang **tidak** bisa diterapkan. `0` = normal.

**`shortfall_qty > 0` wajib ditampilkan.** Artinya hasil hitung fisik dan catatan
penjualan saling bertentangan, dan cabang perlu diperiksa. Contoh kalimat:

> Sedotan Jumbo: diminta −160, diterapkan −30, stok berhenti di 0.

Kalau ini tidak ditampilkan, koreksinya berjalan senyap dan tidak ada yang
menyelidiki penyebabnya.

Catatan: `diff` **tidak** ikut dipangkas — nilainya tetap selisih hasil hitung,
jadi laporan kerugian tetap melaporkan angka penuh.

---

## 5. Riwayat audit lama — jangan diasumsikan hanya material

Audit yang dibuat sebelum perubahan ini bisa berisi item **topping, plastik, dan
sedotan**. Halaman detail/riwayat harus tetap bisa menampilkannya walaupun form
opname yang baru hanya menampilkan teh & gula.

Jangan menulis kode yang berasumsi `material_id` selalu terisi.

---

## 6. `photo_url` di daftar transaksi

`GET /transactions?type=expense` kini menyertakan `photo_url` (URL penuh foto
bukti) pada baris pengeluaran:

```json
{
  "id": 42,
  "transaction_type": "expense",
  "amount": "150000.00",
  "category": "operasional",
  "photo_url": "https://api.estehcandi.com/uploads/expenses/2026/08/abc.jpg"
}
```

- Hanya ada di baris `expense`. Baris `pos` dan `purchase` tidak membawa field
  ini sama sekali.
- Pengeluaran lama yang belum punya foto juga tidak membawa field ini — jadi
  perlakukan `photo_url` sebagai opsional.
