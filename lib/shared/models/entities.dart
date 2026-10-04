/// كل كيانات قاعدة البيانات — Entities واضحة ومشتركة
class Product {
  final String code;
  final String desc;
  final double stock;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  const Product({
    required this.code,
    required this.desc,
    this.stock = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });
  Map<String, Object?> toMap() => {
        'code': code,
        'description': desc,
        'stock': stock,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
  factory Product.fromMap(Map<String, Object?> m) => Product(
        code: (m['code'] ?? '').toString(),
        desc: (m['description'] ?? '').toString(),
        stock: ((m['stock'] ?? 0) as num).toDouble(),
        isActive: ((m['isActive'] ?? 1) as num).toInt() == 1,
        createdAt: m['createdAt']?.toString(),
        updatedAt: m['updatedAt']?.toString(),
      );
}

class Supplier {
  final String code;
  final String desc;
  final bool isActive;
  final String? createdAt;
  const Supplier(
      {required this.code, required this.desc, this.isActive = true, this.createdAt});
  Map<String, Object?> toMap() => {
        'code': code,
        'description': desc,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
      };
  factory Supplier.fromMap(Map<String, Object?> m) => Supplier(
        code: (m['code'] ?? '').toString(),
        desc: (m['description'] ?? '').toString(),
        isActive: ((m['isActive'] ?? 1) as num).toInt() == 1,
        createdAt: m['createdAt']?.toString(),
      );
}

class Customer {
  final String code;
  final String desc;
  final bool isActive;
  final String? createdAt;
  const Customer(
      {required this.code, required this.desc, this.isActive = true, this.createdAt});
  Map<String, Object?> toMap() => {
        'code': code,
        'description': desc,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
      };
  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        code: (m['code'] ?? '').toString(),
        desc: (m['description'] ?? '').toString(),
        isActive: ((m['isActive'] ?? 1) as num).toInt() == 1,
        createdAt: m['createdAt']?.toString(),
      );
}

class ReceiptHeader {
  final String id;
  final String supplierCode;
  final String supplierName;
  final String date;
  final String createdAt;
  final double totalQty;
  final int totalItems;
  const ReceiptHeader({
    required this.id,
    required this.supplierCode,
    required this.supplierName,
    required this.date,
    required this.createdAt,
    this.totalQty = 0,
    this.totalItems = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'supplierCode': supplierCode,
        'supplierName': supplierName,
        'date': date,
        'createdAt': createdAt,
        'totalQty': totalQty,
        'totalItems': totalItems,
      };
  factory ReceiptHeader.fromMap(Map<String, Object?> m) => ReceiptHeader(
        id: m['id'].toString(),
        supplierCode: (m['supplierCode'] ?? '').toString(),
        supplierName: (m['supplierName'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        totalQty: ((m['totalQty'] ?? 0) as num).toDouble(),
        totalItems: ((m['totalItems'] ?? 0) as num).toInt(),
      );
}

class ReceiptItem {
  final int? id;
  final String receiptId;
  final String productCode;
  final String productName;
  final double quantity;
  const ReceiptItem({
    this.id,
    required this.receiptId,
    required this.productCode,
    required this.productName,
    required this.quantity,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'receiptId': receiptId,
        'productCode': productCode,
        'productName': productName,
        'quantity': quantity,
      };
  factory ReceiptItem.fromMap(Map<String, Object?> m) => ReceiptItem(
        id: (m['id'] as num?)?.toInt(),
        receiptId: m['receiptId'].toString(),
        productCode: (m['productCode'] ?? '').toString(),
        productName: (m['productName'] ?? '').toString(),
        quantity: ((m['quantity'] ?? 0) as num).toDouble(),
      );
}

class DeliveryHeader {
  final String id;
  final String customerCode;
  final String customerName;
  final String date;
  final String createdAt;
  final double totalQty;
  final int totalItems;
  const DeliveryHeader({
    required this.id,
    required this.customerCode,
    required this.customerName,
    required this.date,
    required this.createdAt,
    this.totalQty = 0,
    this.totalItems = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'customerCode': customerCode,
        'customerName': customerName,
        'date': date,
        'createdAt': createdAt,
        'totalQty': totalQty,
        'totalItems': totalItems,
      };
  factory DeliveryHeader.fromMap(Map<String, Object?> m) => DeliveryHeader(
        id: m['id'].toString(),
        customerCode: (m['customerCode'] ?? '').toString(),
        customerName: (m['customerName'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        totalQty: ((m['totalQty'] ?? 0) as num).toDouble(),
        totalItems: ((m['totalItems'] ?? 0) as num).toInt(),
      );
}

class DeliveryItem {
  final int? id;
  final String deliveryId;
  final String productCode;
  final String productName;
  final double quantity;
  const DeliveryItem({
    this.id,
    required this.deliveryId,
    required this.productCode,
    required this.productName,
    required this.quantity,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'deliveryId': deliveryId,
        'productCode': productCode,
        'productName': productName,
        'quantity': quantity,
      };
  factory DeliveryItem.fromMap(Map<String, Object?> m) => DeliveryItem(
        id: (m['id'] as num?)?.toInt(),
        deliveryId: m['deliveryId'].toString(),
        productCode: (m['productCode'] ?? '').toString(),
        productName: (m['productName'] ?? '').toString(),
        quantity: ((m['quantity'] ?? 0) as num).toDouble(),
      );
}

class InventorySession {
  final String id;
  final String date;
  final String createdAt;
  final String status; // open | closed
  const InventorySession({
    required this.id,
    required this.date,
    required this.createdAt,
    this.status = 'open',
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'createdAt': createdAt,
        'status': status,
      };
  factory InventorySession.fromMap(Map<String, Object?> m) =>
      InventorySession(
        id: m['id'].toString(),
        date: (m['date'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        status: (m['status'] ?? 'open').toString(),
      );
}

class InventoryItem {
  final int? id;
  final String sessionId;
  final String productCode;
  final String productName;
  final double expectedQty;
  final double actualQty;
  const InventoryItem({
    this.id,
    required this.sessionId,
    required this.productCode,
    required this.productName,
    this.expectedQty = 0,
    this.actualQty = 0,
  });
  double get difference => actualQty - expectedQty;
  String get statusAr {
    if (difference < 0) return 'ناقص';
    if (difference > 0) return 'زائد';
    return 'متساوي';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'productCode': productCode,
        'productName': productName,
        'expectedQty': expectedQty,
        'actualQty': actualQty,
      };
  factory InventoryItem.fromMap(Map<String, Object?> m) => InventoryItem(
        id: (m['id'] as num?)?.toInt(),
        sessionId: m['sessionId'].toString(),
        productCode: (m['productCode'] ?? '').toString(),
        productName: (m['productName'] ?? '').toString(),
        expectedQty: ((m['expectedQty'] ?? 0) as num).toDouble(),
        actualQty: ((m['actualQty'] ?? 0) as num).toDouble(),
      );
}

class StockMovement {
  final int? id;
  final String productCode;
  final String type; // RECEIPT | DELIVERY | ADJUSTMENT | INVENTORY
  final String referenceId;
  final double quantity;
  final double beforeQty;
  final double afterQty;
  final String createdAt;
  const StockMovement({
    this.id,
    required this.productCode,
    required this.type,
    required this.referenceId,
    required this.quantity,
    required this.beforeQty,
    required this.afterQty,
    required this.createdAt,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'productCode': productCode,
        'type': type,
        'referenceId': referenceId,
        'quantity': quantity,
        'beforeQty': beforeQty,
        'afterQty': afterQty,
        'createdAt': createdAt,
      };
  factory StockMovement.fromMap(Map<String, Object?> m) => StockMovement(
        id: (m['id'] as num?)?.toInt(),
        productCode: (m['productCode'] ?? '').toString(),
        type: (m['type'] ?? '').toString(),
        referenceId: (m['referenceId'] ?? '').toString(),
        quantity: ((m['quantity'] ?? 0) as num).toDouble(),
        beforeQty: ((m['beforeQty'] ?? 0) as num).toDouble(),
        afterQty: ((m['afterQty'] ?? 0) as num).toDouble(),
        createdAt: (m['createdAt'] ?? '').toString(),
      );
}

/// عنصر مؤقت داخل شاشة إنشاء إذن (قبل الحفظ)
class DocLine {
  final String productCode;
  final String productName;
  double quantity;
  DocLine({
    required this.productCode,
    required this.productName,
    this.quantity = 1,
  });
}
