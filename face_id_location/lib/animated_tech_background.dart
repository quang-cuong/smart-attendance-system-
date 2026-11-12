import 'dart:math';
import 'package:flutter/material.dart';

/// Widget Hình nền Động Công nghệ (Dynamic Tech Background)
/// Tự động tạo dải màu chuyển động kết hợp hạt năng lượng/đốm sáng mờ ảo
class AnimatedTechBackground extends StatefulWidget {
  final Widget child;
  const AnimatedTechBackground({super.key, required this.child});

  @override
  State<AnimatedTechBackground> createState() => _AnimatedTechBackgroundState();
}

class _AnimatedTechBackgroundState extends State<AnimatedTechBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(const Color(0xFF0F172A), const Color(0xFF030712), progress)!,
                Color.lerp(const Color(0xFF1E293B), const Color(0xFF083344), progress)!,
                Color.lerp(const Color(0xFF0284C7), const Color(0xFF0F172A), progress)!,
              ],
              begin: Alignment(-1.0 + progress * 0.5, -1.0),
              end: Alignment(1.0 - progress * 0.5, 1.0),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Lớp CustomPainter vẽ đốm sáng AI chuyển động mờ
              CustomPaint(
                painter: _TechOrbsPainter(progress: progress),
              ),
              // Nguồn nội dung chính
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _TechOrbsPainter extends CustomPainter {
  final double progress;
  _TechOrbsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Đốm sáng 1: Xanh Cyan ở góc trên bên trái
    final orb1Center = Offset(
      size.width * (0.2 + 0.15 * sin(progress * pi * 2)),
      size.height * (0.25 + 0.1 * cos(progress * pi * 2)),
    );
    final orb1Gradient = RadialGradient(
      colors: [
        const Color(0xFF06B6D4).withOpacity(0.35),
        const Color(0xFF06B6D4).withOpacity(0.0),
      ],
    );
    paint.shader = orb1Gradient.createShader(
      Rect.fromCircle(center: orb1Center, radius: size.width * 0.45),
    );
    canvas.drawCircle(orb1Center, size.width * 0.45, paint);

    // Đốm sáng 2: Xanh Indigo/Tím ở góc dưới bên phải
    final orb2Center = Offset(
      size.width * (0.8 - 0.15 * cos(progress * pi * 2)),
      size.height * (0.75 - 0.1 * sin(progress * pi * 2)),
    );
    final orb2Gradient = RadialGradient(
      colors: [
        const Color(0xFF6366F1).withOpacity(0.30),
        const Color(0xFF6366F1).withOpacity(0.0),
      ],
    );
    paint.shader = orb2Gradient.createShader(
      Rect.fromCircle(center: orb2Center, radius: size.width * 0.55),
    );
    canvas.drawCircle(orb2Center, size.width * 0.55, paint);

    // Đốm sáng 3: Xanh Emerald ngọc ở giữa
    final orb3Center = Offset(
      size.width * (0.5 + 0.2 * sin((progress + 0.5) * pi * 2)),
      size.height * (0.5 + 0.15 * cos((progress + 0.5) * pi * 2)),
    );
    final orb3Gradient = RadialGradient(
      colors: [
        const Color(0xFF10B981).withOpacity(0.25),
        const Color(0xFF10B981).withOpacity(0.0),
      ],
    );
    paint.shader = orb3Gradient.createShader(
      Rect.fromCircle(center: orb3Center, radius: size.width * 0.35),
    );
    canvas.drawCircle(orb3Center, size.width * 0.35, paint);
  }

  @override
  bool shouldRepaint(covariant _TechOrbsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
