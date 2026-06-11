import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/data/models/product_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/presentation/providers/topping_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/utils/currency.dart';

class ToppingPickerResult {
  final int quantity;
  final List<CartTopping> freeToppings;
  final List<CartTopping> extraToppings;

  ToppingPickerResult({
    required this.quantity,
    required this.freeToppings,
    required this.extraToppings,
  });
}

/// Bottom sheet untuk memilih topping gratis & berbayar pada satu baris cart.
Future<ToppingPickerResult?> showToppingPicker(
  BuildContext context, {
  required Product product,
  int initialQty = 1,
  List<CartTopping> initialFree = const [],
  List<CartTopping> initialExtra = const [],
}) {
  return showModalBottomSheet<ToppingPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ToppingPickerSheet(
      product: product,
      initialQty: initialQty,
      initialFree: initialFree,
      initialExtra: initialExtra,
    ),
  );
}

class _ToppingPickerSheet extends ConsumerStatefulWidget {
  final Product product;
  final int initialQty;
  final List<CartTopping> initialFree;
  final List<CartTopping> initialExtra;

  const _ToppingPickerSheet({
    required this.product,
    required this.initialQty,
    required this.initialFree,
    required this.initialExtra,
  });

  @override
  ConsumerState<_ToppingPickerSheet> createState() => _ToppingPickerSheetState();
}

class _ToppingPickerSheetState extends ConsumerState<_ToppingPickerSheet> {
  late int _qty;
  final Map<int, int> _free = {}; // toppingId -> qty
  final Map<int, int> _extra = {}; // toppingId -> qty

  int get _freeUsed => _free.values.fold(0, (a, b) => a + b);
  int get _slots => widget.product.freeToppingSlots;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    for (final t in widget.initialFree) {
      _free[t.topping.id] = t.qty;
    }
    for (final t in widget.initialExtra) {
      _extra[t.topping.id] = t.qty;
    }
  }

  void _confirm(List<Topping> toppings) {
    Topping byId(int id) => toppings.firstWhere((t) => t.id == id);
    final free = _free.entries
        .where((e) => e.value > 0)
        .map((e) => CartTopping(topping: byId(e.key), qty: e.value))
        .toList();
    final extra = _extra.entries
        .where((e) => e.value > 0)
        .map((e) => CartTopping(topping: byId(e.key), qty: e.value))
        .toList();
    Navigator.pop(
      context,
      ToppingPickerResult(quantity: _qty, freeToppings: free, extraToppings: extra),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toppingsAsync = ref.watch(toppingListProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.product.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderLight),
            Expanded(
              child: toppingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat topping: $e')),
                data: (toppings) {
                  if (toppings.isEmpty) {
                    return const Center(child: Text('Belum ada topping aktif'));
                  }
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: [
                      if (_qty > 1)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.brandBlue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: AppTheme.brandBlue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Topping berlaku untuk semua qty di item ini. '
                                  'Untuk topping berbeda tiap cup, buat item terpisah.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.product.hasFreeToppings) ...[
                        _sectionHeader('Topping Gratis', 'Maks $_slots • dipakai $_freeUsed'),
                        ...toppings.map((t) => _ToppingRow(
                              topping: t,
                              qty: _free[t.id] ?? 0,
                              isFree: true,
                              canIncrement: _freeUsed < _slots,
                              onChanged: (v) => setState(() {
                                if (v <= 0) {
                                  _free.remove(t.id);
                                } else {
                                  _free[t.id] = v;
                                }
                              }),
                            )),
                        const SizedBox(height: 20),
                      ],
                      _sectionHeader('Topping Tambahan', 'Berbayar'),
                      ...toppings.map((t) => _ToppingRow(
                            topping: t,
                            qty: _extra[t.id] ?? 0,
                            isFree: false,
                            canIncrement: true,
                            onChanged: (v) => setState(() {
                              if (v <= 0) {
                                _extra.remove(t.id);
                              } else {
                                _extra[t.id] = v;
                              }
                            }),
                          )),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: toppingsAsync.maybeWhen(
                      data: (toppings) => () => _confirm(toppings),
                      orElse: () => null,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Tambahkan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ToppingRow extends StatelessWidget {
  final Topping topping;
  final int qty;
  final bool isFree;
  final bool canIncrement;
  final ValueChanged<int> onChanged;

  const _ToppingRow({
    required this.topping,
    required this.qty,
    required this.isFree,
    required this.canIncrement,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topping.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  isFree ? 'Gratis' : formatRupiah(topping.price),
                  style: TextStyle(
                    fontSize: 12,
                    color: isFree ? Colors.green : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _QtyStepper(
            qty: qty,
            allowZero: true,
            canIncrement: canIncrement,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final bool allowZero;
  final bool canIncrement;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.qty,
    required this.onChanged,
    this.allowZero = false,
    this.canIncrement = true,
  });

  @override
  Widget build(BuildContext context) {
    final minVal = allowZero ? 0 : 1;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, qty > minVal ? () => onChanged(qty - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$qty',
                style: const TextStyle(
                    color: AppTheme.brandBlue, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          _btn(Icons.add, canIncrement ? () => onChanged(qty + 1) : null),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: onTap == null ? AppTheme.borderLight : AppTheme.brandBlue),
      ),
    );
  }
}
