import 'dart:convert';
import 'package:http/http.dart' as http;

// ==================== API SERVICE ====================
class ApiService {
  // Địa chỉ Cloudflare Worker.
  static const String baseUrl =
      'https://attendance-cloudflare.quangcuongdk1.workers.dev';

  // Kiểm tra kết nối Cloudflare Worker và D1.
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data is Map<String, dynamic> &&
            data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Lỗi kết nối Cloudflare: $e');
      return false;
    }
      }

  // Lấy danh sách sinh viên từ Cloudflare D1.
  static Future<List<dynamic>> getStudents() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/students'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Không lấy được danh sách sinh viên.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic> && data['success'] == true) {
      return data['data'] as List<dynamic>? ?? [];
    }

    throw Exception('Dữ liệu sinh viên từ Cloudflare không hợp lệ.');
  }

  // Lấy sinh viên trên Cloudflare D1 theo mã sinh viên.
  static Future<Map<String, dynamic>?> getStudentByCode(
    String studentCode,
  ) async {
    try {
      final students = await getStudents();

      for (final student in students) {
        if (student is Map<String, dynamic>) {
          if (student['student_code']?.toString() == studentCode) {
            return student;
          }
        }
      }

      return null;
    } catch (e) {
      print('Lỗi tìm sinh viên trên Cloudflare: $e');
      rethrow;
    }
  }

  // Thêm sinh viên vào Cloudflare D1.
  static Future<Map<String, dynamic>> addStudent({
    required String studentCode,
    required String fullName,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/students'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'student_code': studentCode,
            'full_name': fullName,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Không thể thêm sinh viên lên Cloudflare D1.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw Exception('Dữ liệu trả về từ Cloudflare không hợp lệ.');
  }

  // Lưu embedding khuôn mặt vào Cloudflare D1.
  static Future<Map<String, dynamic>> saveFaceEmbedding({
    required int userId,
    required List<double> embedding,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/face-data'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'user_id': userId,
            'embedding': embedding,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Không thể lưu dữ liệu khuôn mặt lên Cloudflare D1.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw Exception('Dữ liệu embedding từ Cloudflare không hợp lệ.');
  }

  // Lấy danh sách lớp học từ Cloudflare D1.
  static Future<List<dynamic>> getClasses() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/classes'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Không lấy được danh sách lớp học.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic> && data['success'] == true) {
      return data['data'] as List<dynamic>? ?? [];
    }

    throw Exception('Dữ liệu lớp học từ Cloudflare không hợp lệ.');
  }

  // Lưu dữ liệu điểm danh vào Cloudflare D1.
  static Future<Map<String, dynamic>> saveAttendance({
    required int userId,
    required int classId,
    required double latitude,
    required double longitude,
    required double distance,
    required double faceSimilarity,
    required String status,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/attendance'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'user_id': userId,
            'class_id': classId,
            'latitude': latitude,
            'longitude': longitude,
            'distance': distance,
            'face_similarity': faceSimilarity,
            'status': status,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Không thể lưu điểm danh lên Cloudflare D1.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw Exception('Dữ liệu điểm danh từ Cloudflare không hợp lệ.');
  }

  // Lấy lịch sử điểm danh từ Cloudflare D1.
  static Future<List<dynamic>> getAttendance() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/attendance'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Không lấy được lịch sử điểm danh.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic> && data['success'] == true) {
      return data['data'] as List<dynamic>? ?? [];
    }

    throw Exception('Dữ liệu lịch sử điểm danh không hợp lệ.');
  }
  // Lấy embedding khuôn mặt mới nhất từ Cloudflare D1.
  static Future<List<dynamic>> getFaceData() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/face-data'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Không lấy được dữ liệu khuôn mặt từ Cloudflare.\n'
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic> && data['success'] == true) {
      return data['data'] as List<dynamic>? ?? [];
    }

    throw Exception('Dữ liệu khuôn mặt từ Cloudflare không hợp lệ.');
  }
}