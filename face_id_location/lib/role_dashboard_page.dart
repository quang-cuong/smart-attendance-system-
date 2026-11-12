import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'student_auth.dart';
import 'student_login_page.dart';
import 'animated_tech_background.dart';

/// Trang đọc dữ liệu theo quyền giáo viên/phụ huynh với giao diện Tab hiện đại
class RoleDashboardPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final StudentSession session;
  const RoleDashboardPage({
    super.key,
    required this.cameras,
    required this.session,
  });

  @override
  State<RoleDashboardPage> createState() => _RoleDashboardPageState();
}

class _RoleDashboardPageState extends State<RoleDashboardPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> sessions = [];
  Map<int, List<Map<String, dynamic>>> reports = {};
  Timer? timer;
  Set<int> alerted = {};
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _refresh();
    timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshSessions(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshSessions() async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/sessions'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode != 200 || data['success'] != true) return;
      final rows = List<Map<String, dynamic>>.from(
        (data['data'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      if (!mounted) return;
      setState(() => sessions = rows);
      for (final row in rows.where((r) => r['phase'] == 'closed')) {
        final id = int.tryParse('${row['id']}') ?? 0;
        if (!alerted.contains(id)) {
          alerted.add(id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã kết thúc điểm danh: ${row['subject_name']}. Nhấn Xem kết quả để cập nhật.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi phiên cho vai trò: $e');
    }
  }

  Future<void> _loadReport(int sessionId) async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/sessions/$sessionId/results'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'Lỗi tải kết quả');
      }
      if (!mounted) return;
      setState(
        () => reports[sessionId] = List<Map<String, dynamic>>.from(
          (data['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await StudentAuth.roleAttendance(widget.session.token);
      if (!mounted) return;
      setState(
        () => items =
            rows.map((x) => Map<String, dynamic>.from(x as Map)).toList(),
      );
      await _refreshSessions();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get roleName =>
      widget.session.role == 'teacher' ? 'Giáo viên' : 'Phụ huynh';

  String _formatDateTime(String rawDate) {
    if (rawDate.isEmpty) return 'Chưa xác định';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute - $day/$month/$year';
    } catch (_) {
      return rawDate;
    }
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'on_time':
      case 'success':
        bg = Colors.green.withOpacity(0.18);
        text = Colors.greenAccent;
        label = 'Đúng giờ';
        icon = Icons.check_circle_rounded;
        break;
      case 'late':
        bg = Colors.orange.withOpacity(0.18);
        text = Colors.orangeAccent;
        label = 'Đi muộn';
        icon = Icons.access_time_filled_rounded;
        break;
      case 'absent':
        bg = Colors.red.withOpacity(0.18);
        text = Colors.redAccent;
        label = 'Vắng mặt';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = Colors.blue.withOpacity(0.18);
        text = Colors.blueAccent;
        label = status.isNotEmpty ? status : 'Chưa điểm danh';
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(String phase) {
    Color bg;
    Color text;
    String label;

    switch (phase.toLowerCase()) {
      case 'open':
        bg = Colors.green.withOpacity(0.2);
        text = Colors.greenAccent;
        label = 'ĐANG ĐIỂM DANH';
        break;
      case 'closed':
        bg = Colors.grey.withOpacity(0.25);
        text = Colors.white70;
        label = 'ĐÃ KẾT THÚC';
        break;
      default:
        bg = Colors.amber.withOpacity(0.2);
        text = Colors.amberAccent;
        label = 'SẮP MỞ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                ),
                child: Icon(
                  widget.session.role == 'teacher'
                      ? Icons.school_rounded
                      : Icons.family_restroom_rounded,
                  color: Colors.cyanAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    widget.session.username,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => StudentLoginPage(cameras: widget.cameras),
                ),
                (_) => false,
              ),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.cyanAccent,
            indicatorWeight: 3,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_rounded, size: 20),
                text: 'PHIÊN ĐIỂM DANH',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_rounded, size: 20),
                text: 'LỊCH SỬ CHI TIẾT',
              ),
            ],
          ),
        ),
        body: AnimatedTechBackground(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                )
              : error != null
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildSessionsTab(),
                        _buildHistoryTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  // ==================== TAB 1: PHIÊN ĐIỂM DANH ====================
  Widget _buildSessionsTab() {
    final openSessions =
        sessions.where((s) => s['phase'] == 'open').length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Thẻ tổng quan
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỔNG SỐ PHIÊN HỌC',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sessions.length} phiên',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: Colors.white12,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐANG MỞ ĐIỂM DANH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$openSessions phiên',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: const Center(
              child: Text(
                'Chưa có phiên điểm danh nào trong thời khóa biểu.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ),
          )
        else
          ...sessions.map((r) {
            final id = int.tryParse('${r['id']}') ?? 0;
            final report = reports[id];
            final phase = (r['phase'] ?? '').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: phase == 'open'
                      ? Colors.greenAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.12),
                  width: phase == 'open' ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r['subject_name']} (${r['class_code']})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _buildPhaseChip(phase),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phòng: ${r['room'] ?? 'Chưa đặt'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Bắt đầu: ${_formatDateTime(r['starts_at'] ?? '')}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.cyanAccent.withOpacity(0.2),
                              foregroundColor: Colors.cyanAccent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.cyanAccent),
                              ),
                            ),
                            onPressed: () => _loadReport(id),
                            icon: const Icon(Icons.analytics_rounded, size: 18),
                            label: const Text(
                              'XEM BÁO CÁO KẾT QUẢ PHIÊN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (report != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'DANH SÁCH HỌC SINH (${report.length} em):',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (report.isEmpty)
                              const Text(
                                'Chưa có bản ghi kết quả.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              )
                            else
                              ...report.map(
                                (x) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${x['full_name'] ?? 'Chưa tên'}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'MSSV: ${x['student_code'] ?? 'N/A'}',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.6),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildStatusChip(
                                        (x['status'] ?? '').toString(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ==================== TAB 2: LỊCH SỬ CHI TIẾT ====================
  Widget _buildHistoryTab() {
    final filteredItems = items.where((row) {
      if (_selectedFilter == 'ALL') return true;
      final status = (row['status'] ?? '').toString().toLowerCase();
      if (_selectedFilter == 'on_time') {
        return status == 'on_time' || status == 'success';
      }
      return status == _selectedFilter;
    }).toList();

    return Column(
      children: [
        // BỘ LỌC CHIPS TRẠNG THÁI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF0F172A).withOpacity(0.6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Tất cả (${items.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('on_time', 'Đúng giờ'),
                const SizedBox(width: 8),
                _buildFilterChip('late', 'Đi muộn'),
                const SizedBox(width: 8),
                _buildFilterChip('absent', 'Vắng mặt'),
              ],
            ),
          ),
        ),

        // DANH SÁCH
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'Chưa có dữ liệu điểm danh phù hợp.',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, i) {
                    final row = filteredItems[i];
                    final name = (row['full_name'] ??
                            row['student_code'] ??
                            'Sinh viên')
                        .toString();
                    final studentCode =
                        (row['student_code'] ?? '').toString();
                    final clazz = (row['class_name'] ??
                            row['class_code'] ??
                            'Chưa đặt lớp')
                        .toString();
                    final date =
                        _formatDateTime((row['attendance_time'] ?? '').toString());
                    final status = (row['status'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.75),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.person_pin_rounded,
                              color: Colors.cyanAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'MSSV: $studentCode | Lớp: $clazz',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      date,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(status),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      selectedColor: Colors.cyanAccent,
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }
}
