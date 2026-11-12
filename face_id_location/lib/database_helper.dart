import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'attendance.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(
    Database db,
    int version,
  ) async {
    // =========================
    // BẢNG USERS
    // =========================
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_code TEXT UNIQUE,
        full_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // =========================
    // BẢNG CLASSES
    // =========================
    await db.execute('''
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_code TEXT NOT NULL,
        class_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL
      )
    ''');

    // =========================
    // BẢNG FACE DATA
    // =========================
    await db.execute('''
      CREATE TABLE face_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        embedding TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // =========================
    // BẢNG ATTENDANCE
    // =========================
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        attendance_time TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        distance REAL NOT NULL,
        face_similarity REAL NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (class_id) REFERENCES classes(id)
      )
    ''');

    // =========================
    // TẠO LỚP MẶC ĐỊNH
    // =========================
    await db.insert(
      'classes',
      {
        'class_code': 'CLASS01',
        'class_name': 'Lớp học',
        'latitude': 16.031992,
        'longitude': 108.222306,
        'radius': 100,
      },
    );
  }

  // ==========================================
  // USER
  // ==========================================

  Future<int> insertUser({
    required String studentCode,
    required String fullName,
  }) async {
    final db = await database;

    return await db.insert(
      'users',
      {
        'student_code': studentCode,
        'full_name': fullName,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<Map<String, dynamic>?> getFirstUser() async {
    final db = await database;

    final result = await db.query(
      'users',
      orderBy: 'id ASC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ==========================================
  // FACE DATA
  // ==========================================

  Future<int> saveFaceEmbedding({
    required int userId,
    required String embedding,
  }) async {
    final db = await database;

    await db.delete(
      'face_data',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return await db.insert(
      'face_data',
      {
        'user_id': userId,
        'embedding': embedding,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==========================================
  // ATTENDANCE
  // ==========================================

  Future<int> insertAttendance({
    required int userId,
    required int classId,
    required double latitude,
    required double longitude,
    required double distance,
    required double faceSimilarity,
    required String status,
  }) async {
    final db = await database;

    return await db.insert(
      'attendance',
      {
        'user_id': userId,
        'class_id': classId,
        'attendance_time': DateTime.now().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'distance': distance,
        'face_similarity': faceSimilarity,
        'status': status,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT
        attendance.id,
        users.student_code,
        users.full_name,
        classes.class_code,
        classes.class_name,
        attendance.attendance_time,
        attendance.latitude,
        attendance.longitude,
        attendance.distance,
        attendance.face_similarity,
        attendance.status
      FROM attendance
      INNER JOIN users
        ON attendance.user_id = users.id
      INNER JOIN classes
        ON attendance.class_id = classes.id
      ORDER BY attendance.attendance_time DESC
    ''');
  }
  Future<Map<String, dynamic>?> getUserByStudentCode(String studentCode) async {
    final db = await database;

    final result = await db.query(
      'users',
      where: 'student_code = ?',
      whereArgs: [studentCode],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first;
  }
  Future<List<double>?> getFaceEmbedding(int userId) async {
    final db = await database;

    final result = await db.query(
      'face_data',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final embeddingString = result.first['embedding'] as String;

    return embeddingString
        .split(',')
        .map((e) => double.tryParse(e) ?? 0.0)
        .toList();
  }

  // ==========================================
  // XÓA TOÀN BỘ DATABASE
  // ==========================================
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;

    return await db.query(
      'users',
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsersWithFace() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT
        users.id,
        users.student_code,
        users.full_name,
        face_data.embedding
      FROM users
      INNER JOIN face_data
        ON users.id = face_data.user_id
      ORDER BY users.id ASC
    ''');
  }
  Future<void> clearAttendance() async {
    final db = await database;

    await db.delete('attendance');
  }
}