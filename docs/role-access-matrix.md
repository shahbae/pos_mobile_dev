# Role Access Matrix

Dokumentasi otoritatif akses tiap role terhadap modul/endpoint sistem POS.
Sumber kebenaran: `cmd/server/main.go` (route registration).

---

## Daftar Role

Didefinisikan di `internal/roles/roles.go`.

| Role | Konstanta | Deskripsi |
|---|---|---|
| Owner | `roles.Owner` | Pemilik usaha. Akses penuh ke semua modul. Tidak ikut absensi. |
| Supervisor | `roles.Supervisor` | Pengawas operasional. Hampir setara Owner kecuali beberapa endpoint Owner-only. |
| Leader | `roles.Leader` | Kepala cabang. Operasional cabang penuh, tanpa akses reports/employees/attendance admin. |
| Finance | `roles.Finance` | Bagian keuangan. Read-only ke master data + akses penuh expense & reports. |
| Kasir | `roles.Kasir` | Operator kasir. Fokus POS, shift, transaksi. |
| Karyawan | `roles.Karyawan` | Karyawan umum. Bisa POS, shift, dan absensi. |
| Produksi | `roles.Produksi` | Staf produksi. Hanya POS + absensi. |

> `IsEmployee()` menganggap semua role kecuali `Owner` sebagai karyawan (untuk endpoint employee management).

---

## Ringkasan per Role

### Owner — Akses Penuh
Hampir semua endpoint. Endpoint yang **hanya Owner**:
- `POST /branches`, `PUT /branches/:id`, `PUT /branches/:id/status`
- `PATCH /attendance/:id` (koreksi absensi)

Owner **tidak** ikut absensi (tidak bisa `POST /attendance/check-in`).

### Supervisor — Operasional Penuh
Setara Owner kecuali:
- Tidak bisa CRUD branches
- Tidak bisa koreksi absensi

Punya akses penuh ke: employees, attendance admin, stock audit approve, semua master data, reports, expenses, POS, shift.

### Leader — Operasional Cabang
Bisa: branch management (master data CRUD), POS, shift, expenses, dashboard operational, purchases, stock audit (create, tidak approve).

**Tidak bisa**: employees, attendance admin, reports (`/reports/*`), stock audit approve.

### Finance — Read-Only + Keuangan
Bisa: lihat semua master data (products/recipe, variants/recipe, promos, toppings, materials, suppliers, stock, audits, purchases), expenses CRUD, semua reports, dashboard operational, list & detail shift, list transactions.

**Tidak bisa**: buat/edit/hapus master data, buka/tutup shift, transaksi POS, employees, attendance admin.

### Kasir — POS & Shift
Bisa: POS transactions, shift (buka/tutup/lihat), list transactions, absensi sendiri, lihat data publik (products/services/categories/customers).

**Tidak bisa**: reports, expenses, stock/material/purchase, employees.

### Karyawan — POS + Shift + Absensi
Bisa: POS transactions, shift (buka/tutup/lihat), absensi (cek-in/out).

**Tidak bisa**: list transactions, reports, expenses, master data CRUD.

### Produksi — POS + Absensi
Bisa: POS transactions, absensi (cek-in/out).

**Tidak bisa**: shift, list transactions, reports, expenses, master data CRUD.

---

## Matriks Modul × Role

Legend: ✅ akses · 📖 read-only · 🙋 hanya data sendiri · ❌ tidak ada akses

### Auth & Profile

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /me` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /auth/switch-branch` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /auth/logout` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Branches

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /branches` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /branches` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `PUT /branches/:id` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `PUT /branches/:id/status` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Employees

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /employees` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `POST /employees` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `PUT /employees/:id` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /employees/:id` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Attendance

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `POST /attendance/check-in` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /attendance/check-out` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /attendance/me/today` | ✅ | 🙋 | 🙋 | 🙋 | 🙋 | 🙋 | 🙋 |
| `GET /attendance/me` | ✅ | 🙋 | 🙋 | 🙋 | 🙋 | 🙋 | 🙋 |
| `GET /attendance` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `GET /attendance/summary` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `GET /attendance/:id` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `PATCH /attendance/:id` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Product Categories

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /product-categories` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /product-categories/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /product-categories` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /product-categories/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /product-categories/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Products

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /products` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /products/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /products` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /products/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /products/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `POST /products/:id/image` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /products/:id/image` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `GET /products/:id/recipe` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `PUT /products/:id/recipe` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Product Variants

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /products/:id/variants` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /products/:id/variants/:vid` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /products/:id/variants` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /products/:id/variants/:vid` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /products/:id/variants/:vid` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `GET /products/:id/variants/:vid/recipe` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `PUT /products/:id/variants/:vid/recipe` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Promos

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /promos` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /promos/active` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /promos/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /promos` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /promos/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /promos/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Toppings & Topping Stock

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /toppings` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /toppings/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /toppings` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /toppings/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /toppings/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `GET /topping-stock` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /topping-stock/movements` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /topping-stock/adjust` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Services

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /services` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /services/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /services` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /services/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /services/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Customers

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /customers` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GET /customers/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST /customers` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `PUT /customers/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `DELETE /customers/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Suppliers

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /suppliers` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /suppliers/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /suppliers` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /suppliers/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /suppliers/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Materials

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /materials` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /materials/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /materials` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `PUT /materials/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /materials/:id` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Stock

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /stock-levels` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /stock-movements` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /stock/adjust` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### Stock Audit

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /stock-audits` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /stock-audits/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /stock-audits` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `POST /stock-audits/:id/approve` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Purchases

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /purchases` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /purchases/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /purchases` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

### POS Transactions & Transactions

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `POST /product-transactions` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| `GET /product-transactions/:invoice_no` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| `GET /transactions` (unified ledger) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |

### Expenses

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `POST /expenses` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /expenses` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /expenses/:id` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |

### Dashboard & Reports

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `GET /dashboard/operational` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/daily` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/profit` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/payments` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/top-products` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/top-toppings` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/purchases` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/stock-alerts` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET /reports/ledger` | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |

### Shifts (Kasir)

| Endpoint | Owner | Supervisor | Leader | Finance | Kasir | Karyawan | Produksi |
|---|---|---|---|---|---|---|---|
| `POST /shifts` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `PUT /shifts/current/close` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `GET /shifts/current` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `GET /shifts` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `GET /shifts/:id` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

---

## Catatan & Inkonsistensi

Beberapa hal yang mungkin perlu direview konsistensinya:

1. **Leader tidak punya akses Reports (`/reports/*`)** tapi punya akses Dashboard Operational. Periksa apakah by design atau ada role yang lupa ditambahkan.
2. **Karyawan & Produksi bisa POS tapi tidak bisa lihat list transactions** (`GET /transactions`) — hanya bisa lihat transaksi lewat invoice number.
3. **Kasir tidak bisa lihat Materials/Stock**, padahal POS yang dia lakukan mengurangi stok. Mungkin by design (kasir tidak perlu tahu data stok internal).
4. **Produksi tidak punya akses Materials/Stock/Topping**, padahal namanya "produksi". Role ini sepertinya belum dipakai serius — hanya bisa POS + absensi.
5. **Customers** punya akses penuh untuk semua role. Belum ada pembatasan create/delete customer per role.

---

## Cara Menambah Role Baru

1. Tambah konstanta di `internal/roles/roles.go`.
2. Update `IsValid()` dan `IsEmployee()` di file yang sama.
3. Tambahkan role ke whitelist middleware yang sesuai di `cmd/server/main.go`.
4. Update dokumen ini.
