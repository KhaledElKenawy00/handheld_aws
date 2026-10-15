/// أنواع العمليات الست — نفس ألفاظ الصور.
enum OpKind {
  delivery, // تسليم
  receipt, // استلام
  returnCust, // مرتجع عميل
  returnSup, // مرتجع مورد
  transferIn, // تحويل داخلي
  transferOut, // تحويل خارجي
}

OpKind opKindFrom(String label) {
  switch (label) {
    case 'تسليم':
      return OpKind.delivery;
    case 'استلام':
      return OpKind.receipt;
    case 'مرتجع عميل':
      return OpKind.returnCust;
    case 'مرتجع مورد':
      return OpKind.returnSup;
    case 'تحويل داخلي':
      return OpKind.transferIn;
    default:
      return OpKind.transferOut;
  }
}

extension OpKindX on OpKind {
  String get label {
    switch (this) {
      case OpKind.delivery:
        return 'تسليم';
      case OpKind.receipt:
        return 'استلام';
      case OpKind.returnCust:
        return 'مرتجع عميل';
      case OpKind.returnSup:
        return 'مرتجع مورد';
      case OpKind.transferIn:
        return 'تحويل داخلي';
      case OpKind.transferOut:
        return 'تحويل خارجي';
    }
  }

  /// اسم الوظيفة في الصلاحيات.
  String get job {
    switch (this) {
      case OpKind.delivery:
        return 'تسليمات';
      case OpKind.receipt:
        return 'استلامات';
      case OpKind.returnCust:
        return 'مرتجعات للعميل';
      case OpKind.returnSup:
        return 'مرتجعات للمورد';
      case OpKind.transferIn:
        return 'تحويلات داخلية';
      case OpKind.transferOut:
        return 'تحويلات خارجية';
    }
  }

  /// عنوان قائمة المعاملات.
  String get listTitle => 'قائمة المعاملات';

  /// خيارات الطرف في معلومات عملية.
  List<String> get partyTypes {
    switch (this) {
      case OpKind.delivery:
      case OpKind.returnCust:
        return ['عميل'];
      case OpKind.receipt:
      case OpKind.returnSup:
        return ['مورد'];
      case OpKind.transferIn:
      case OpKind.transferOut:
        return ['مخزن'];
    }
  }

  bool get usesLegacy {
    return this == OpKind.delivery || this == OpKind.receipt;
  }
}
