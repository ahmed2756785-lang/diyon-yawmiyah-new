import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

String appCurrency = 'ر.ي';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final pending = _opening;
    if (pending != null) return pending;
    final future = _open();
    _opening = future;
    try { return await future; } finally { _opening = null; }
  }

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    final db = await openDatabase(
      p.join(root, 'diyon_yawmiyah.db'),
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
        await db.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            archived_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_transactions_customer ON transactions(customer_id)');
        await db.execute('CREATE INDEX idx_customers_archived ON customers(archived_at)');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('settings', {'key': 'currency', 'value': 'ر.ي'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE customers ADD COLUMN archived_at TEXT');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_archived ON customers(archived_at)');
        }
      },
    );
    _db = db;
    return db;
  }

  Future<List<Map<String, Object?>>> customers() async {
    final db = await database;
    return db.rawQuery("""
      SELECT c.*, COALESCE(SUM(CASE WHEN t.type='debt' THEN t.amount ELSE -t.amount END),0) AS balance
      FROM customers c LEFT JOIN transactions t ON t.customer_id=c.id
      WHERE c.archived_at IS NULL
      GROUP BY c.id ORDER BY c.name COLLATE NOCASE
    """);
  }

  Future<List<Map<String, Object?>>> archivedCustomers() async {
    final db = await database;
    return db.rawQuery("""
      SELECT c.*, COALESCE(SUM(CASE WHEN t.type='debt' THEN t.amount ELSE -t.amount END),0) AS balance
      FROM customers c LEFT JOIN transactions t ON t.customer_id=c.id
      WHERE c.archived_at IS NOT NULL
      GROUP BY c.id ORDER BY c.archived_at DESC
    """);
  }

  Future<int> addCustomer(String name, String phone, String note) async {
    final db = await database;
    return db.insert('customers', {
      'name': name.trim(), 'phone': phone.trim(), 'note': note.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> addTransaction(int customerId, String type, double amount, String note) async {
    final db = await database;
    return db.transaction((txn) => txn.insert('transactions', {
      'customer_id': customerId, 'type': type, 'amount': amount,
      'note': note.trim(), 'created_at': DateTime.now().toIso8601String(),
    }));
  }

  Future<List<Map<String, Object?>>> ledger(int customerId) async {
    final db = await database;
    return db.query('transactions', where: 'customer_id=?', whereArgs: [customerId], orderBy: 'created_at DESC, id DESC');
  }

  Future<double> customerBalance(int customerId) async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT COALESCE(SUM(CASE WHEN type='debt' THEN amount ELSE -amount END),0) AS balance
      FROM transactions WHERE customer_id=?
    """, [customerId]);
    return (rows.first['balance'] as num).toDouble();
  }

  Future<void> archiveCustomer(int customerId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery("""
        SELECT COALESCE(SUM(CASE WHEN type='debt' THEN amount ELSE -amount END),0) AS balance
        FROM transactions WHERE customer_id=?
      """, [customerId]);
      final balance = (rows.first['balance'] as num).toDouble();
      if (balance > 0.000001) throw StateError('لا يمكن أرشفة العميل قبل تسوية كامل الدين');
      await txn.update('customers', {'archived_at': DateTime.now().toIso8601String()},
        where: 'id=? AND archived_at IS NULL', whereArgs: [customerId]);
    });
  }

  Future<void> restoreCustomer(int customerId) async {
    final db = await database;
    await db.update('customers', {'archived_at': null}, where: 'id=?', whereArgs: [customerId]);
  }

  Future<Map<String, double>> totals() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT
        COALESCE(SUM(CASE WHEN type='debt' THEN amount ELSE 0 END),0) AS debts,
        COALESCE(SUM(CASE WHEN type='payment' THEN amount ELSE 0 END),0) AS payments
      FROM transactions INNER JOIN customers ON customers.id=transactions.customer_id
      WHERE customers.archived_at IS NULL
    """);
    final row = rows.first;
    return {'debts': (row['debts'] as num).toDouble(), 'payments': (row['payments'] as num).toDouble()};
  }

  Future<String> getCurrency() async {
    final db = await database;
    final rows = await db.query('settings', where: 'key=?', whereArgs: ['currency'], limit: 1);
    appCurrency = rows.isEmpty ? 'ر.ي' : rows.first['value'] as String;
    return appCurrency;
  }

  Future<void> setCurrency(String value) async {
    final db = await database;
    await db.insert('settings', {'key': 'currency', 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    appCurrency = value;
  }

  Future<Map<String, Object?>> exportAll() async {
    final db = await database;
    return {
      'format': 'diyon-yawmiyah-backup', 'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'customers': await db.query('customers', orderBy: 'id'),
      'transactions': await db.query('transactions', orderBy: 'id'),
      'settings': await db.query('settings'),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['format'] != 'diyon-yawmiyah-backup' || data['customers'] is! List || data['transactions'] is! List) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('customers');
      if (data['settings'] is List) await txn.delete('settings');
      for (final item in data['customers'] as List) {
        final customer = Map<String, Object?>.from(item as Map);
        customer.putIfAbsent('archived_at', () => null);
        await txn.insert('customers', customer);
      }
      if (data['settings'] is List) {
        for (final item in data['settings'] as List) {
          await txn.insert('settings', Map<String, Object?>.from(item as Map));
        }
      } else {
        await txn.insert('settings', {'key': 'currency', 'value': 'ر.ي'}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final item in data['transactions'] as List) {
        await txn.insert('transactions', Map<String, Object?>.from(item as Map));
      }
    });
    await getCurrency();
  }
}