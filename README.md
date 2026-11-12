# 🎓 Smart Attendance System

Hệ thống điểm danh sinh viên kết hợp **nhận diện khuôn mặt** và **xác thực vị trí GPS**, dành cho sinh viên, giảng viên và phụ huynh.



## Tính năng

**Ứng dụng sinh viên (Flutter)**
- Điểm danh bằng khuôn mặt với Google ML Kit và MobileFaceNet (TFLite, vector 192 chiều).
- Xác thực vị trí GPS: lấy nhiều mẫu vị trí, hiển thị khoảng cách đến lớp học và sai số (± m).
- Lịch học 3 chế độ: ngày, tuần, tháng.
- Lịch sử điểm danh: đúng giờ, đi muộn, vắng mặt.

**Giáo viên và phụ huynh**
- Giáo viên quản lý phiên điểm danh và xem báo cáo của lớp được phân công.
- Phụ huynh theo dõi lịch sử điểm danh của con.

**Backend (Cloudflare Workers + D1)**
- Mật khẩu băm PBKDF2-SHA256, xác thực bằng JWT (hiệu lực 8 giờ).
- API quản lý sinh viên, lớp học, phiên điểm danh, dữ liệu khuôn mặt và phân quyền.

**Web quản trị**
- Tạo admin đầu tiên, duyệt tài khoản giáo viên/phụ huynh, phân công lớp, liên kết phụ huynh với sinh viên.

## Cấu trúc thư mục

```text
face_id_location/                  # Ứng dụng Flutter
├── lib/
│   ├── main.dart                  # Trang chính, luồng điểm danh
│   ├── student_login_page.dart    # Đăng nhập, đổi mật khẩu
│   ├── student_schedule_page.dart # Lịch học
│   ├── role_dashboard_page.dart   # Giáo viên, phụ huynh
│   ├── face_recognition_service.dart
│   └── api_service.dart
└── assets/model/mobilefacenet.tflite

attendance-cloudflare/             # Worker API + D1
├── src/index.ts
├── schema.sql
└── wrangler.jsonc

smart_attendance_admin_v2/         # Web quản trị
├── auth.html
├── admin.html
└── admin.js
```
## 🛠 Hướng dẫn cài đặt và chạy dự án

### Yêu cầu hệ thống
- Flutter SDK 3.x trở lên
- Node.js v18 trở lên và npm
- Android Studio hoặc VS Code, cùng điện thoại Android thật (hoặc máy ảo có camera)

### 1. Ứng dụng di động (Flutter)
```bash
cd face_id_location
flutter pub get
flutter run
```

### 2. Backend (Cloudflare Worker + D1)
```bash
cd attendance-cloudflare/attendance-cloudflare
npm ci

# Tạo bảng trong cơ sở dữ liệu D1
npx wrangler d1 execute attendance-db --remote --file=schema.sql

# Khai báo khóa bí mật
npx wrangler secret put JWT_SECRET
npx wrangler secret put ADMIN_BOOTSTRAP_SECRET

# Triển khai Worker
npx wrangler deploy
```

### 3. Web quản trị
```bash
cd smart_attendance_admin_v2/smart_attendance_admin_v2
npx serve . -l 5500
```
Mở trình duyệt và truy cập: http://localhost:5500/auth.html

## Công nghệ

Flutter · Dart · Google ML Kit · TensorFlow Lite · Geolocator · Cloudflare Workers (TypeScript) · Cloudflare D1 (SQLite) · HTML/CSS/JavaScript
