import 'product_model.dart';

class StockMovementModel {
  final int? id;
  final int? productId;
  final String? type; // "IN" | "OUT" | "ADJUST"
  final int? quantity;
  final String? referenceType; // "purchase" | "sales" | "adjustment"
  final int? referenceId;
  final String? createdAt;
  
  // Optional related product object if the API returns one
  final Product? product;

  StockMovementModel({
    this.id,
    this.productId,
    this.type,
    this.quantity,
    this.referenceType,
    this.referenceId,
    this.createdAt,
    this.product,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> j) {
    return StockMovementModel(
      id: j['id'],
      productId: j['product_id'],
      type: j['type'],
      quantity: j['quantity'],
      referenceType: j['reference_type'],
      referenceId: j['reference_id'],
      createdAt: j['created_at'],
      product: j['product'] != null ? Product.fromJson(j['product']) : null,
    );
  }
}
