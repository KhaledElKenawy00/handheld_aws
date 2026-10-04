/// Database schema — كل الجداول + Indexes + Foreign Keys
class Schema {
  static const int version = 1;

  static List<String> createStatements() => const [
        '''
        CREATE TABLE IF NOT EXISTS products(
          code TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          stock REAL NOT NULL DEFAULT 0,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
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
          FOREIGN KEY(supplierCode) REFERENCES suppliers(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS receipt_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receiptId TEXT NOT NULL,
          productCode TEXT NOT NULL,
          productName TEXT NOT NULL,
          quantity REAL NOT NULL,
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
          FOREIGN KEY(customerCode) REFERENCES customers(code)
        )''',
        '''
        CREATE TABLE IF NOT EXISTS delivery_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          deliveryId TEXT NOT NULL,
          productCode TEXT NOT NULL,
          productName TEXT NOT NULL,
          quantity REAL NOT NULL,
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
        'CREATE INDEX IF NOT EXISTS idx_products_desc ON products(description)',
        'CREATE INDEX IF NOT EXISTS idx_products_active ON products(isActive)',
        'CREATE INDEX IF NOT EXISTS idx_receipt_items_receipt ON receipt_items(receiptId)',
        'CREATE INDEX IF NOT EXISTS idx_delivery_items_delivery ON delivery_items(deliveryId)',
        'CREATE INDEX IF NOT EXISTS idx_movements_product ON stock_movements(productCode)',
        'CREATE INDEX IF NOT EXISTS idx_movements_ref ON stock_movements(referenceId)',
        'CREATE INDEX IF NOT EXISTS idx_inv_items_session ON inventory_items(sessionId)',
        'CREATE INDEX IF NOT EXISTS idx_receipts_date ON receipts(date)',
        'CREATE INDEX IF NOT EXISTS idx_deliveries_date ON deliveries(date)',
      ];
}
