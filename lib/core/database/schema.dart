/// Database schema v5 — الجداول القديمة + الجديدة (صور pic المرجعية).
/// الترقية تتم بإضافة جداول/أعمدة فقط — بدون حذف أي بيانات.
/// v3: مقاطع الباركود (wStart/wEnd/cStart/cEnd/dStart/dEnd/mStart/mEnd).
/// v4: تنظيف بيانات فقط — تصفير مقاطع الوزن الوهمية التي كانت تُضبط
/// تلقائيًا (من أول الباركود لآخره مع علامة 1) فيظهر الوزن هو رقم الباركود.
/// v5: سعر بيع افتراضي للصنف (products.price) — يُملأ تلقائيًا في النقدي.
class Schema {
  static const int version = 5;

  /// أنواع العمليات الست + الوظائف السبع للصلاحيات (نفس ألفاظ الصور).
  static const List<String> opKinds = [
    'تسليم',
    'استلام',
    'مرتجع عميل',
    'مرتجع مورد',
    'تحويل خارجي',
    'تحويل داخلي',
  ];
  static const List<String> jobs = [
    'تسليمات',
    'استلامات',
    'مرتجعات للعميل',
    'مرتجعات للمورد',
    'تحويلات خارجية',
    'تحويلات داخلية',
    'اخرى',
  ];

  static List<String> createStatements() => const [
        '''
        CREATE TABLE IF NOT EXISTS products(
          code TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          stock REAL NOT NULL DEFAULT 0,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT,
          weightType TEXT NOT NULL DEFAULT 'متغير',
          fixedWeight REAL NOT NULL DEFAULT 0,
          barcode TEXT,
          price REAL NOT NULL DEFAULT 0,
          hasCode INTEGER NOT NULL DEFAULT 1,
          hasWeight INTEGER NOT NULL DEFAULT 1,
          hasDate INTEGER NOT NULL DEFAULT 0,
          hasMazraa INTEGER NOT NULL DEFAULT 1
        )''',
        '''
        CREATE TABLE IF NOT EXISTS suppliers(
          code TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT
        )''',
        '''
        CREATE TABLE IF NOT EXISTS customers(
          code TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT
        )''',
        '''
        CREATE TABLE IF NOT EXISTS receipts(
          id TEXT PRIMARY KEY,
          supplierCode TEXT NOT NULL,
          supplierName TEXT NOT NULL,
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          totalQty REAL NOT NULL DEFAULT 0,
          totalItems INTEGER NOT NULL DEFAULT 0,
          totalWeight REAL NOT NULL DEFAULT 0,
          totalPrice REAL NOT NULL DEFAULT 0,
          cash INTEGER NOT NULL DEFAULT 0,
          byUser TEXT NOT NULL DEFAULT '',
          num INTEGER NOT NULL DEFAULT 0,
          reqQty REAL NOT NULL DEFAULT 0,
          reqWeight REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(supplierCode) REFERENCES suppliers(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS receipt_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receiptId TEXT NOT NULL,
          productCode TEXT NOT NULL,
          productName TEXT NOT NULL,
          quantity REAL NOT NULL,
          weight REAL NOT NULL DEFAULT 0,
          price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(receiptId) REFERENCES receipts(id) ON DELETE CASCADE,
          FOREIGN KEY(productCode) REFERENCES products(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS deliveries(
          id TEXT PRIMARY KEY,
          customerCode TEXT NOT NULL,
          customerName TEXT NOT NULL,
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          totalQty REAL NOT NULL DEFAULT 0,
          totalItems INTEGER NOT NULL DEFAULT 0,
          totalWeight REAL NOT NULL DEFAULT 0,
          totalPrice REAL NOT NULL DEFAULT 0,
          cash INTEGER NOT NULL DEFAULT 0,
          byUser TEXT NOT NULL DEFAULT '',
          num INTEGER NOT NULL DEFAULT 0,
          reqQty REAL NOT NULL DEFAULT 0,
          reqWeight REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(customerCode) REFERENCES customers(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS delivery_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          deliveryId TEXT NOT NULL,
          productCode TEXT NOT NULL,
          productName TEXT NOT NULL,
          quantity REAL NOT NULL,
          weight REAL NOT NULL DEFAULT 0,
          price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(deliveryId) REFERENCES deliveries(id) ON DELETE CASCADE,
          FOREIGN KEY(productCode) REFERENCES products(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS inventory_sessions(
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'open'
        )''',
        '''
        CREATE TABLE IF NOT EXISTS inventory_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId TEXT NOT NULL,
          productCode TEXT NOT NULL,
          productName TEXT NOT NULL,
          expectedQty REAL NOT NULL DEFAULT 0,
          actualQty REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(sessionId) REFERENCES inventory_sessions(id) ON DELETE CASCADE,
          UNIQUE(sessionId, productCode)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS stock_movements(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productCode TEXT NOT NULL,
          type TEXT NOT NULL,
          referenceId TEXT NOT NULL,
          quantity REAL NOT NULL,
          beforeQty REAL NOT NULL,
          afterQty REAL NOT NULL,
          createdAt TEXT NOT NULL,
          FOREIGN KEY(productCode) REFERENCES products(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS sequences(
          key TEXT PRIMARY KEY,
          lastNumber INTEGER NOT NULL DEFAULT 0
        )''',
        '''
        CREATE TABLE IF NOT EXISTS app_settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )''',
        // ── جديد v2 ──
        '''
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'مستخدم'
        )''',
        '''
        CREATE TABLE IF NOT EXISTS user_permissions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          job TEXT NOT NULL,
          allowed INTEGER NOT NULL DEFAULT 1,
          UNIQUE(username, job)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS warehouses(
          code TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          createdAt TEXT
        )''',
        '''
        CREATE TABLE IF NOT EXISTS product_codes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productCode TEXT NOT NULL,
          barcode TEXT NOT NULL,
          qty REAL NOT NULL DEFAULT 0,
          weight REAL NOT NULL DEFAULT 0,
          unit TEXT NOT NULL DEFAULT 'KG',
          mark TEXT NOT NULL DEFAULT '1',
          dateFmt TEXT NOT NULL DEFAULT 'DD/MM/YYYY',
          value REAL NOT NULL DEFAULT 0,
          wStart INTEGER NOT NULL DEFAULT 0,
          wEnd INTEGER NOT NULL DEFAULT 0,
          cStart INTEGER NOT NULL DEFAULT 0,
          cEnd INTEGER NOT NULL DEFAULT 0,
          dStart INTEGER NOT NULL DEFAULT 0,
          dEnd INTEGER NOT NULL DEFAULT 0,
          mStart INTEGER NOT NULL DEFAULT 0,
          mEnd INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(productCode) REFERENCES products(code) ON DELETE CASCADE
        )''',
        '''
        CREATE TABLE IF NOT EXISTS op_headers(
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          partyType TEXT NOT NULL DEFAULT '',
          partyCode TEXT NOT NULL DEFAULT '',
          partyName TEXT NOT NULL DEFAULT '',
          num INTEGER NOT NULL DEFAULT 0,
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          byUser TEXT NOT NULL DEFAULT '',
          totalQty REAL NOT NULL DEFAULT 0,
          totalWeight REAL NOT NULL DEFAULT 0,
          totalPrice REAL NOT NULL DEFAULT 0,
          totalItems INTEGER NOT NULL DEFAULT 0,
          cash INTEGER NOT NULL DEFAULT 0,
          reqQty REAL NOT NULL DEFAULT 0,
          reqWeight REAL NOT NULL DEFAULT 0
        )''',
        '''
        CREATE TABLE IF NOT EXISTS op_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          opId TEXT NOT NULL,
          productCode TEXT NOT NULL,
          productName TEXT NOT NULL,
          quantity REAL NOT NULL,
          weight REAL NOT NULL DEFAULT 0,
          price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(opId) REFERENCES op_headers(id) ON DELETE CASCADE
        )''',
        'CREATE INDEX IF NOT EXISTS idx_products_desc ON products(description)',
        'CREATE INDEX IF NOT EXISTS idx_products_active ON products(isActive)',
        'CREATE INDEX IF NOT EXISTS idx_receipt_items_receipt ON receipt_items(receiptId)',
        'CREATE INDEX IF NOT EXISTS idx_delivery_items_delivery ON delivery_items(deliveryId)',
        'CREATE INDEX IF NOT EXISTS idx_movements_product ON stock_movements(productCode)',
        'CREATE INDEX IF NOT EXISTS idx_movements_ref ON stock_movements(referenceId)',
        'CREATE INDEX IF NOT EXISTS idx_inv_items_session ON inventory_items(sessionId)',
        'CREATE INDEX IF NOT EXISTS idx_receipts_date ON receipts(date)',
        'CREATE INDEX IF NOT EXISTS idx_deliveries_date ON deliveries(date)',
        'CREATE INDEX IF NOT EXISTS idx_op_kind ON op_headers(kind)',
        'CREATE INDEX IF NOT EXISTS idx_op_items_op ON op_items(opId)',
        'CREATE INDEX IF NOT EXISTS idx_codes_product ON product_codes(productCode)',
        // فهارس البحث بالباركود عند المسح — بدونها كل مسحة تفحص الجدول كله
        // (سبب البطء "بياخد ثانية"). تُطبق على القديم تلقائيًا عبر onUpgrade.
        'CREATE INDEX IF NOT EXISTS idx_codes_barcode ON product_codes(barcode)',
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
      ];

  /// أعمدة v2 على الجداول القديمة — تُطبق فقط على الأعمدة الناقصة فعلًا
  /// (يفحص PRAGMA table_info أولًا حتى لا يظهر duplicate column في اللوج).
  static Map<String, List<String>> v2Alters() => const {
        'products': [
          "ALTER TABLE products ADD COLUMN weightType TEXT NOT NULL DEFAULT 'متغير'",
          "ALTER TABLE products ADD COLUMN fixedWeight REAL NOT NULL DEFAULT 0",
          "ALTER TABLE products ADD COLUMN barcode TEXT",
          "ALTER TABLE products ADD COLUMN hasCode INTEGER NOT NULL DEFAULT 1",
          "ALTER TABLE products ADD COLUMN hasWeight INTEGER NOT NULL DEFAULT 1",
          "ALTER TABLE products ADD COLUMN hasDate INTEGER NOT NULL DEFAULT 1",
          "ALTER TABLE products ADD COLUMN hasMazraa INTEGER NOT NULL DEFAULT 1",
        ],
        'receipts': [
          "ALTER TABLE receipts ADD COLUMN totalWeight REAL NOT NULL DEFAULT 0",
          "ALTER TABLE receipts ADD COLUMN totalPrice REAL NOT NULL DEFAULT 0",
          "ALTER TABLE receipts ADD COLUMN cash INTEGER NOT NULL DEFAULT 0",
          "ALTER TABLE receipts ADD COLUMN byUser TEXT NOT NULL DEFAULT ''",
          "ALTER TABLE receipts ADD COLUMN num INTEGER NOT NULL DEFAULT 0",
          "ALTER TABLE receipts ADD COLUMN reqQty REAL NOT NULL DEFAULT 0",
          "ALTER TABLE receipts ADD COLUMN reqWeight REAL NOT NULL DEFAULT 0",
        ],
        'receipt_items': [
          "ALTER TABLE receipt_items ADD COLUMN weight REAL NOT NULL DEFAULT 0",
          "ALTER TABLE receipt_items ADD COLUMN price REAL NOT NULL DEFAULT 0",
        ],
        'deliveries': [
          "ALTER TABLE deliveries ADD COLUMN totalWeight REAL NOT NULL DEFAULT 0",
          "ALTER TABLE deliveries ADD COLUMN totalPrice REAL NOT NULL DEFAULT 0",
          "ALTER TABLE deliveries ADD COLUMN cash INTEGER NOT NULL DEFAULT 0",
          "ALTER TABLE deliveries ADD COLUMN byUser TEXT NOT NULL DEFAULT ''",
          "ALTER TABLE deliveries ADD COLUMN num INTEGER NOT NULL DEFAULT 0",
          "ALTER TABLE deliveries ADD COLUMN reqQty REAL NOT NULL DEFAULT 0",
          "ALTER TABLE deliveries ADD COLUMN reqWeight REAL NOT NULL DEFAULT 0",
        ],
        'delivery_items': [
          "ALTER TABLE delivery_items ADD COLUMN weight REAL NOT NULL DEFAULT 0",
          "ALTER TABLE delivery_items ADD COLUMN price REAL NOT NULL DEFAULT 0",
        ],
        // op_headers جدول جديد في v2 ويُنشأ بالأعمدة كاملة — لا يحتاج ALTER.
      };

  /// أعمدة v3 — مقاطع الباركود على product_codes.
  static Map<String, List<String>> v3Alters() => const {
        'product_codes': [
          'ALTER TABLE product_codes ADD COLUMN wStart INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN wEnd INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN cStart INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN cEnd INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN dStart INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN dEnd INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN mStart INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE product_codes ADD COLUMN mEnd INTEGER NOT NULL DEFAULT 0',
        ],
      };

  /// أعمدة v5 — سعر البيع الافتراضي على products.
  static Map<String, List<String>> v5Alters() => const {
        'products': [
          'ALTER TABLE products ADD COLUMN price REAL NOT NULL DEFAULT 0',
        ],
      };
}
