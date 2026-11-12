import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'student_auth.dart';

/// Dữ liệu được đọc trực tiếp từ Cloudflare D1, không phụ thuộc SQLite trên máy.
class AttendanceHistoryPage extends StatefulWidget {
  final StudentSession session;
  const AttendanceHistoryPage({super.key, required this.session});
  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  List<Map<String,dynamic>> _rows = [];
  List<Map<String,dynamic>> _schedules = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<List<Map<String,dynamic>>> _get(String path) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}$path'),
      headers: {'Authorization':'Bearer ${widget.session.token}'})
      .timeout(const Duration(seconds:15));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || response.statusCode >= 300 || decoded['success'] != true) {
      throw Exception(decoded is Map ? (decoded['message'] ?? 'Máy chủ không phản hồi đúng') : 'Phản hồi không hợp lệ');
    }
    final values = decoded['data'];
    return values is List ? values.map((x)=>Map<String,dynamic>.from(x as Map)).toList() : [];
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await Future.wait([
        _get('/api/student/attendance-history'),
        _get('/api/student/schedules'),
      ]);
      if (!mounted) return;
      setState(() { _rows = data[0]; _schedules = data[1]; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString())?.toLocal();
    if (d == null) return raw.toString();
    String f(int v) => v.toString().padLeft(2,'0');
    return '${f(d.day)}/${f(d.month)}/${d.year}  ${f(d.hour)}:${f(d.minute)}';
  }

  String _status(dynamic value) {
    switch (value?.toString()) {
      case 'on_time': return 'Đúng giờ';
      case 'late': return 'Đi muộn';
      case 'absent': return 'Vắng';
      default: return 'Chưa có kết quả';
    }
  }
  Color _statusColor(dynamic value) {
    switch (value?.toString()) {
      case 'on_time': return Colors.green.shade700;
      case 'late': return Colors.orange.shade800;
      case 'absent': return Colors.red.shade700;
      default: return Colors.blueGrey;
    }
  }

  Widget _historyCard(Map<String,dynamic> row) {
    final state = row['status'];
    final color = _statusColor(state);
    final similarity = num.tryParse('${row['face_similarity']}');
    final distance = num.tryParse('${row['distance']}');
    return Card(margin: const EdgeInsets.only(bottom:10),
      child: Padding(padding: const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(state=='on_time' ? Icons.check_circle_rounded : state=='late' ? Icons.watch_later : state=='absent' ? Icons.cancel : Icons.schedule,
            color:color,size:28),
          const SizedBox(width:10),
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${row['subject_name'] ?? 'Môn học'}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),
            Text('${row['class_code'] ?? ''} • ${row['room'] ?? ''}',style:Theme.of(context).textTheme.bodySmall),
          ])),
          Text(_status(state),style:TextStyle(color:color,fontWeight:FontWeight.w700)),
        ]),
        const Divider(height:20),
        Text('Bắt đầu: ${_date(row['starts_at'])}'),
        if (row['checked_at'] != null) Text('Đã điểm danh: ${_date(row['checked_at'])}'),
        if (distance != null) Text('Khoảng cách: ${distance.toStringAsFixed(1)} m'),
        if (similarity != null) Text('Độ tương đồng: ${(similarity*100).toStringAsFixed(1)}%'),
      ])));
  }

  Widget _scheduleCard(Map<String,dynamic> row) {
    return Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(
      leading: const Icon(Icons.event_note_rounded,color:Colors.indigo),
      title: Text('${row['subject_name'] ?? 'Môn học'}',style:const TextStyle(fontWeight:FontWeight.w600)),
      subtitle: Text('${row['class_code'] ?? ''} • Phòng ${row['room'] ?? '—'}\n${_date(row['starts_at'])}'),
      isThreeLine:true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _tab==0 ? _rows : _schedules;
    final filtered = _tab==0 ? rows.where((r)=>r['status']=='on_time'||r['status']=='late'||r['status']=='absent').toList() : rows;
    return Scaffold(
      appBar: AppBar(title:const Text('Lịch sử & lịch điểm danh'),actions:[
        IconButton(onPressed:_load,icon:const Icon(Icons.refresh),tooltip:'Làm mới'),
      ]),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<int>(
          segments:const [
            ButtonSegment(value:0,icon:Icon(Icons.fact_check_outlined),label:Text('Kết quả')),
            ButtonSegment(value:1,icon:Icon(Icons.calendar_month),label:Text('Lịch học')),
          ],
          selected:{_tab},onSelectionChanged:(v)=>setState(()=>_tab=v.first),
        )),
        Expanded(child:_loading ? const Center(child:CircularProgressIndicator())
          : _error != null ? Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(
                mainAxisSize:MainAxisSize.min,children:[
                  Text('Không tải được dữ liệu: $_error',textAlign:TextAlign.center),
                  const SizedBox(height:12),OutlinedButton(onPressed:_load,child:const Text('Thử lại')),
                ])))
          : RefreshIndicator(onRefresh:_load,child:ListView(
            physics:const AlwaysScrollableScrollPhysics(),
            padding:const EdgeInsets.fromLTRB(12,2,12,24),children:[
              if(filtered.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:90),child:Column(children:[
                Icon(Icons.event_busy,size:58,color:Colors.grey),
                SizedBox(height:12),Text('Chưa có dữ liệu',style:TextStyle(fontSize:16)),
              ])),
              if(_tab==0) ...filtered.map(_historyCard) else ...filtered.map(_scheduleCard),
            ],))),
      ]),
    );
  }
}
