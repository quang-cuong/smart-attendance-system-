import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;

  static const String _modelPath =
      'assets/model/mobilefacenet.tflite';
  static const String _embeddingKey =
      'registered_face_embedding';

  static const int _inputSize = 112;
  static const int _embeddingSize = 192;

  bool get isReady => _interpreter != null;

  // ============================================================
  // KHỞI TẠO MODEL
  // ============================================================

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
      );

      final inputTensor =
          _interpreter!.getInputTensor(0);

      final outputTensor =
          _interpreter!.getOutputTensor(0);

      debugPrint(
        'Face model loaded successfully',
      );

      debugPrint(
        'Input shape: ${inputTensor.shape}',
      );

      debugPrint(
        'Input type: ${inputTensor.type}',
      );

      debugPrint(
        'Output shape: ${outputTensor.shape}',
      );

      debugPrint(
        'Output type: ${outputTensor.type}',
      );

      // Kiểm tra model có đúng model của project không
      if (inputTensor.shape.length != 4 ||
          inputTensor.shape[1] != _inputSize ||
          inputTensor.shape[2] != _inputSize ||
          inputTensor.shape[3] != 3) {
        throw Exception(
          'Model input không đúng: '
          'cần [1,112,112,3]',
        );
      }

      if (outputTensor.shape.length != 2 ||
          outputTensor.shape[1] != _embeddingSize) {
        throw Exception(
          'Model output không đúng: '
          'cần [1,192]',
        );
      }
    } catch (e) {
      debugPrint(
        'Lỗi khởi tạo FaceRecognitionService: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // CHUYỂN ẢNH THÀNH INPUT MODEL (TỐI ƯU FLOAT32LIST BỘ NHỚ)
  // ============================================================

  Float32List _preprocessFace(img.Image face) {
    final resized = img.copyResize(
      face,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final floatBuffer = Float32List(1 * _inputSize * _inputSize * 3);
    int bufferIndex = 0;

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        floatBuffer[bufferIndex++] = (pixel.r.toDouble() - 127.5) / 128.0;
        floatBuffer[bufferIndex++] = (pixel.g.toDouble() - 127.5) / 128.0;
        floatBuffer[bufferIndex++] = (pixel.b.toDouble() - 127.5) / 128.0;
      }
    }

    return floatBuffer;
  }

  // ============================================================
  // TẠO EMBEDDING (TỰ ĐỘNG RESHAPE SIÊU NHANH)
  // ============================================================

  List<double> getEmbedding(img.Image face) {
    if (_interpreter == null) {
      throw Exception('Model chưa được load');
    }

    final inputBuffer = _preprocessFace(face).reshape([1, _inputSize, _inputSize, 3]);
    final outputBuffer = Float32List(1 * _embeddingSize).reshape([1, _embeddingSize]);

    _interpreter!.run(inputBuffer, outputBuffer);

    final List<double> embedding = List<double>.from(outputBuffer[0]);

    debugPrint('Embedding size: ${embedding.length}');
    return embedding;
  }

  // ============================================================
  // CHUẨN HÓA VECTOR
  // ============================================================

  List<double> normalizeEmbedding(
    List<double> embedding,
  ) {
    double norm = 0;

    for (final value in embedding) {
      norm += value * value;
    }

    norm = sqrt(norm);

    if (norm == 0) {
      return List<double>.filled(
        embedding.length,
        0,
      );
    }

    return embedding
        .map(
          (value) => value / norm,
        )
        .toList();
  }

  // ============================================================
  // COSINE SIMILARITY
  // ============================================================

  double cosineSimilarity(
    List<double> a,
    List<double> b,
  ) {
    if (a.length != b.length) {
      throw Exception(
        'Hai vector không cùng kích thước',
      );
    }

    double dot = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];

      normA +=
          a[i] * a[i];

      normB +=
          b[i] * b[i];
    }

    if (normA == 0 ||
        normB == 0) {
      return 0;
    }

    return dot /
        (sqrt(normA) *
            sqrt(normB));
  }

  // ============================================================
  // LƯU EMBEDDING KHUÔN MẶT
  // ============================================================

  Future<void> saveEmbedding(
    List<double> embedding,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final normalized =
        normalizeEmbedding(
      embedding,
    );

    final stringList =
        normalized
            .map(
              (value) =>
                  value.toString(),
            )
            .toList();

    await prefs.setStringList(
      _embeddingKey,
      stringList,
    );

    debugPrint(
      'Đã lưu embedding khuôn mặt',
    );

    debugPrint(
      'Số phần tử: ${normalized.length}',
    );
  }

  // ============================================================
  // LẤY EMBEDDING ĐÃ ĐĂNG KÝ
  // ============================================================

  Future<List<double>?> loadRegisteredEmbedding() async {
    final prefs =
        await SharedPreferences.getInstance();

    final data =
        prefs.getStringList(
      _embeddingKey,
    );

    if (data == null ||
        data.isEmpty) {
      return null;
    }

    final embedding =
        data
            .map(
              (value) =>
                  double.tryParse(value) ??
                  0.0,
            )
            .toList();

    if (embedding.length !=
        _embeddingSize) {
      debugPrint(
        'Embedding đã lưu không hợp lệ',
      );

      return null;
    }

    return embedding;
  }

  // ============================================================
  // XÓA KHUÔN MẶT ĐÃ ĐĂNG KÝ
  // ============================================================

  Future<void> deleteRegisteredEmbedding() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _embeddingKey,
    );

    debugPrint(
      'Đã xóa khuôn mặt đăng ký',
    );
  }

  // ============================================================
  // KIỂM TRA ĐÃ ĐĂNG KÝ KHUÔN MẶT CHƯA
  // ============================================================

  Future<bool> hasRegisteredFace() async {
    final embedding =
        await loadRegisteredEmbedding();

    return embedding != null &&
        embedding.length ==
            _embeddingSize;
  }

  // ============================================================
  // SO SÁNH KHUÔN MẶT HIỆN TẠI
  // ============================================================

  Future<double> compareFace(
    img.Image face,
  ) async {
    final registered =
        await loadRegisteredEmbedding();

    if (registered == null) {
      throw Exception(
        'Chưa đăng ký khuôn mặt',
      );
    }

    final current =
        getEmbedding(face);

    final normalizedCurrent =
        normalizeEmbedding(
      current,
    );

    final similarity =
        cosineSimilarity(
      normalizedCurrent,
      registered,
    );

    debugPrint(
      'Cosine similarity: $similarity',
    );

    return similarity;
  }

  // ============================================================
  // KIỂM TRA CÓ PHẢI ĐÚNG NGƯỜI KHÔNG
  // ============================================================

  Future<bool> isSamePerson(
    img.Image face, {
    double threshold = 0.75,
  }) async {
    final similarity =
        await compareFace(face);

    final result =
        similarity >= threshold;

    debugPrint(
      'Similarity: $similarity',
    );

    debugPrint(
      'Threshold: $threshold',
    );

    debugPrint(
      'Đúng người: $result',
    );

    return result;
  }

  // ============================================================
  // GIẢI PHÓNG MODEL
  // ============================================================

  void dispose() {
    _interpreter?.close();
    _interpreter = null;

    debugPrint(
      'FaceRecognitionService disposed',
    );
  }
}