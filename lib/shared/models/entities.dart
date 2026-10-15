/// كل كيانات قاعدة البيانات — Entities واضحة ومشتركة
class Product {
  final String code;
  final String desc;
  final double stock;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final String weightType; // متغير | ثابت
  final double fixedWeight;
  final String? barcode;
  final double price; // سعر البيع الافتراضي (0 = يُدخل يدويًا في النقدي)
  final bool hasCode;
  final bool hasWeight;
  final bool hasDate;
  final bool hasMazraa;
  const Product({
    required this.code,
    required this.desc,
    this.stock = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.weightType = 'متغير',
    this.fixedWeight = 0,
    this.barcode,
    this.price = 0,
    // الكود والوزن مفعّلان افتراضيًا — التاريخ مطفي.
    // الوزن شغال لكن قيمته صفر لو لم تُحدد.
    this.hasCode = true,
    this.hasWeight = true,
    this.hasDate = false,
    this.hasMazraa = true,
  });
  Map<String, Object?> toMap() => {
        'code': code,
        'description': desc,
        'stock': stock,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'weightType': weightType,
        'fixedWeight': fixedWeight,
        'barcode': barcode,
        'price': price,
        'hasCode': hasCode ? 1 : 0,
        'hasWeight': hasWeight ? 1 : 0,
        'hasDate': hasDate ? 1 : 0,
        'hasMazraa': hasMazraa ? 1 : 0,
      };
  factory Product.fromMap(Map<String, Object?> m) => Product(
        code: (m['code'] ?? '').toString(),
        desc: (m['description'] ?? '').toString(),
        stock: ((m['stock'] ?? 0) as num).toDouble(),
        isActive: ((m['isActive'] ?? 1) as num).toInt() == 1,
        createdAt: m['createdAt']?.toString(),
        updatedAt: m['updatedAt']?.toString(),
        weightType: (m['weightType'] ?? 'متغير').toString(),
        fixedWeight: ((m['fixedWeight'] ?? 0) as num).toDouble(),
        barcode: m['barcode']?.toString(),
        price: ((m['price'] ?? 0) as num).toDouble(),
        hasCode: ((m['hasCode'] ?? 1) as num).toInt() == 1,
        hasWeight: ((m['hasWeight'] ?? 1) as num).toInt() == 1,
        hasDate: ((m['hasDate'] ?? 0) as num).toInt() == 1,
        hasMazraa: ((m['hasMazraa'] ?? 1) as num).toInt() == 1,
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
  final double totalWeight;
  final double totalPrice;
  final bool cash;
  final String byUser;
  final int number;
  final double reqQty;
  final double reqWeight;
  const ReceiptHeader({
    required this.id,
    required this.supplierCode,
    required this.supplierName,
    required this.date,
    required this.createdAt,
    this.totalQty = 0,
    this.totalItems = 0,
    this.totalWeight = 0,
    this.totalPrice = 0,
    this.cash = false,
    this.byUser = '',
    this.number = 0,
    this.reqQty = 0,
    this.reqWeight = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'supplierCode': supplierCode,
        'supplierName': supplierName,
        'date': date,
        'createdAt': createdAt,
        'totalQty': totalQty,
        'totalItems': totalItems,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
        'cash': cash ? 1 : 0,
        'byUser': byUser,
        'num': number,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      };
  factory ReceiptHeader.fromMap(Map<String, Object?> m) => ReceiptHeader(
        id: m['id'].toString(),
        supplierCode: (m['supplierCode'] ?? '').toString(),
        supplierName: (m['supplierName'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        totalQty: ((m['totalQty'] ?? 0) as num).toDouble(),
        totalItems: ((m['totalItems'] ?? 0) as num).toInt(),
        totalWeight: ((m['totalWeight'] ?? 0) as num).toDouble(),
        totalPrice: ((m['totalPrice'] ?? 0) as num).toDouble(),
        cash: ((m['cash'] ?? 0) as num).toInt() == 1,
        byUser: (m['byUser'] ?? '').toString(),
        number: ((m['num'] ?? 0) as num).toInt(),
        reqQty: ((m['reqQty'] ?? 0) as num).toDouble(),
        reqWeight: ((m['reqWeight'] ?? 0) as num).toDouble(),
      );
}

class ReceiptItem {
  final int? id;
  final String receiptId;
  final String productCode;
  final String productName;
  final double quantity;
  final double weight;
  final double price;
  const ReceiptItem({
    this.id,
    required this.receiptId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    this.weight = 0,
    this.price = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'receiptId': receiptId,
        'productCode': productCode,
        'productName': productName,
        'quantity': quantity,
        'weight': weight,
        'price': price,
      };
  factory ReceiptItem.fromMap(Map<String, Object?> m) => ReceiptItem(
        id: (m['id'] as num?)?.toInt(),
        receiptId: m['receiptId'].toString(),
        productCode: (m['productCode'] ?? '').toString(),
        productName: (m['productName'] ?? '').toString(),
        quantity: ((m['quantity'] ?? 0) as num).toDouble(),
        weight: ((m['weight'] ?? 0) as num).toDouble(),
        price: ((m['price'] ?? 0) as num).toDouble(),
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
  final double totalWeight;
  final double totalPrice;
  final bool cash;
  final String byUser;
  final int number;
  final double reqQty;
  final double reqWeight;
  const DeliveryHeader({
    required this.id,
    required this.customerCode,
    required this.customerName,
    required this.date,
    required this.createdAt,
    this.totalQty = 0,
    this.totalItems = 0,
    this.totalWeight = 0,
    this.totalPrice = 0,
    this.cash = false,
    this.byUser = '',
    this.number = 0,
    this.reqQty = 0,
    this.reqWeight = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'customerCode': customerCode,
        'customerName': customerName,
        'date': date,
        'createdAt': createdAt,
        'totalQty': totalQty,
        'totalItems': totalItems,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
        'cash': cash ? 1 : 0,
        'byUser': byUser,
        'num': number,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      };
  factory DeliveryHeader.fromMap(Map<String, Object?> m) => DeliveryHeader(
        id: m['id'].toString(),
        customerCode: (m['customerCode'] ?? '').toString(),
        customerName: (m['customerName'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        totalQty: ((m['totalQty'] ?? 0) as num).toDouble(),
        totalItems: ((m['totalItems'] ?? 0) as num).toInt(),
        totalWeight: ((m['totalWeight'] ?? 0) as num).toDouble(),
        totalPrice: ((m['totalPrice'] ?? 0) as num).toDouble(),
        cash: ((m['cash'] ?? 0) as num).toInt() == 1,
        byUser: (m['byUser'] ?? '').toString(),
        number: ((m['num'] ?? 0) as num).toInt(),
        reqQty: ((m['reqQty'] ?? 0) as num).toDouble(),
        reqWeight: ((m['reqWeight'] ?? 0) as num).toDouble(),
      );
}

class DeliveryItem {
  final int? id;
  final String deliveryId;
  final String productCode;
  final String productName;
  final double quantity;
  final double weight;
  final double price;
  const DeliveryItem({
    this.id,
    required this.deliveryId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    this.weight = 0,
    this.price = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'deliveryId': deliveryId,
        'productCode': productCode,
        'productName': productName,
        'quantity': quantity,
        'weight': weight,
        'price': price,
      };
  factory DeliveryItem.fromMap(Map<String, Object?> m) => DeliveryItem(
        id: (m['id'] as num?)?.toInt(),
        deliveryId: m['deliveryId'].toString(),
        productCode: (m['productCode'] ?? '').toString(),
        productName: (m['productName'] ?? '').toString(),
        quantity: ((m['quantity'] ?? 0) as num).toDouble(),
        weight: ((m['weight'] ?? 0) as num).toDouble(),
        price: ((m['price'] ?? 0) as num).toDouble(),
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
  double weight;
  double price;
  DocLine({
    required this.productCode,
    required this.productName,
    this.quantity = 1,
    this.weight = 0,
    this.price = 0,
  });
}

/// مستخدم النظام (شاشة ادارة المستخدمين)
class AppUser {
  final int? id;
  final String username;
  final String password;
  final String type; // مستخدم | مدير
  const AppUser({this.id, required this.username, required this.password, this.type = 'مستخدم'});
  Map<String, Object?> toMap() => {'id': id, 'username': username, 'password': password, 'type': type};
  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: (m['id'] as num?)?.toInt(),
        username: (m['username'] ?? '').toString(),
        password: (m['password'] ?? '').toString(),
        type: (m['type'] ?? 'مستخدم').toString(),
      );
}

/// مخزن (شاشة المخازن)
class Warehouse {
  final String code;
  final String name;
  final String? createdAt;
  const Warehouse({required this.code, required this.name, this.createdAt});
  Map<String, Object?> toMap() => {'code': code, 'name': name, 'createdAt': createdAt};
  factory Warehouse.fromMap(Map<String, Object?> m) => Warehouse(
        code: (m['code'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        createdAt: m['createdAt']?.toString(),
      );
}

/// كود باركود تابع لصنف (دايلوج إضافة كود)
/// مقاطع الباركود بترقيم 1-based وشاملين (أول رقم = 1):
/// weight بين wStart..wEnd، code بين cStart..cEnd، date بين dStart..dEnd،
/// mazraa بين mStart..mEnd. القيمة 0 تعني "غير محدد".
class ProductCode {
  final int? id;
  final String productCode;
  final String barcode;
  final double qty;
  final double weight;
  final String unit; // KG | LB
  final String mark; // 1 | 10 | 100 | 1000 | 10000
  final String dateFmt;
  final double value;
  final int wStart;
  final int wEnd;
  final int cStart;
  final int cEnd;
  final int dStart;
  final int dEnd;
  final int mStart;
  final int mEnd;
  const ProductCode({
    this.id,
    required this.productCode,
    required this.barcode,
    this.qty = 0,
    this.weight = 0,
    this.unit = 'KG',
    this.mark = '1',
    this.dateFmt = 'DD/MM/YYYY',
    this.value = 0,
    this.wStart = 0,
    this.wEnd = 0,
    this.cStart = 0,
    this.cEnd = 0,
    this.dStart = 0,
    this.dEnd = 0,
    this.mStart = 0,
    this.mEnd = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'productCode': productCode,
        'barcode': barcode,
        'qty': qty,
        'weight': weight,
        'unit': unit,
        'mark': mark,
        'dateFmt': dateFmt,
        'value': value,
        'wStart': wStart,
        'wEnd': wEnd,
        'cStart': cStart,
        'cEnd': cEnd,
        'dStart': dStart,
        'dEnd': dEnd,
        'mStart': mStart,
        'mEnd': mEnd,
      };
  factory ProductCode.fromMap(Map<String, Object?> m) => ProductCode(
        id: (m['id'] as num?)?.toInt(),
        productCode: (m['productCode'] ?? '').toString(),
        barcode: (m['barcode'] ?? '').toString(),
        qty: ((m['qty'] ?? 0) as num).toDouble(),
        weight: ((m['weight'] ?? 0) as num).toDouble(),
        unit: (m['unit'] ?? 'KG').toString(),
        mark: (m['mark'] ?? '1').toString(),
        dateFmt: (m['dateFmt'] ?? 'DD/MM/YYYY').toString(),
        value: ((m['value'] ?? 0) as num).toDouble(),
        wStart: ((m['wStart'] ?? 0) as num).toInt(),
        wEnd: ((m['wEnd'] ?? 0) as num).toInt(),
        cStart: ((m['cStart'] ?? 0) as num).toInt(),
        cEnd: ((m['cEnd'] ?? 0) as num).toInt(),
        dStart: ((m['dStart'] ?? 0) as num).toInt(),
        dEnd: ((m['dEnd'] ?? 0) as num).toInt(),
        mStart: ((m['mStart'] ?? 0) as num).toInt(),
        mEnd: ((m['mEnd'] ?? 0) as num).toInt(),
      );
}

/// ترويسة عملية عامة (مرتجع عميل/مورد + تحويل داخلي/خارجي)
class OpHeader {
  final String id;
  final String kind;
  final String partyType;
  final String partyCode;
  final String partyName;
  final int number;
  final String date;
  final String createdAt;
  final String byUser;
  final double totalQty;
  final double totalWeight;
  final double totalPrice;
  final int totalItems;
  final bool cash;
  final double reqQty;
  final double reqWeight;
  const OpHeader({
    required this.id,
    required this.kind,
    this.partyType = '',
    this.partyCode = '',
    this.partyName = '',
    this.number = 0,
    required this.date,
    required this.createdAt,
    this.byUser = '',
    this.totalQty = 0,
    this.totalWeight = 0,
    this.totalPrice = 0,
    this.totalItems = 0,
    this.cash = false,
    this.reqQty = 0,
    this.reqWeight = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind,
        'partyType': partyType,
        'partyCode': partyCode,
        'partyName': partyName,
        'num': number,
        'date': date,
        'createdAt': createdAt,
        'byUser': byUser,
        'totalQty': totalQty,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
        'totalItems': totalItems,
        'cash': cash ? 1 : 0,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      };
  factory OpHeader.fromMap(Map<String, Object?> m) => OpHeader(
        id: m['id'].toString(),
        kind: (m['kind'] ?? '').toString(),
        partyType: (m['partyType'] ?? '').toString(),
        partyCode: (m['partyCode'] ?? '').toString(),
        partyName: (m['partyName'] ?? '').toString(),
        number: ((m['num'] ?? 0) as num).toInt(),
        date: (m['date'] ?? '').toString(),
        createdAt: (m['createdAt'] ?? '').toString(),
        byUser: (m['byUser'] ?? '').toString(),
        totalQty: ((m['totalQty'] ?? 0) as num).toDouble(),
        totalWeight: ((m['totalWeight'] ?? 0) as num).toDouble(),
        totalPrice: ((m['totalPrice'] ?? 0) as num).toDouble(),
        totalItems: ((m['totalItems'] ?? 0) as num).toInt(),
        cash: ((m['cash'] ?? 0) as num).toInt() == 1,
        reqQty: ((m['reqQty'] ?? 0) as num).toDouble(),
        reqWeight: ((m['reqWeight'] ?? 0) as num).toDouble(),
      );
}

class OpItem {
  final int? id;
  final String opId;
  final String productCode;
  final String productName;
  final double quantity;
  final double weight;
  final double price;
  const OpItem({
    this.id,
    required this.opId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    this.weight = 0,
    this.price = 0,
  });
  Map<String, Object?> toMap() => {
        'id': id,
        'opId': opId,
        'productCode': productCode,
        'productName': productName,
        'quantity': quantity,
        'weight': weight,
        'price': price,
      };
  factory OpItem.fromMap(Map<String, Object?> m) => OpItem(
        id: (m['id'] as num?)?.toInt(),
        opId: m['opId'].toString(),
        productCode: (m['productCode'] ?? '').toString(),
        productName: (m['productName'] ?? '').toString(),
        quantity: ((m['quantity'] ?? 0) as num).toDouble(),
        weight: ((m['weight'] ?? 0) as num).toDouble(),
        price: ((m['price'] ?? 0) as num).toDouble(),
      );
}
