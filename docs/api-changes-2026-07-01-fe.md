# API Changes — 2026-07-01 (Panduan FE)

Ringkasan 3 perubahan backend hari ini. **Semua backward-compatible** (payload lama tidak error), tapi ada penyesuaian UX/handling yang perlu FE lakukan. Detail lengkap ada di doc masing-masing.

---

## 1. Slot topping gratis kini **per-variant** (bukan per-produk)

Doc lengkap: [`api-product-variant.md`](./api-product-variant.md)

**Apa yang berubah:**
- `ProductVariant` punya field baru **`free_topping_slots`** (number, default `0`).
- Jumlah topping gratis yang boleh dipilih per baris item diambil dari **variant** (kalau item pakai variant), atau dari **produk** (kalau tanpa variant — perilaku lama).

**Yang perlu FE lakukan:**
- [ ] Form Create/Update variant → tambah input `free_topping_slots`.
- [ ] Tampilkan/pakai `free_topping_slots` dari variant saat kasir memilih topping gratis.
- [ ] ⚠️ **Variant lama semua default `0`** → topping gratis tidak bisa dipakai sampai owner set nilainya. Perlu diinfokan ke owner.

**Payload transaksi:** tidak berubah (`free_toppings` / `extra_toppings` tetap sama).

---

## 2. Promo free item — item gratis dibatasi ke **item termurah** + topping tidak gratis

Doc lengkap: [`api-promo-free-item-fe.md`](./api-promo-free-item-fe.md)

**Apa yang berubah:**
- Item yang boleh digratiskan **harga dasarnya ≤ item termurah di keranjang** (harga dasar produk/variant, tanpa topping). Praktisnya hanya item termurah yang boleh gratis.
- Topping pada item gratis **tidak lagi digratiskan**. Field `extra_toppings` di `promo_free_items` masih diterima tapi **diabaikan**.

**Yang perlu FE lakukan:**
- [ ] Filter opsi "Gratiskan" → hanya tampilkan item yang harganya ≤ item termurah di keranjang.
- [ ] Handle error baru `422`: `"free item price exceeds the cheapest item in order"`.
- [ ] Jangan hitung/tampilkan topping item gratis sebagai gratis.

**Payload transaksi:** field sama (`promo_free_items`), jadi FE lama tetap jalan — tapi bisa kena error di atas kalau menggratiskan item mahal.

---

## 3. Buku besar (ledger) — filter per cabang untuk owner

Doc lengkap: [`api-ledger-and-breaking-changes.md`](./api-ledger-and-breaking-changes.md)

**Apa yang berubah:**
- `GET /reports/ledger` menerima query baru **`?branch_id`** (khusus owner).
  - tanpa param → konsolidasi semua cabang + array `branches` (perilaku lama).
  - `?branch_id=X` → data 1 cabang saja, array `branches` tidak muncul.
  - invalid / `0` → `400 invalid branch_id`.
- User yang sudah terikat cabang → `?branch_id` diabaikan (tetap terkunci cabang token).
- `stock_loss` kini ikut ter-scope saat filter cabang.

**Yang perlu FE lakukan:**
- [ ] (Opsional) Tambah dropdown pilih cabang di halaman buku besar untuk owner → kirim `?branch_id`.

**Tanpa perubahan FE:** endpoint tetap jalan seperti sekarang (konsolidasi).
