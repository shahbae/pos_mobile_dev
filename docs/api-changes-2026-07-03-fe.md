# Perubahan API untuk Frontend — 2026-07-03

Ketersediaan produk berdasarkan stok resep (**product readiness**). Dua dampak ke FE:

1. [Field baru `product_ready` & `is_ready` di list produk](#1-field-baru-di-get-products)
2. [POS menolak transaksi kalau bahan tidak cukup](#2-pos-menolak-produk-tidak-ready)

> Format response standar: sukses `{"success": true, "data": ...}`, gagal `{"success": false, "message": "..."}`.

---

## Konsep singkat

**Ready** = semua bahan di resep produk/varian **cukup stoknya** di cabang tersebut untuk membuat minimal 1 porsi.
- Produk **tanpa resep** → selalu `ready`.
- Produk **punya varian** → tiap varian dihitung sendiri (varian M bisa habis sementara XL ready). `product_ready` di level produk = `true` bila **minimal satu varian aktif ready**.
- Readiness **selalu relatif ke satu cabang** (stok per-cabang). Untuk owner yang melihat **semua cabang**, field bernilai `null` (tidak bisa dihitung lintas cabang).

---

## 1. Field baru di `GET /products`

Endpoint kini **branch-scoped** (mengikuti cabang di token, atau `?branch_id=` untuk owner — sama seperti endpoint stok).

### Field baru pada response

| Field | Tipe | Arti |
|---|---|---|
| `product_ready` | `bool \| null` | Produk bisa dijual di cabang ini. `null` = view semua cabang (tidak dihitung). |
| `variants[].is_ready` | `bool \| null` | Kesiapan tiap varian. `null` = view semua cabang. |

### Contoh — cabang spesifik (kasir, atau owner dgn `?branch_id=2`)
```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "name": "Kopi Susu",
      "selling_price": "18000.00",
      "has_variants": true,
      "product_ready": true,
      "variants": [
        { "id": 11, "name": "M",  "selling_price": "18000.00", "is_ready": false },
        { "id": 12, "name": "XL", "selling_price": "22000.00", "is_ready": true  }
      ]
    },
    {
      "id": 7,
      "name": "Teh Manis",
      "selling_price": "8000.00",
      "has_variants": false,
      "product_ready": false,
      "variants": []
    }
  ]
}
```

### Contoh — owner view semua cabang (`?branch_id=all` atau tanpa pilih cabang)
```json
{
  "id": 5,
  "name": "Kopi Susu",
  "has_variants": true,
  "product_ready": null,
  "variants": [
    { "id": 11, "name": "M",  "is_ready": null },
    { "id": 12, "name": "XL", "is_ready": null }
  ]
}
```

### Saran pemakaian di FE
- **Kartu produk**: kalau `product_ready === false` → tandai habis / non-aktifkan (abu-abu), tidak bisa ditambahkan ke keranjang.
- **Pilihan varian**: pakai `variants[].is_ready` untuk menonaktifkan pilihan varian tertentu (mis. M disabled, XL tetap bisa dipilih).
- **`null`**: jangan tampilkan indikator ready/habis (view lintas cabang). Kalau owner mau lihat status, arahkan pilih cabang dulu (`?branch_id=<id>`).

> Catatan: field lain di list produk tidak berubah. `product_ready`/`is_ready` juga muncul di endpoint single produk (`GET /products/:id`, create, update, upload image) tetapi **selalu `null`** di sana karena tanpa konteks cabang — jangan andalkan nilai readiness dari endpoint itu, gunakan `GET /products` (branch-scoped).

---

## 2. POS menolak produk tidak ready

Selain penanda visual, backend kini **menegakkan** di sisi transaksi.

`POST /pos/transactions` akan **ditolak** bila ada item yang stok bahannya tidak cukup:

```json
// response 422
{ "success": false, "message": "product not ready: insufficient material stock" }
```

- Cek dilakukan **per baris item / per varian** yang dipesan. Memesan **varian M** (habis) ditolak walaupun `product_ready` produknya `true` (karena XL ready).
- Bila ditolak, **tidak ada** transaksi tersimpan dan **tidak ada** stok terpotong (dibatalkan penuh).
- Berlaku untuk bahan/**material** di resep. (Stok **topping** belum ikut menghambat pada rilis ini.)

### Saran pemakaian di FE
- Idealnya cegah di UI lebih dulu pakai `product_ready`/`is_ready` supaya kasir tidak sampai submit item habis.
- Tetap **tangani response `422`** ini sebagai pengaman (mis. stok berubah sejak list dimuat): tampilkan pesan "Produk/varian ini stoknya habis", minta kasir refresh daftar produk.

---

## Perubahan perilaku internal (tidak berdampak langsung ke kontrak FE)

- Stok material **tidak boleh minus lagi** di seluruh operasi (sebelumnya penjualan POS diizinkan menembus stok/negatif). Konsekuensinya: penjualan yang melampaui stok kini gagal dengan `422` di atas, bukan diam-diam membuat stok minus.
