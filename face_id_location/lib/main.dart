import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' as services;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'face_recognition_service.dart';
import 'database_helper.dart';
import 'attendance_history_page.dart';
import 'api_service.dart';
import 'student_auth.dart';
import 'student_login_page.dart';
import 'animated_tech_background.dart';
import 'student_schedule_page.dart';

// ==================== KHỞI ĐỘNG ỨNG DỤNG ====================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(FaceIdLocationApp(cameras: cameras));
}

// ==================== ỨNG DỤNG CHÍNH ====================
class FaceIdLocationApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const FaceIdLocationApp({super.key, required this.cameras});

  // Hàm tạo giao diện ứng dụng.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Điểm danh thông minh',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      home: StudentLoginPage(cameras: cameras),
    );
  }
}

// ==================== TRANG ĐIỂM DANH ====================
class AttendancePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final StudentSession session;
  const AttendancePage({super.key, required this.cameras, required this.session});

  // Hàm tạo trạng thái cho trang điểm danh.
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  // ==================== FACE RECOGNITION ====================
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();
  late FaceDetector _faceDetector;
  bool _isModelReady = false, _isRegisteringFace = false, _isRecognizingFace = false, _isFaceMatched = false;
  double _faceSimilarity = 0;
  String _faceRecognitionStatus = 'Đang khởi tạo model...';

  // ==================== CAMERA ====================
  CameraController? _cameraController;
  bool _isCameraReady = false, _isDetecting = false, _cameraVisible = false, _busy = false;
  String _faceState = "loading";
  int _faceCount = 0;
  int _selectedCameraIndex = 0;

  // ==================== LOCATION ====================
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSubscription;
  Completer<bool>? _locationWaiter;
  DateTime? _lastLocationAt;
  static const double _maximumGpsAccuracy = 25.0;
  bool _isGettingLocation = false, _isInAllowedLocation = false;
  String _locationStatus = 'Chưa lấy vị trí';
//   static const double _classLatitude = 16.032114;
//   static const double _classLongitude = 108.221900;
//   static const double _allowedRadius = 100;
//   double _distanceFromClass = 0;
    List<Map<String, dynamic>> _classes = [];
    Map<String, dynamic>? _selectedClass;
    bool _isLoadingClasses = false;
    List<Map<String,dynamic>> _sessions = [];
    Map<String,dynamic>? _activeSession;
    Timer? _sessionTimer;
    Set<int> _alertedSessions = {};
    String _sessionMessage = 'Đang tải lịch điểm danh...';
    double _distanceFromClass = 0;

  // ==================== DATABASE ====================
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // Hàm khởi tạo Face Detector, model và camera.
  @override
  void initState() {
    super.initState();
    // FAST mode giảm thời gian phát hiện; embedding vẫn do MobileFaceNet xử lý.
    _faceDetector = FaceDetector(options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
    ));
    _initializeFaceRecognition();
    _refreshFaceStatus();
    _loadClasses().then((_) => _refreshSessions());
    _sessionTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshSessions());
  }

  // ==================== KHỞI TẠO MODEL ====================
  // Hàm tải model nhận diện khuôn mặt.
  Future<void> _initializeFaceRecognition() async {
    try {
      await _faceRecognitionService.initialize();
      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _faceRecognitionStatus = 'Model nhận diện khuôn mặt đã sẵn sàng';
      });
    } catch (e) {
      debugPrint('Lỗi khởi tạo face model: $e');
      if (!mounted) return;
      setState(() {
        _isModelReady = false;
        _faceRecognitionStatus = 'Lỗi model: $e';
      });
    }
  }

  // ==================== KHỞI TẠO CAMERA ====================
  // Hàm mở camera với độ phân giải cao và lựa chọn vị trí camera.
  Future<void> _initCamera([int? cameraIndex]) async {
    if (widget.cameras.isEmpty) {
      if (mounted) setState(() => _locationStatus = 'Không tìm thấy camera');
      return;
    }

    if (cameraIndex != null) {
      _selectedCameraIndex = cameraIndex % widget.cameras.length;
    } else {
      final frontCameraIndex = widget.cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontCameraIndex != -1 ? frontCameraIndex : 0;
    }

    final camera = widget.cameras[_selectedCameraIndex];

    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Lỗi camera: $e');
      if (mounted) setState(() => _locationStatus = 'Lỗi camera: $e');
    }
  }

  // ==================== CHUYỂN ĐỔI CAMERA ====================
  Future<void> _switchCamera() async {
    if (widget.cameras.length <= 1) {
      _showMessage('Thiết bị chỉ có 1 camera.', Colors.orange);
      return;
    }

    setState(() => _isCameraReady = false);

    await _stopFaceDetection();
    final nextIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    await _initCamera(nextIndex);
  }

  // ==================== PHÁT HIỆN KHUÔN MẶT LIVE ====================
  // Hàm bắt đầu camera stream để ML Kit phát hiện số khuôn mặt.
  Future<void> _startFaceDetection() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showMessage('Camera chưa sẵn sàng.', Colors.red);
      return;
    }
    if (_cameraController!.value.isStreamingImages) return;
    setState(() => _faceRecognitionStatus = 'Đang phát hiện khuôn mặt...');
    await _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;
      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) {
          _isDetecting = false;
          return;
        }
        final faces = await _faceDetector.processImage(inputImage);
        if (mounted) setState(() => _faceCount = faces.length);
      } catch (e) {
        debugPrint('Lỗi phát hiện khuôn mặt: $e');
      }
      _isDetecting = false;
    });
  }

  // ==================== CHUYỂN CAMERA IMAGE SANG ML KIT ====================
  // Hàm chuyển hình ảnh camera thành InputImage cho ML Kit.
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = widget.cameras[_selectedCameraIndex];

    final orientations = {
      services.DeviceOrientation.portraitUp: 0,
      services.DeviceOrientation.landscapeLeft: 90,
      services.DeviceOrientation.portraitDown: 180,
      services.DeviceOrientation.landscapeRight: 270,
    };

    int? rotationCompensation = orientations[_cameraController!.value.deviceOrientation];
    if (rotationCompensation == null) return null;

    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (camera.sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (camera.sensorOrientation - rotationCompensation + 360) % 360;
    }

    final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ==================== DỪNG NHẬN DIỆN ====================
  // Hàm dừng camera stream.
  Future<void> _stopFaceDetection() async {
    if (_cameraController == null) return;
    if (_cameraController!.value.isStreamingImages) await _cameraController!.stopImageStream();
    _isDetecting = false;
    if (mounted) setState(() => _faceCount = 0);
  }

  // ==================== PHÁT HIỆN VÀ CROP KHUÔN MẶT ====================
  // Hàm tìm đúng một khuôn mặt và cắt vùng khuôn mặt từ ảnh.
  Future<img.Image?> _detectAndCropFace(String imagePath, {bool quiet = false}) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (!quiet) _showMessage('Không phát hiện khuôn mặt.', Colors.orange);
        return null;
      }

      if (faces.length > 1) {
        if (!quiet) _showMessage('Phát hiện nhiều khuôn mặt. Chỉ để một người trước camera.', Colors.orange);
        return null;
      }

      final bytes = await File(imagePath).readAsBytes();
      var original = img.decodeImage(bytes);
      if (original == null) {
        if (!quiet) _showMessage('Không thể đọc ảnh camera.', Colors.red);
        return null;
      }

      original = img.bakeOrientation(original);

      final box = faces.first.boundingBox;
      final paddingX = box.width * 0.20, paddingY = box.height * 0.25;
      double left = (box.left - paddingX).clamp(0.0, original.width.toDouble());
      double top = (box.top - paddingY).clamp(0.0, original.height.toDouble());
      double right = (box.right + paddingX).clamp(0.0, original.width.toDouble());
      double bottom = (box.bottom + paddingY).clamp(0.0, original.height.toDouble());

      final cropWidth = (right - left).round(), cropHeight = (bottom - top).round();

      if (cropWidth <= 0 || cropHeight <= 0) {
        if (!quiet) _showMessage('Không thể crop khuôn mặt.', Colors.red);
        return null;
      }

      final cropped = img.copyCrop(original, x: left.round(), y: top.round(), width: cropWidth, height: cropHeight);
      debugPrint('Ảnh crop: ${cropped.width}x${cropped.height}');
      return cropped;
    } catch (e) {
      debugPrint('Lỗi detect/crop face: $e');
      if (!quiet) _showMessage('Lỗi xử lý khuôn mặt: $e', Colors.red);
      return null;
    }
  }

  Future<Map<String, dynamic>> _myFaceRequest(String path, {List<double>? embedding}) async {
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    final headers = {'Authorization': 'Bearer ${widget.session.token}', 'Content-Type': 'application/json'};
    final http.Response response = embedding == null
        ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 15))
        : await http.post(uri, headers: headers, body: jsonEncode({'embedding': embedding})).timeout(const Duration(seconds: 15));
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300 || result['success'] != true) {
      throw Exception(result['message']?.toString() ?? 'Máy chủ không xử lý được yêu cầu.');
    }
    return result;
  }

  Future<void> _refreshFaceStatus() async {
    try {
      final result = await _myFaceRequest('/api/student/my-face');
      if (mounted) setState(() => _faceState = result['status']?.toString() ?? 'missing');
    } catch (e) {
      if (mounted) setState(() => _faceState = 'error');
      debugPrint('Kiểm tra đăng ký khuôn mặt: $e');
    }
  }

  Future<void> _openCamera() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (mounted) setState(() => _cameraVisible = true);
      return;
    }
    if (mounted) setState(() => _cameraVisible = true);
    await _initCamera();
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Không mở được camera trên điện thoại.');
    }
  }

  Future<void> _closeCamera() async {
    await _stopFaceDetection();
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) setState(() { _isCameraReady = false; _cameraVisible = false; });
    if (controller != null) await controller.dispose();
  }

  // Chỉ chụp ảnh khi luồng camera đã xác nhận có đúng một khuôn mặt.
  // Tránh tạo và xóa hàng chục ảnh không có mặt trong mỗi lần quét.
  Future<img.Image?> _captureDetectedFace({required DateTime deadline}) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return null;
    if (DateTime.now().isAfter(deadline)) return null;
    if (controller.value.isStreamingImages) await controller.stopImageStream();

    final found = Completer<bool>();
    bool processing = false;
    bool inputSupported = false;
    try {
      await controller.startImageStream((CameraImage frame) async {
        if (processing || found.isCompleted) return;
        processing = true;
        try {
          final input = _inputImageFromCameraImage(frame);
          if (input == null) return;
          inputSupported = true;
          final faces = await _faceDetector.processImage(input);
          if (mounted && _faceCount != faces.length) {
            setState(() => _faceCount = faces.length);
          }
          if (faces.length == 1 && faces.first.boundingBox.width >= 55 &&
              faces.first.boundingBox.height >= 55 && !found.isCompleted) {
            found.complete(true);
          }
        } catch (e) {
          debugPrint('Bỏ qua khung hình live: $e');
        } finally {
          processing = false;
        }
      });
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      // Kiểm tra live tối đa 2 giây/lượt; fallback khi điện thoại không
      // hỗ trợ định dạng stream cho ML Kit.
      final detected = await found.future.timeout(
        remaining < const Duration(seconds: 2) ? remaining : const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if ((!detected && inputSupported) || !mounted || !_cameraVisible) return null;
    } catch (e) {
      debugPrint('Không đọc được camera stream: $e');
      return null;
    } finally {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    }

    String? imagePath;
    try {
      final picture = await controller.takePicture();
      imagePath = picture.path;
      return await _detectAndCropFace(imagePath, quiet: true);
    } catch (e) {
      debugPrint('Không lấy được ảnh khuôn mặt: $e');
      return null;
    } finally {
      if (imagePath != null) {
        try { await File(imagePath).delete(); } catch (_) {}
      }
    }
  }

  // Đăng ký khuôn mặt tự động, không cần bấm chụp.
  Future<List<double>> _captureEmbedding() async {
    if (!_isModelReady) throw Exception('Mô hình AI chưa sẵn sàng.');
    await _openCamera();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (mounted && _cameraVisible && DateTime.now().isBefore(deadline)) {
      final face = await _captureDetectedFace(deadline: deadline);
      if (face != null) {
        final embedding = _faceRecognitionService.getEmbedding(face);
        if (embedding.length == 192 && embedding.every((v) => v.isFinite)) {
          return embedding;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw Exception('Chưa tìm được khuôn mặt rõ ràng trong 30 giây. Hãy thử lại.');
  }

  // Chỉ so khớp embedding của tài khoản đã đăng nhập.
  Future<double> _scanMyFaceAutomatically(List<double> registered) async {
    if (!_isModelReady) throw Exception('Mô hình nhận diện AI chưa sẵn sàng.');
    await _openCamera();
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    double bestSimilarity = -1;
    final normalizedRegistered = _faceRecognitionService.normalizeEmbedding(registered);
    while (mounted && _cameraVisible && DateTime.now().isBefore(deadline)) {
      final face = await _captureDetectedFace(deadline: deadline);
      if (face != null) {
        final embedding = _faceRecognitionService.getEmbedding(face);
        if (embedding.length == 192) {
          final similarity = _faceRecognitionService.cosineSimilarity(
            _faceRecognitionService.normalizeEmbedding(embedding),
            normalizedRegistered,
          );
          if (similarity.isFinite) {
            if (similarity > bestSimilarity) bestSimilarity = similarity;
            if (mounted) setState(() {
              _faceSimilarity = similarity;
              _faceRecognitionStatus = similarity >= 0.70
                  ? 'Đã xác thực đúng ${widget.session.username}'
                  : 'Đang xác minh • ${(similarity * 100).toStringAsFixed(0)}%';
            });
            if (similarity >= 0.70) return similarity;
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted || !_cameraVisible) throw Exception('Đã dừng camera.');
    if (bestSimilarity < 0) {
      throw Exception('Không phát hiện được một khuôn mặt rõ ràng. Hãy thử nơi đủ sáng.');
    }
    throw Exception('Khuôn mặt không khớp tài khoản ${widget.session.username}.');
  }

  // Đăng ký duy nhất cho tài khoản đang đăng nhập; Worker kiểm tra trùng.
  Future<void> _registerMyFace() async {
    if (_busy || (_faceState != 'missing' && _faceState != 'pending')) return;
    setState(() => _busy = true);
    try {
      final embedding = await _captureEmbedding();
      await _myFaceRequest('/api/student/face-registration', embedding: embedding);
      await _refreshFaceStatus();
      _showMessage('Đăng ký khuôn mặt thành công. Không cần Admin duyệt.', Colors.green);
    } catch (e) {
      _showMessage('Không thể đăng ký khuôn mặt: $e', Colors.red);
    } finally {
      await _closeCamera();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadClasses() async {
    if (!mounted) return;

    setState(() => _isLoadingClasses = true);

    try {
      final response = await http.get(Uri.parse('https://attendance-cloudflare.quangcuongdk1.workers.dev/api/classes'));

      if (response.statusCode != 200) {
        throw Exception('Không lấy được danh sách lớp.');
      }

      final result = jsonDecode(response.body);

      if (result['success'] != true || result['data'] is! List) {
        throw Exception('Dữ liệu lớp học không hợp lệ.');
      }

      final classes = List<Map<String, dynamic>>.from(
        (result['data'] as List).map((e) => Map<String, dynamic>.from(e)),
      );

      if (!mounted) return;

      setState(() {
        _classes = classes;
        _selectedClass = classes.isNotEmpty ? classes.first : null;
        _isLoadingClasses = false;
        _currentPosition = null;
        _distanceFromClass = 0;
        _isInAllowedLocation = false;
        _locationStatus = classes.isEmpty ? 'Chưa có lớp học.' : 'Đã chọn lớp ${classes.first['class_name']}';
      });
    } catch (e) {
      debugPrint('Lỗi tải lớp: $e');

      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
          _locationStatus = 'Không tải được danh sách lớp.';
        });

        _showMessage('Lỗi tải danh sách lớp: $e', Colors.red);
      }
    }
  }
  Future<void> _refreshSessions() async {
    if (!mounted) return;
    try {
      final resp = await http.get(Uri.parse('${ApiService.baseUrl}/api/sessions'),
        headers: {'Authorization':'Bearer ${widget.session.token}'}).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode != 200 || decoded['success'] != true) return;
      final rows = List<Map<String,dynamic>>.from((decoded['data'] as List).map((e)=>Map<String,dynamic>.from(e)));
      final active = rows.where((e)=>e['phase']=='open').toList();
      Map<String,dynamic>? selected;
      if (active.isNotEmpty) selected=active.first;
      if (!mounted) return;
      if (selected != null) {
        final id = int.tryParse('${selected['id']}') ?? 0;
        if (!_alertedSessions.contains(id)) {
          _alertedSessions.add(id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('ĐẾN GIỜ ĐIỂM DANH: ${selected['subject_name']} – ${selected['class_code']}'),
            duration: const Duration(seconds: 8)));
        }
      }
      final classId=selected?['class_id']?.toString();
      final matching=classId==null?null:_classes.where((c)=>c['id'].toString()==classId).toList();
      setState(() {
        if (_activeSession?['id']?.toString() != selected?['id']?.toString()) {
          _currentPosition = null;
          _isInAllowedLocation = false;
          _distanceFromClass = 0;
        }
        _sessions=rows;_activeSession=selected;
        _sessionMessage=selected==null?'Chưa có phiên đang mở. Xem lịch bên dưới.':'Đang mở: ${selected['subject_name']}';
        if(matching!=null&&matching.isNotEmpty)_selectedClass=matching.first;
      });
    } catch (e) { debugPrint('Không cập nhật được phiên: $e'); }
  }

  Widget _sessionPanel() {
    final active=_activeSession;
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('THỜI KHÓA BIỂU & PHIÊN ĐIỂM DANH',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:8),Text(_sessionMessage),
        if(active!=null) Text('Môn: ${active['subject_name']} | Phòng: ${active['room']}\n'
          'Kết thúc điểm danh: ${active['ends_at']} (UTC)'),
        if(_sessions.isEmpty) const Text('Chưa có phiên điểm danh. Admin cần tạo phiên.'),
        ..._sessions.take(6).map((s)=>ListTile(dense:true,
          title:Text('${s['subject_name']} – ${s['class_code']}'),
          subtitle:Text('${s['starts_at']} (UTC)'),
          trailing:Text(s['phase']=='open'?'ĐANG MỞ':s['phase']=='closed'?'KẾT THÚC':'SẮP MỞ'))),
        TextButton.icon(onPressed:_refreshSessions,icon:const Icon(Icons.refresh),label:const Text('Làm mới phiên')),
        const Text('Thông báo khi app đang mở; cần FCM để báo khi app đóng.',style:TextStyle(fontSize:12)),
      ])));
  }

  // ==================== GPS THEO DÕI LIÊN TỤC ====================
  // GPS điện thoại KHÔNG đo chính xác đến 10 cm; accuracy là sai số ước tính.
  // Trường hợp gần ranh giới bán kính sẽ được coi là chưa đủ tin cậy.
  bool get _hasFreshReliableLocation {
    final pos = _currentPosition;
    final updated = _lastLocationAt;
    return pos != null && updated != null &&
        DateTime.now().difference(updated) < const Duration(seconds: 12) &&
        pos.accuracy.isFinite && pos.accuracy > 0 &&
        pos.accuracy <= _maximumGpsAccuracy;
  }

  void _onPositionChanged(Position position) {
    if (!mounted || _selectedClass == null) return;
    final classLat = double.tryParse('${_selectedClass!['latitude']}');
    final classLon = double.tryParse('${_selectedClass!['longitude']}');
    final radius = double.tryParse('${_selectedClass!['radius']}');
    if (classLat == null || classLon == null || radius == null) return;
    if (!position.latitude.isFinite || !position.longitude.isFinite ||
        position.latitude.abs() > 90 || position.longitude.abs() > 180) return;
    // Không nhận kết quả GPS đã quá cũ.
    if (DateTime.now().difference(position.timestamp).inSeconds > 10) return;
    final distance = Geolocator.distanceBetween(
      position.latitude, position.longitude, classLat, classLon,
    );
    final acc = position.accuracy;
    final reliable = acc.isFinite && acc > 0 && acc <= _maximumGpsAccuracy;
    // Chỉ xác nhận trong vùng nếu cả vùng sai số vẫn nằm trong bán kính.
    final safelyInside = reliable && distance + acc <= radius;
    final safelyOutside = reliable && distance - acc > radius;
    setState(() {
      _currentPosition = position;
      _lastLocationAt = DateTime.now();
      _distanceFromClass = distance;
      _isInAllowedLocation = safelyInside;
      _isGettingLocation = false;
      _locationStatus = !reliable
          ? 'Sai số GPS ±${acc.toStringAsFixed(1)} m quá lớn; cần đo lại (tối đa ±25 m).'
          : safelyInside
              ? 'Đã xác minh trong bán kính lớp học.'
              : safelyOutside
                  ? 'Đang ở ngoài bán kính lớp học.'
                  : 'Đang sát ranh giới hoặc tín hiệu chưa rõ; hãy đo lại.';
    });
    final waiter = _locationWaiter;
    if (waiter != null && !waiter.isCompleted && reliable) {
      waiter.complete(safelyInside);
    }
    debugPrint('GPS lat=${position.latitude}, lon=${position.longitude}, '
      'accuracy=±${acc.toStringAsFixed(1)}m, distance=${distance.toStringAsFixed(1)}m');
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    if (_selectedClass == null) {
      _showMessage('Vui lòng chọn lớp điểm danh.', Colors.orange);
      return;
    }
    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Đang cập nhật GPS liên tục...';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('GPS đang tắt. Hãy bật dịch vụ vị trí.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Chưa được cấp quyền vị trí chính xác.');
      }
      // Chỉ giữ một stream; cài waiter trước để không bỏ lỡ mẫu GPS đầu.
      final oldWaiter = _locationWaiter;
      if (oldWaiter != null && !oldWaiter.isCompleted) oldWaiter.complete(false);
      final waiter = Completer<bool>();
      _locationWaiter = waiter;
      if (_locationSubscription == null) {
        final LocationSettings settings = Platform.isAndroid
            ? AndroidSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 0,
                intervalDuration: const Duration(seconds: 1),
                // Dùng Fused Location Provider mặc định của Android.
                forceLocationManager: false,
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 0,
              );
        _locationSubscription = Geolocator.getPositionStream(
          locationSettings: settings,
        ).listen(_onPositionChanged, onError: (Object error) {
          if (mounted) setState(() {
            _locationStatus = 'Không đọc được GPS: $error';
            _isGettingLocation = false;
            _isInAllowedLocation = false;
          });
          if (_locationWaiter != null && !_locationWaiter!.isCompleted) {
            _locationWaiter!.complete(false);
          }
        });
      }
      if (!_hasFreshReliableLocation) {
        await waiter.future.timeout(
          const Duration(seconds: 15), onTimeout: () => false,
        );
      } else if (!waiter.isCompleted) {
        waiter.complete(_isInAllowedLocation);
      }
      if (mounted) setState(() {
        _isGettingLocation = false;
        if (!_hasFreshReliableLocation) {
          _isInAllowedLocation = false;
          _locationStatus = 'Chưa có GPS đủ tin cậy. Hãy ra nơi thoáng rồi thử lại.';
        }
      });
    } catch (e) {
      if (mounted) setState(() {
        _isGettingLocation = false;
        _isInAllowedLocation = false;
        _locationStatus = 'Lỗi vị trí: $e';
      });
    }
  }

  // Chỉ so khớp khuôn mặt đã đăng ký của chính tài khoản này.
  Future<void> _attendance() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _refreshSessions();
      if (_activeSession == null) {
        _showMessage('Chưa có phiên điểm danh đang mở.', Colors.orange);
        return;
      }
      if (_faceState != 'approved') {
        _showMessage('Tài khoản chưa đăng ký khuôn mặt hợp lệ.', Colors.orange);
        return;
      }
      if (_selectedClass == null || _selectedClass!['id'].toString() != _activeSession!['class_id'].toString()) {
        _showMessage('Không tìm thấy lớp điểm danh phù hợp.', Colors.red);
        return;
      }
      // API chỉ trả dữ liệu khuôn mặt được duyệt của chủ tài khoản, không tìm người khớp nhất.
      final result = await _myFaceRequest('/api/student/my-face');
      if (result['status'] != 'approved' || result['embedding'] is! String) {
        throw Exception('Chưa có dữ liệu khuôn mặt đã đăng ký.');
      }
      final storedEmbedding = result['embedding'] as String;
      final dynamic decodedEmbedding = storedEmbedding.trim().startsWith('[')
          ? jsonDecode(storedEmbedding) : null;
      final registered = decodedEmbedding is List
          ? decodedEmbedding.map((v) => double.tryParse(v.toString()) ?? double.nan).toList()
          : storedEmbedding.split(',').map((v) => double.tryParse(v.trim()) ?? double.nan).toList();
      if (registered.length != 192 || registered.any((v) => !v.isFinite)) {
        throw Exception('Dữ liệu khuôn mặt được lưu không hợp lệ.');
      }
      // GPS và Face ID chạy song song để giảm tổng thời gian điểm danh.
      final gpsTask = _getCurrentLocation();
      if (mounted) setState(() => _faceRecognitionStatus = 'Đưa khuôn mặt vào camera để AI tự động nhận diện...');
      // Tự quét và so khớp liên tục trong tối đa 35 giây.
      // Không cho điểm danh bằng danh tính của người khác.
      final similarity = await _scanMyFaceAutomatically(registered);
      if (!mounted) return;
      setState(() { _faceSimilarity = similarity; _isFaceMatched = true; });
      await gpsTask;
      if (_currentPosition?.isMocked == true) throw Exception('Không chấp nhận vị trí mô phỏng.');
      if (!_hasFreshReliableLocation || !_isInAllowedLocation) {
        throw Exception('Bạn đang ở ngoài khu vực điểm danh hoặc chưa có GPS.');
      }
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/student/session-attendance'),
        headers: {'Authorization': 'Bearer ${widget.session.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _activeSession!['id'],
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'face_similarity': similarity,
          'gps_accuracy': _currentPosition!.accuracy,
        }),
      ).timeout(const Duration(seconds: 15));
      final saved = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 300 || saved['success'] != true) {
        throw Exception(saved['message']?.toString() ?? 'Điểm danh thất bại.');
      }
      _showMessage(saved['message']?.toString() ?? 'Điểm danh thành công.', Colors.green);
      await _refreshSessions();
    } catch (e) {
      _showMessage('Điểm danh thất bại: $e', Colors.red);
    } finally {
      await _closeCamera();
      if (mounted) setState(() => _busy = false);
    }
  }

  // ==================== HIỂN THỊ THÔNG BÁO ====================
  // Hàm hiển thị SnackBar thông báo cho người dùng.
  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)));
  }

  // Camera được đặt phía trên như giao diện ban đầu nhưng chỉ bật khi cần.
  @override
  Widget build(BuildContext context) {
    final active = _activeSession;
    final gpsValid = _currentPosition != null && _isInAllowedLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ĐIỂM DANH THÔNG MINH',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blueAccent, letterSpacing: 0.8)),
            Text('Xin chào, ${widget.session.username}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.1), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7)),
              tooltip: 'Lịch học',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => StudentSchedulePage(session: widget.session))),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.blueAccent),
              tooltip: 'Lịch sử',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AttendanceHistoryPage(session: widget.session))),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Đăng xuất',
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => StudentLoginPage(cameras: widget.cameras)), (_) => false),
            ),
          ),
        ],
      ),
      body: AnimatedTechBackground(
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ==================== KHUNG CAMERA / HUD AI ====================
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _cameraVisible ? Colors.greenAccent : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (_cameraVisible)
                                BoxShadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 6, spreadRadius: 2)
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _cameraVisible
                            ? (_busy && (_faceState == 'missing' || _faceState == 'pending') ? 'ĐĂNG KÝ KHUÔN MẶT' : 'AI ĐANG QUÉT MẶT')
                            : 'CAMERA FACE ID AI',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    if (_cameraVisible)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_cameraVisible && _isCameraReady && _cameraController != null)
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: 100,
                              height: 100 * (_cameraController!.value.aspectRatio < 1
                                  ? 1 / _cameraController!.value.aspectRatio
                                  : _cameraController!.value.aspectRatio),
                              child: CameraPreview(_cameraController!),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Center(
                              child: _cameraVisible
                                ? const CircularProgressIndicator(color: Colors.cyanAccent)
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
                                        ),
                                        child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.cyanAccent, size: 54),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text('Camera FaceID đang chờ', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Đến giờ học, nhấn nút bên dưới để tự nhận diện',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                      ),
                                    ],
                                  ),
                            ),
                          ),

                        if (_cameraVisible)
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                width: 190,
                                height: 230,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(115),
                                  border: Border.all(color: Colors.cyanAccent, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (_cameraVisible)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                _busy && (_faceState == 'missing' || _faceState == 'pending')
                                  ? 'Đưa khuôn mặt vào khung – hệ thống đang tự lưu'
                                  : _faceRecognitionStatus,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
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

          // ==================== BẢNG THÔNG TIN PHIÊN HỌC ====================
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active != null ? Colors.green.withOpacity(0.5) : Colors.grey.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(color: (active != null ? Colors.green : Colors.grey).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          active != null ? Icons.play_circle_fill_rounded : Icons.schedule_rounded,
                          color: active != null ? Colors.green : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          active == null ? 'CHƯA MỞ PHIÊN ĐIỂM DANH' : 'ĐANG TRONG GIỜ ĐIỂM DANH',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: active == null ? Colors.grey.shade600 : Colors.green.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (active != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('HOẠT ĐỘNG', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
                if (active != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.book_rounded, size: 18, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${active['subject_name']} (${active['class_code']})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room_rounded, size: 18, color: Colors.indigoAccent),
                      const SizedBox(width: 8),
                      Text('Phòng học: ${active['room'] ?? 'Chưa đặt'}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Hạn điểm danh: ${DateTime.tryParse('${active['ends_at']}')?.toLocal().toString().substring(0, 16) ?? active['ends_at']}',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ==================== THẺ XEM LỊCH HỌC ====================
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.cyan.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentSchedulePage(session: widget.session)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THỜI KHÓA BIỂU / LỊCH HỌC',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), letterSpacing: 0.5),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Xem lịch học Ngày, Tuần, Tháng',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ==================== KHU VỰC THẺ VỊ TRÍ & MẶT ====================
          Row(
            children: [
              // Thẻ Khuôn Mặt
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _faceState == 'approved' ? Icons.check_circle_rounded : Icons.face_rounded,
                            color: _faceState == 'approved' ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text('KHUÔN MẶT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _faceState == 'approved' ? '✓ Đã sẵn sàng' :
                        _faceState == 'pending' ? 'Chờ kích hoạt' :
                        _faceState == 'missing' ? 'Chưa đăng ký' : 'Lỗi dữ liệu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _faceState == 'approved' ? Colors.green.shade700 : Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                      if (_faceState == 'missing' || _faceState == 'pending') ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _busy ? null : _registerMyFace,
                            child: const Text('Đăng ký mặt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Thẻ Vị Trí GPS
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: gpsValid ? Colors.green.withOpacity(0.4) : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            gpsValid ? Icons.gps_fixed_rounded : Icons.location_off_rounded,
                            color: gpsValid ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text('VỊ TRÍ GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        gpsValid ? '✓ Trong khu vực' : 'Chưa xác định',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: gpsValid ? Colors.green.shade700 : Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: Colors.blueAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isGettingLocation || _busy ? null : _getCurrentLocation,
                          child: Text(
                            _isGettingLocation ? 'Đang lấy...' : 'Cập nhật vị trí',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_currentPosition != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Vĩ độ: ${_currentPosition!.latitude.toStringAsFixed(7)} | Kinh độ: ${_currentPosition!.longitude.toStringAsFixed(7)}\n'
                'Khoảng cách đến lớp: ${_distanceFromClass.toStringAsFixed(1)} m | Sai số GPS: ±${_currentPosition!.accuracy.toStringAsFixed(1)} m\n'
                '${_locationStatus}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ),

          const SizedBox(height: 20),

          // ==================== NÚT HERO ĐIỂM DANH CHÍNH ====================
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: (_busy || active == null || _faceState != 'approved')
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : [const Color(0xFF06B6D4), const Color(0xFF2563EB)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: (_busy || active == null || _faceState != 'approved')
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _busy || active == null || _faceState != 'approved' ? null : _attendance,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _busy ? 'ĐANG TỰ ĐỘNG XÁC THỰC...' : 'ĐIỂM DANH – MỞ CAMERA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_faceSimilarity > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Độ tương đồng tài khoản: ${(_faceSimilarity * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ==================== TỰ ĐỘNG LÀM MỚI & THÔNG TIN PHỤ ====================
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: () async {
                    await _refreshSessions();
                    await _refreshFaceStatus();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0F172A)),
                  label: const Text('Làm mới dữ liệu', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
    );
  }

  // ==================== GIẢI PHÓNG TÀI NGUYÊN ====================
  // Hàm giải phóng camera, ML Kit và model khi đóng trang.
  @override
  void dispose() {
    _cameraController?.dispose();
    _sessionTimer?.cancel();
    _locationSubscription?.cancel();
    final waiter = _locationWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(false);
    _faceDetector.close();
    _faceRecognitionService.dispose();
    super.dispose();
  }
}
