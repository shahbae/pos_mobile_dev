# Spec: Backend Go — SSE untuk Kitchen Display System

**Repo:** backend Go (be-pos)
**Tujuan:** kirim pesanan yang sudah dibayar ke tablet dapur secara realtime
lewat Server-Sent Events.

Baca `README.md` untuk prinsip umum sebelum mulai.

---

## 1. File baru: `internal/realtime/hub.go`

Buat file berikut apa adanya. Sesuaikan hanya bagian pembacaan claim JWT
(ditandai `GANTI`).

```go
package realtime

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

const (
	EventOrderPaid          = "order.paid"
	EventOrderStatusChanged = "order.status_changed"
	EventOrderVoided        = "order.voided"
)

type OrderItemPayload struct {
	ID       string   `json:"id"`
	Name     string   `json:"name"`
	Qty      int      `json:"qty"`
	Variants []string `json:"variants,omitempty"`
	Note     string   `json:"note,omitempty"`
}

type OrderPayload struct {
	ID          string             `json:"id"`
	OrderNumber string             `json:"order_number"`
	TableOrTag  string             `json:"table_or_tag,omitempty"`
	OrderType   string             `json:"order_type"`
	Status      string             `json:"status"`
	Items       []OrderItemPayload `json:"items"`
	PaidAt      time.Time          `json:"paid_at"`
	CashierName string             `json:"cashier_name,omitempty"`
}

type subscriber struct {
	room string
	send chan []byte
}

type Hub struct {
	mu     sync.RWMutex
	rooms  map[string]map[*subscriber]struct{}
	nextID atomic.Uint64
}

func NewHub() *Hub {
	return &Hub{rooms: make(map[string]map[*subscriber]struct{})}
}

func RoomKey(tenantID, outletID string) string {
	return tenantID + ":" + outletID
}

func (h *Hub) subscribe(room string) *subscriber {
	s := &subscriber{room: room, send: make(chan []byte, 32)}
	h.mu.Lock()
	if h.rooms[room] == nil {
		h.rooms[room] = make(map[*subscriber]struct{})
	}
	h.rooms[room][s] = struct{}{}
	h.mu.Unlock()
	return s
}

func (h *Hub) unsubscribe(s *subscriber) {
	h.mu.Lock()
	if subs, ok := h.rooms[s.room]; ok {
		delete(subs, s)
		if len(subs) == 0 {
			delete(h.rooms, s.room)
		}
	}
	h.mu.Unlock()
	close(s.send)
}

// Broadcast aman dipanggil dari goroutine mana pun.
func (h *Hub) Broadcast(room, event string, payload any) {
	body, err := json.Marshal(payload)
	if err != nil {
		log.Printf("[realtime] marshal payload gagal: %v", err)
		return
	}

	id := h.nextID.Add(1)
	frame := []byte(fmt.Sprintf("id: %d\nevent: %s\ndata: %s\n\n", id, event, body))

	h.mu.RLock()
	defer h.mu.RUnlock()
	for s := range h.rooms[room] {
		select {
		case s.send <- frame:
		default:
			log.Printf("[realtime] buffer penuh, frame di-drop untuk room=%s", room)
		}
	}
}

func (h *Hub) OnlineCount(room string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.rooms[room])
}

const heartbeatInterval = 20 * time.Second

func (h *Hub) HandleSSE(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming tidak didukung", http.StatusInternalServerError)
		return
	}

	// GANTI: ambil dari claim JWT hasil auth middleware, bukan query param.
	// claims := auth.FromContext(r.Context())
	// tenantID, outletID := claims.TenantID, claims.OutletID
	tenantID := r.URL.Query().Get("tenant_id")
	outletID := r.URL.Query().Get("outlet_id")
	if tenantID == "" || outletID == "" {
		http.Error(w, "tenant_id & outlet_id wajib diisi", http.StatusBadRequest)
		return
	}
	room := RoomKey(tenantID, outletID)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache, no-transform")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, "retry: 3000\n\n")
	flusher.Flush()

	sub := h.subscribe(room)
	defer h.unsubscribe(sub)

	ticker := time.NewTicker(heartbeatInterval)
	defer ticker.Stop()

	ctx := r.Context()
	for {
		select {
		case <-ctx.Done():
			return
		case frame, ok := <-sub.send:
			if !ok {
				return
			}
			if _, err := w.Write(frame); err != nil {
				return
			}
			flusher.Flush()
		case <-ticker.C:
			if _, err := fmt.Fprint(w, ": heartbeat\n\n"); err != nil {
				return
			}
			flusher.Flush()
		}
	}
}
```

---

## 2. Wiring di `main.go`

Buat hub **satu kali** dan inject ke handler + service order.

```go
hub := realtime.NewHub()

orderSvc := service.NewOrderService(orderRepo, hub)

// net/http
mux.Handle("GET /api/v1/kds/stream", authMiddleware(http.HandlerFunc(hub.HandleSSE)))

// atau Gin
r.GET("/api/v1/kds/stream", authMiddleware(), gin.WrapF(hub.HandleSSE))
r.GET("/api/v1/kds/orders", authMiddleware(), kdsHandler.ListActive)
r.PATCH("/api/v1/kds/orders/:id/status", authMiddleware(), kdsHandler.UpdateStatus)
```

**Penting soal timeout:** jika `http.Server` punya `WriteTimeout`, koneksi SSE
akan diputus paksa. Set `WriteTimeout: 0` untuk server ini, atau pisahkan
route SSE ke server/mux dengan timeout nol.

---

## 3. Trigger broadcast di service

Selalu **setelah** transaksi DB berhasil commit.

```go
func (s *OrderService) MarkAsPaid(ctx context.Context, orderID string) error {
	order, err := s.repo.MarkPaid(ctx, orderID) // commit di dalam sini
	if err != nil {
		return err
	}

	s.hub.Broadcast(
		realtime.RoomKey(order.TenantID, order.OutletID),
		realtime.EventOrderPaid,
		toOrderPayload(order),
	)
	return nil
}

func (s *OrderService) UpdateKitchenStatus(ctx context.Context, orderID, status string) error {
	order, err := s.repo.UpdateStatus(ctx, orderID, status)
	if err != nil {
		return err
	}
	s.hub.Broadcast(
		realtime.RoomKey(order.TenantID, order.OutletID),
		realtime.EventOrderStatusChanged,
		toOrderPayload(order),
	)
	return nil
}
```

Lakukan hal sama untuk void/refund dengan `EventOrderVoided`.

---

## 4. Endpoint snapshot (WAJIB)

`GET /api/v1/kds/orders?status=queued,preparing,ready`

Query pesanan aktif milik tenant+outlet dari JWT, urut `paid_at ASC`, eager
load items + variants (hindari N+1). Response:

```json
{
  "data": [
    {
      "id": "ord_01J...",
      "order_number": "A-014",
      "table_or_tag": "Meja 3",
      "order_type": "dine_in",
      "status": "queued",
      "items": [
        { "id": "itm_1", "name": "Es Teh Manis", "qty": 2,
          "variants": ["Less Sugar", "Large"], "note": "tanpa es" }
      ],
      "paid_at": "2026-08-06T10:12:44Z",
      "cashier_name": "Dewi"
    }
  ]
}
```

Struktur objek di `data[]` **harus identik** dengan payload SSE — client
memakai parser yang sama untuk keduanya.

---

## 5. Migrasi DB

Tambahkan kolom pada tabel orders jika belum ada:

- `kitchen_status` VARCHAR(20) NOT NULL DEFAULT 'queued'
- `paid_at` TIMESTAMP NULL
- index: `(tenant_id, outlet_id, kitchen_status, paid_at)`

---

## Acceptance criteria

- [ ] `curl -N ".../api/v1/kds/stream?..."` menampilkan `: heartbeat` tiap 20 detik.
- [ ] Menyelesaikan pembayaran memunculkan frame `event: order.paid` pada stream yang terbuka.
- [ ] Stream milik outlet B tidak menerima event dari outlet A.
- [ ] `go test -race ./internal/realtime/...` lolos (uji 50 subscriber + 1000 broadcast paralel).
- [ ] Menutup client tidak menyebabkan goroutine leak — `OnlineCount` kembali ke 0.
- [ ] Payload SSE dan payload snapshot punya struktur field yang sama persis.
