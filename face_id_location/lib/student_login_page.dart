import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'student_auth.dart';
import 'role_dashboard_page.dart';
import 'animated_tech_background.dart';

class StudentLoginPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const StudentLoginPage({super.key, required this.cameras});
  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên đăng nhập/email và mật khẩu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await StudentAuth.login(_username.text, _password.text);
      if (!mounted) return;
      if (session.mustChangePassword) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => StudentChangePasswordPage(
                cameras: widget.cameras, session: session)));
      } else if (session.role == 'student') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => AttendancePage(
                cameras: widget.cameras, session: session)));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => RoleDashboardPage(
                cameras: widget.cameras, session: session)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedTechBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO FACE ID CÔNG NGHỆ PHỐI VÒNG GLOW
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A).withOpacity(0.6),
                          border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.35),
                              blurRadius: 25,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 54,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'ĐIỂM DANH THÔNG MINH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hệ thống điểm danh AI FaceID & GPS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // CARD CÔNG NGHỆ KÍNH GLASSMORPHISM
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'ĐĂNG NHẬP HỆ THỐNG',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Ô nhập Username/Email
                            TextField(
                              controller: _username,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Tên đăng nhập / Email',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.person_rounded, color: Colors.cyanAccent),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Ô nhập Password
                            TextField(
                              controller: _password,
                              obscureText: _hidden,
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: (_) => _busy ? null : _login(),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.lock_rounded, color: Colors.cyanAccent),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    color: Colors.white60,
                                  ),
                                  onPressed: () => setState(() => _hidden = !_hidden),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                                ),
                              ),
                            ),

                            if (_error != null)
                              Container(
                                margin: const EdgeInsets.only(top: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 22),

                            // NÚT ĐĂNG NHẬP HERO GRADIENT
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: _busy
                                      ? [Colors.grey.shade600, Colors.grey.shade700]
                                      : [const Color(0xFF06B6D4), const Color(0xFF2563EB)],
                                ),
                                boxShadow: _busy
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF06B6D4).withOpacity(0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _busy ? null : _login,
                                child: _busy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'ĐĂNG NHẬP',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Quên mật khẩu? Liên hệ quản trị viên để được hỗ trợ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StudentChangePasswordPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final StudentSession session;
  const StudentChangePasswordPage(
      {super.key, required this.cameras, required this.session});
  @override
  State<StudentChangePasswordPage> createState() =>
      _StudentChangePasswordPageState();
}

class _StudentChangePasswordPageState
    extends State<StudentChangePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_new.text)) {
      setState(() => _error = 'Mật khẩu mới phải gồm đúng 6 chữ số (0–9).');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Xác nhận mật khẩu không khớp.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StudentAuth.changePassword(widget.session, _old.text, _new.text);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Đổi mật khẩu thành công'),
                content: const Text('Vui lòng đăng nhập lại bằng mật khẩu mới.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Đồng ý'))
                ],
              ));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => StudentLoginPage(cameras: widget.cameras)),
          (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedTechBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A).withOpacity(0.6),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.8), width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 48, color: Colors.cyanAccent),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ĐỔI MẬT KHẨU LẦN ĐẦU',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bạn cần thay đổi mật khẩu tạm thời trước khi tiếp tục.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _old,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu tạm thời',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.key_rounded, color: Colors.cyanAccent),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.cyanAccent, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _new,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu mới (đúng 6 chữ số)',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.cyanAccent),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.cyanAccent, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirm,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Xác nhận mật khẩu mới',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Colors.cyanAccent),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.cyanAccent, width: 2)),
                              ),
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            const SizedBox(height: 18),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: _busy
                                      ? [Colors.grey.shade600, Colors.grey.shade700]
                                      : [const Color(0xFF06B6D4), const Color(0xFF2563EB)],
                                ),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('ĐỔI MẬT KHẨU', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
