import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'diyon_yawmiyah.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
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
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.insert('settings', {'key': 'currency', 'value': 'ر.ي'});
      },
    );
    await _db!.execute('PRAGMA foreign_keys = ON');
    return _db!;
  }

  Future<List<Map<String, Object?>>> customers() async {
    final db = await database;
    return db.rawQuery('''
      SELECT c.*, COALESCE(SUM(CASE WHEN t.type='debt' THEN t.amount ELSE -t.amount END),0) AS balance
      FROM customers c LEFT JOIN transactions t ON t.customer_id=c.id
      GROUP BY c.id ORDER BY c.name COLLATE NOCASE
    ''');
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
    return db.insert('transactions', {
      'customer_id': customerId, 'type': type, 'amount': amount,
      'note': note.trim(), 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> ledger(int customerId) async {
    final db = await database;
    return db.query('transactions', where: 'customer_id=?', whereArgs: [customerId], orderBy: 'created_at DESC, id DESC');
  }

  Future<Map<String, double>> totals() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT
        COALESCE(SUM(CASE WHEN type='debt' THEN amount ELSE 0 END),0) AS debts,
        COALESCE(SUM(CASE WHEN type='payment' THEN amount ELSE 0 END),0) AS payments
      FROM transactions
    """);
    final row = rows.first;
    return {
      'debts': (row['debts'] as num).toDouble(),
      'payments': (row['payments'] as num).toDouble(),
    };
  }

  Future<String> getCurrency() async {
    final db = await database;
    final rows = await db.query('settings', where: 'key=?', whereArgs: ['currency'], limit: 1);
    return rows.isEmpty ? 'ر.ي' : rows.first['value'] as String;
  }

  Future<void> setCurrency(String value) async {
    final db = await database;
    await db.insert('settings', {'key': 'currency', 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>> exportAll() async {
    final db = await database;
    return {
      'format': 'diyon-yawmiyah-backup',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'customers': await db.query('customers', orderBy: 'id'),
      'transactions': await db.query('transactions', orderBy: 'id'),
      'settings': await db.query('settings'),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['format'] != 'diyon-yawmiyah-backup' ||
        data['customers'] is! List || data['transactions'] is! List) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('customers');
      if (data['settings'] is List) await txn.delete('settings');
      for (final item in data['customers'] as List) {
        await txn.insert('customers', Map<String, Object?>.from(item as Map));
      }
      if (data['settings'] is List) {
        for (final item in data['settings'] as List) {
          await txn.insert('settings', Map<String, Object?>.from(item as Map));
        }
      } else {
        await txn.insert('settings', {'key': 'currency', 'value': 'ر.ي'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final item in data['transactions'] as List) {
        await txn.insert('transactions', Map<String, Object?>.from(item as Map));
      }
    });
  }
}
