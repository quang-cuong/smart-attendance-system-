import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'student_auth.dart';
import 'animated_tech_background.dart';

/// Màn hình Lịch học Học sinh / Sinh viên chuẩn mẫu 100%
class StudentSchedulePage extends StatefulWidget {
  final StudentSession session;
  const StudentSchedulePage({super.key, required this.session});

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> {
  // Mode: 'day', 'week', 'month'
  String _viewMode = 'day';

  DateTime _selectedDate = DateTime.now();

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allSchedule = [];

  @override
  void initState() {
    super.initState();
    _fetchScheduleData();
  }

  Future<void> _fetchScheduleData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/student/schedules'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(resp.body);
      List<Map<String, dynamic>> fetchedList = [];

      if (resp.statusCode == 200 && decoded['success'] == true) {
        fetchedList = List<Map<String, dynamic>>.from(
          (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }

      if (resp.statusCode != 200 || decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Không tải được lịch học.');
      }
      final realSchedule = <Map<String, dynamic>>[];

      for (final item in fetchedList) {
        final startsAt = DateTime.tryParse('${item['starts_at']}')?.toLocal() ?? DateTime.now();
        realSchedule.add({
          'subject_name': item['subject_name'] ?? 'Môn học',
          'class_code': item['class_code'] ?? 'Lớp',
          'room': item['room'] ?? 'Chưa đặt',
          'periods': '${_clock(startsAt)} – ${_clock(DateTime.tryParse("${item['ends_at']}")?.toLocal() ?? startsAt)}',
          'teacher_name': item['teacher_name'] ?? 'Chưa cập nhật',
          'notes': item['notes'] ?? 'Lịch học chính thức',
          'date': DateTime(startsAt.year, startsAt.month, startsAt.day),
        });
      }

      if (!mounted) return;
      setState(() {
        _allSchedule = realSchedule;
        if (realSchedule.isNotEmpty) {
          _selectedDate = realSchedule.first['date'] as DateTime;
          _selectedMonth = _selectedDate.month;
          _selectedYear = _selectedDate.year;
        } else {
          final now = DateTime.now();
          _selectedDate = DateTime(now.year, now.month, now.day);
          _selectedMonth = now.month;
          _selectedYear = now.year;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          final now = DateTime.now();
          _selectedDate = DateTime(now.year, now.month, now.day);
        });
      }
    }
  }

  String _clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _movePeriod(int direction) {
    setState(() {
      _selectedDate = _viewMode == 'month'
          ? DateTime(_selectedYear, _selectedMonth + direction, 1)
          : DateTime(_selectedDate.year, _selectedDate.month,
              _selectedDate.day + direction * (_viewMode == 'week' ? 7 : 1));
      _selectedYear = _selectedDate.year;
      _selectedMonth = _selectedDate.month;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getWeekdayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'Th 2';
      case DateTime.tuesday: return 'Th 3';
      case DateTime.wednesday: return 'Th 4';
      case DateTime.thursday: return 'Th 5';
      case DateTime.friday: return 'Th 6';
      case DateTime.saturday: return 'Th 7';
      case DateTime.sunday: return 'CN';
      default: return '';
    }
  }

  String _formatFullDateHeader(DateTime date) {
    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = date.month.toString().padLeft(2, '0');
    return '${_getWeekdayName(date)}, $dayStr/$monthStr/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0284C7),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Lịch học',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(tooltip: 'Trước', icon: const Icon(Icons.chevron_left), onPressed: () => _movePeriod(-1)),
          IconButton(tooltip: 'Sau', icon: const Icon(Icons.chevron_right), onPressed: () => _movePeriod(1)),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: _fetchScheduleData,
          ),
        ],
      ),
      body: AnimatedTechBackground(
        child: Column(
          children: [
            // ==================== THANH ĐIỀU HƯỚNG CHỌN NGÀY / TUẦN / THÁNG ====================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nhãn chọn thời gian theo Mode
                  if (_viewMode == 'day')
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                        );
                        if (picked != null) {
                          setState(() { _selectedDate = picked; _selectedMonth = picked.month; _selectedYear = picked.year; });
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            _formatFullDateHeader(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0F172A)),
                        ],
                      ),
                    )
                  else if (_viewMode == 'week')
                    Row(
                      children: [
                        Text('$_selectedYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Icon(Icons.arrow_drop_down_rounded),
                        const SizedBox(width: 8),
                        Text('Tuần ${_selectedDate.day}/${_selectedDate.month}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text('Tháng $_selectedMonth, $_selectedYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),

                  // Nút Toggle [ Ngày | Tuần | Tháng ]
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        _buildSegmentBtn('day', 'Ngày'),
                        _buildSegmentBtn('week', 'Tuần'),
                        _buildSegmentBtn('month', 'Tháng'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // NỘI DUNG THEO MODE
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                  : _error != null
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: const TextStyle(color: Colors.white)), TextButton(onPressed: _fetchScheduleData, child: const Text('Thử lại'))]))
                      : _viewMode == 'day'
                      ? _buildDayView()
                      : _viewMode == 'week'
                          ? _buildWeekView()
                          : _buildMonthView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentBtn(String mode, String label) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ==================== MODE 1: NGÀY ====================
  Widget _buildDayView() {
    final dayClasses = _allSchedule.where((s) => _isSameDay(s['date'] as DateTime, _selectedDate)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (dayClasses.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'Không có lịch học trong ngày này.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          )
        else
          ...dayClasses.map((item) => _buildScheduleCard(item)),
      ],
    );
  }

  // ==================== MODE 2: TUẦN ====================
  Widget _buildWeekView() {
    // 7 ngày trong tuần từ Thứ 2 (26/10) đến CN (01/11)
    final startOfWeek = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day - (_selectedDate.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Column(
      children: [
        // Thanh chọn 7 ngày trong tuần dạng cuộn ngang
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((dayDate) {
              final isSelected = _isSameDay(dayDate, _selectedDate);
              final dayNumStr = dayDate.day.toString().padLeft(2, '0');
              final isSunday = dayDate.weekday == DateTime.sunday;

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = dayDate),
                child: Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getWeekdayName(dayDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : (isSunday ? Colors.red : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayNumStr,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isSunday ? Colors.red : Colors.black87),
                        ),
                      ),
                      if (_allSchedule.any((s) => _isSameDay(s['date'] as DateTime, dayDate)))
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 14,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.redAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Danh sách môn học nhóm theo các ngày trong tuần
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: weekDays.map((dayDate) {
              final dayClasses = _allSchedule.where((s) => _isSameDay(s['date'] as DateTime, dayDate)).toList();
              if (dayClasses.isEmpty) return const SizedBox.shrink();

              final dayTitle = '${_getWeekdayName(dayDate)}, ${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pill nhãn ngày
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dayTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                  ...dayClasses.map((item) => _buildScheduleCard(item)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==================== MODE 3: THÁNG ====================
  Widget _buildMonthView() {
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day; // Tháng 11/2026 có 30 ngày
    final startWeekday = DateTime(_selectedYear, _selectedMonth, 1).weekday; // Ngày 01/11/2026 là Chủ nhật (CN)

    final monthGridDays = <DateTime?>[];
    // Padding cho tuần đầu
    for (int i = 1; i < startWeekday; i++) {
      monthGridDays.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      monthGridDays.add(DateTime(_selectedYear, _selectedMonth, i));
    }

    final dayClasses = _allSchedule.where((s) => _isSameDay(s['date'] as DateTime, _selectedDate)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Lưới Lịch Tháng Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // Header hàng thứ
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Th 2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Th 3', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Th 4', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Th 5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Th 6', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Th 7', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                  Text('CN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),

              // Lưới ngày 7 cột
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: monthGridDays.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, idx) {
                  final dayDate = monthGridDays[idx];
                  if (dayDate == null) return const SizedBox.shrink();

                  final isSelected = _isSameDay(dayDate, _selectedDate);
                  final hasClass = _allSchedule.any((s) => _isSameDay(s['date'] as DateTime, dayDate));

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = dayDate),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${dayDate.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          if (hasClass)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tiêu đề ngày chọn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${_getWeekdayName(_selectedDate)}, ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),

        const SizedBox(height: 12),

        if (dayClasses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Không có lịch học trong ngày này.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ...dayClasses.map((item) => _buildScheduleCard(item)),
      ],
    );
  }

  // ==================== WIDGET THẺ LỊCH HỌC CHUẨN 100% ẢNH MẪU ====================
  Widget _buildScheduleCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Thanh viền nổi bật màu xanh lá chạy dọc bên trái
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 6,
                color: const Color(0xFF10B981), // Green highlight
              ),
            ),

            // Nội dung thẻ Lịch học
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Huy hiệu "• Lịch học"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '• Lịch học',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tên Môn Học
                  Text(
                    item['subject_name'] ?? 'Môn học',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bảng chi tiết Tiết, Phòng, Giảng viên, Ghi chú
                  _buildDetailRow('Giờ:', item['periods'] ?? 'Chưa cập nhật'),
                  const SizedBox(height: 6),
                  _buildDetailRow('Phòng:', item['room'] ?? '101'),
                  const SizedBox(height: 6),
                  _buildDetailRow('Giảng viên:', item['teacher_name'] ?? 'Giảng viên'),
                  if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow('Ghi chú:', item['notes'].toString()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
