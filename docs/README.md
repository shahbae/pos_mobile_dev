# Fitur: Kitchen Display System (KDS) Realtime

Spesifikasi implementasi untuk dibaca oleh AI coding agent. Baca file sesuai
repo yang sedang dikerjakan — jangan campur.

| File | Untuk repo | Isi |
|---|---|---|
| `01-backend-golang.md` | backend Go (be-pos) | SSE hub, endpoint stream & snapshot, trigger broadcast |
| `02-frontend-flutter.md` | app Flutter | SSE client, controller, UI grid dapur |
| `03-deployment-vps.md` | VPS Hostinger | Nginx, systemd, verifikasi |

## Ringkasan arsitektur

Kasir menyelesaikan pembayaran → backend commit ke DB → backend broadcast event
SSE ke room `tenant:outlet` → tablet dapur menerima dalam < 1 detik dan
menampilkan kartu pesanan baru.

```
Kasir (Flutter) --POST /orders/{id}/pay--> Go API --commit DB--> Hub.Broadcast
                                                                      |
                                                          SSE (text/event-stream)
                                                                      v
                                                          Dapur (Flutter KDS)
```

## Prinsip yang tidak boleh dilanggar

1. **SSE bukan sumber kebenaran.** Snapshot REST adalah sumber kebenaran.
   Setiap kali koneksi terbuka/pulih, client wajib fetch snapshot dulu.
   Kalau tidak, pesanan hilang saat wifi dapur putus sebentar.
2. **Broadcast selalu setelah DB commit**, tidak pernah di dalam transaksi.
3. **Broadcast tidak boleh blocking.** Kirim ke channel pakai `select` +
   `default`; kalau buffer penuh, drop frame — client akan resync sendiri.
4. **Isolasi tenant/outlet wajib.** Room key = `tenantID + ":" + outletID`.
   Dapur cabang A tidak boleh menerima pesanan cabang B.
5. **Jangan pakai polling interval.** Jangan pakai WebSocket untuk kasus ini.

## Nama event (kontrak bersama BE & FE)

| Event | Kapan dikirim | Aksi di dapur |
|---|---|---|
| `order.paid` | pembayaran sukses | tambah kartu baru + bunyikan buzzer |
| `order.status_changed` | status berubah | update kartu; hapus jika `served` |
| `order.voided` | dibatalkan / refund | hapus kartu |

Status pesanan: `queued` → `preparing` → `ready` → `served`.
