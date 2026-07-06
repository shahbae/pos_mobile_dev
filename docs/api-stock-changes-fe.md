# Perubahan API Stock (FE Guide)

Tanggal: 2026-07-05

Dokumen ini merangkum **dua perubahan** pada modul stok yang berdampak ke Frontend:

1. **Stok material jadi desimal** (sebelumnya integer) — menyamai topping & plastic.
2. **List stok kini punya `name`, `unit`, dan `packs[]`** — qty ditampilkan dalam kemasan (mis. "2 pack + 400 gram").

> Envelope semua endpoint: `{ "success": true, "data": ... }` (sukses) / `{ "success": false, "message": "..." }` (error). Semua butuh `Authorization: Bearer <token>`.

---

## 1. Stok material → desimal ⚠️ BREAKING

Dulu stok bahan disimpan sebagai **integer** (gram/pcs bulat). Sekarang **desimal** `decimal(18,4)`, konsisten dengan topping & plastic. Alasannya: resep memang memakai pecahan (mis. `12.5 gram`), dan perhitungan lama membulatkan ke atas sehingga stok tercatat habis lebih cepat dari kenyataan.

### Yang berubah untuk FE

**a) Response `GET /stock-levels` — `qty_on_hand` & `incoming_today` sekarang STRING**

| Field | Sebelum | Sekarang |
|---|---|---|
| `qty_on_hand` | number `2400` | string `"2400"` |
| `incoming_today` | number `2400` | string `"2400"` |

**b) Request mutasi — `qty` / `new_qty` sekarang STRING desimal**

Berlaku untuk:
- `POST /stock/adjust` → `new_qty`
- `POST /stock/increase` → `qty`
- `POST /stock/decrease` → `qty`

```jsonc
// SEBELUM
{ "material_id": 8, "new_qty": 2400, "reference_type": "manual" }

// SEKARANG
{ "material_id": 8, "new_qty": "2400.5", "reference_type": "manual" }
```

Kirim angka sebagai **string** (mis. `"12.5"`, `"2400"`). Nilai desimal kini diterima.

> **Aksi FE:** perlakukan semua qty stok (material, topping, plastic) sebagai **string desimal** — parse dengan util decimal yang sudah dipakai untuk topping/plastic. Jangan lagi berasumsi material integer.

---

## 2. `name`, `unit`, dan `packs[]` di list stok

Endpoint list stok kini meng-enrich tiap baris dengan **nama + satuan dasar** (tak perlu fetch master terpisah) dan **`packs[]`** — jumlah on-hand yang dinyatakan dalam kemasan `PurchaseTemplate`.

Berlaku seragam untuk **tiga** endpoint:

| Endpoint | ID field | qty field |
|---|---|---|
| `GET /stock-levels` (bahan) | `material_id` | `qty_on_hand` |
| `GET /topping-stock` | `topping_id` | `qty` |
| `GET /plastic-stock` | `plastic_id` | `qty` |

Semua qty di atas + semua angka di `packs[]` = **string desimal**. Scope cabang otomatis (non-owner → cabangnya; owner → agregat SUM lintas cabang, baris sintetis dengan `branch_id`/`id` bisa 0).

### Field `packs[]`

Satu entri per template kemasan milik item. Item tanpa template → `packs: []`.

| Field | Tipe | Arti |
|---|---|---|
| `template_id` | integer | ID template kemasan |
| `name` | string | Nama kemasan (`"Pack"`, `"Galon"`, `"Dus"`, …) |
| `base_qty` | string desimal | Unit dasar per 1 kemasan |
| `whole` | string desimal | Kemasan utuh = `floor(qty / base_qty)` |
| `remainder` | string desimal | Sisa unit dasar setelah kemasan utuh |
| `exact` | string desimal | `qty / base_qty` (dibulatkan 4 desimal) |

**Cara render di FE:**
- `"2 pack + 400 gram"` → `whole` + `remainder` + `unit`
- `"2.4 pack"` → `exact`

### Contoh — `GET /stock-levels`

Susu Full Cream stok `2400 gram`, 3 template (Sachet=200, Pack=1000, Dus=12000):

```json
{
  "success": true,
  "data": [
    {
      "id": 2,
      "material_id": 8,
      "branch_id": 1,
      "name": "Susu Full Cream",
      "unit": "gram",
      "qty_on_hand": "2400",
      "incoming_today": "2400",
      "updated_at": "2026-07-05T21:23:19.338+07:00",
      "packs": [
        { "template_id": 5, "name": "Sachet", "base_qty": "200",   "whole": "12", "remainder": "0",    "exact": "12" },
        { "template_id": 3, "name": "Pack",   "base_qty": "1000",  "whole": "2",  "remainder": "400",  "exact": "2.4" },
        { "template_id": 7, "name": "Dus",    "base_qty": "12000", "whole": "0",  "remainder": "2400", "exact": "0.2" }
      ]
    }
  ]
}
```

Filter satu material (`GET /stock-levels?material_id=8`) → objek tunggal dengan bentuk sama.

### Contoh — `GET /topping-stock`

Boba stok `3500 gram`:

```json
{
  "success": true,
  "data": [
    {
      "topping_id": 12,
      "branch_id": 1,
      "name": "Boba",
      "unit": "gram",
      "qty": "3500",
      "incoming_today": "3500",
      "packs": [
        { "template_id": 9, "name": "Pack", "base_qty": "1000", "whole": "3", "remainder": "500", "exact": "3.5" }
      ]
    }
  ]
}
```

`GET /plastic-stock` identik, hanya `plastic_id` (biasanya `unit: "pcs"`, `base_qty` bulat).

---

## Ringkasan checklist FE

- [ ] Perlakukan `qty_on_hand`/`qty`/`incoming_today` material sebagai **string desimal** (bukan number).
- [ ] Ubah body `POST /stock/adjust|increase|decrease` → kirim `qty`/`new_qty` sebagai **string**.
- [ ] Hapus fetch master terpisah untuk nama/unit di halaman stok — pakai `name`/`unit` dari response.
- [ ] Tampilkan `packs[]` untuk konversi kemasan; fallback ke `qty + unit` jika `packs` kosong.
- [ ] Komponen tabel stok bisa **satu** untuk material/topping/plastic (bentuk seragam), beda hanya `*_id` & nama qty field.
