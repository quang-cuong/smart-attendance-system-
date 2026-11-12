import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class StudentSession {
  final String token;
  final String username;
  final int studentId; // 0 cho giáo viên/phụ huynh (không được mở màn hình quét mặt).
  final String role;
  final bool mustChangePassword;
  const StudentSession({required this.token, required this.username,
    required this.studentId, required this.role, required this.mustChangePassword});
}

class StudentAuth {
  static Future<Map<String, dynamic>> _parse(http.Response response) async {
    final dynamic parsed;
    try { parsed = jsonDecode(response.body); }
    catch (_) { throw Exception('Máy chủ phản hồi không hợp lệ (HTTP ${response.statusCode}).'); }
    if (parsed is! Map<String, dynamic>) throw Exception('Dữ liệu máy chủ không hợp lệ.');
    if (response.statusCode < 200 || response.statusCode >= 300 || parsed['success'] != true) {
      throw Exception(parsed['message']?.toString() ?? 'Yêu cầu thất bại (HTTP ${response.statusCode}).');
    }
    return parsed;
  }

  static Future<StudentSession> login(String username, String password) async {
    final response = await http.post(Uri.parse('${ApiService.baseUrl}/api/auth/login'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({'username':username.trim(),'password':password}),
    ).timeout(const Duration(seconds: 15));
    final result = await _parse(response);
    final user = result['user'];
    if (user is! Map || !['student','teacher','parent'].contains(user['role'])) {
      throw Exception('Ứng dụng chỉ hỗ trợ sinh viên, giáo viên và phụ huynh.');
    }
    final token = result['token']?.toString() ?? '';
    final studentId = int.tryParse(user['student_id']?.toString() ?? '');
    if (token.isEmpty || (user['role'] == 'student' && studentId == null)) throw Exception('Thông tin tài khoản chưa đầy đủ.');
    return StudentSession(token:token, username:user['username'].toString(),
      studentId:studentId ?? 0, role:user['role'].toString(), mustChangePassword:user['must_change_password'] == true || user['must_change_password'] == 1);
  }

  static Future<void> changePassword(StudentSession session, String oldPassword, String newPassword) async {
    final response = await http.post(Uri.parse('${ApiService.baseUrl}${session.role == 'student' ? '/api/student/change-password' : '/api/role/change-password'}'),
      headers: {'Content-Type':'application/json','Authorization':'Bearer ${session.token}'},
      body: jsonEncode({'old_password':oldPassword,'new_password':newPassword}),
    ).timeout(const Duration(seconds: 15));
    await _parse(response);
  }

  static Future<List<dynamic>> roleAttendance(String token) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/api/role/attendance'),
      headers: {'Authorization':'Bearer $token'}).timeout(const Duration(seconds: 15));
    final result = await _parse(response);
    return result['data'] is List ? result['data'] as List : [];
  }
}
